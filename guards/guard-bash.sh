#!/bin/sh
# guard-bash.sh — PreToolUse guard for the Bash tool.
# Enforces harness-level execution boundaries (privilege escalation, subshells,
# destructive edits/git, root removal, settings clobber, and network egress).
# Sourced helpers: guard-lib.sh, guard-git.sh, guard-egress.sh. POSIX sh.
set -eu

GUARD_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
. "$GUARD_DIR/guard-lib.sh"
. "$GUARD_DIR/guard-git.sh"
. "$GUARD_DIR/guard-egress.sh"

command -v jq >/dev/null 2>&1 || exit 0
guard_payload
COMMAND=$(guard_field '.tool_input.command')
CWD=$(guard_field '.cwd')
[ -n "$COMMAND" ] || guard_pass
[ -d "$CWD" ] || CWD=$PWD

NL='
'

is_cluster() {
  case "$1" in
    -"$2"|-"$2".*) return 0 ;;
    --*) return 1 ;;
  esac
  printf '%s' "$1" | grep -Eq "^-[a-zA-Z]+$" || return 1
  printf '%s' "$1" | grep -q "$2"
}

# 1. Privilege escalation
check_sudo() {
  case "$(guard_basename_cmd "$1")" in
    sudo|doas|pkexec)
      guard_deny "Blocked: privilege escalation ($1). No TTY in agent session; failures trip faillock. Hand command to user." ;;
  esac
}

# 2. Nested interpreter invocation
check_nested_interpreter() {
  case "$(guard_basename_cmd "$1")" in
    sh|bash|zsh|dash|ksh)
      for w in $(guard_words "$1"); do
        case "$w" in
          -c|-*c*) guard_deny "Blocked: nested shell invocation ($1). Subshells bypass inspection; run commands directly." ;;
        esac
      done ;;
  esac
}

# 3. In-place stream edits
check_inplace() {
  _cmd=$(guard_basename_cmd "$1")
  case "$_cmd" in sed|perl) ;; *) return 0 ;; esac
  _skip=1
  for w in $(guard_words "$1"); do
    if [ "$_skip" -eq 1 ]; then _skip=0; continue; fi
    case "$w" in --in-place*) ;; *) is_cluster "$w" i || continue ;; esac
    guard_deny "Blocked: in-place stream edit ($_cmd -i). Use Edit tool or git show HEAD:<path>."
  done
}

# 4. Recursive removal of a root
check_rm_root() {
  [ "$(guard_basename_cmd "$1")" = "rm" ] || return 0
  _rec=0; _skip=1
  for w in $(guard_words "$1"); do
    if [ "$_skip" -eq 1 ]; then _skip=0; continue; fi
    case "$w" in
      --recursive) _rec=1; continue ;;
      --*) continue ;;
      -*) if is_cluster "$w" r || is_cluster "$w" R; then _rec=1; fi; continue ;;
    esac
    [ "$_rec" -eq 1 ] || continue
    _t=${w%/}
    # shellcheck disable=SC2016,SC2088
    case "$_t" in
      '~/'*) _t="$HOME/${_t#'~/'}" ;;
      '$HOME/'*) _t="$HOME/${_t#'$HOME/'}" ;;
      '${HOME}/'*) _t="$HOME/${_t#'${HOME}/'}" ;;
    esac
    # shellcheck disable=SC2016
    case "$_t" in
      ''|'~'|'$HOME'|'/'|'/home'|'/usr'|'/etc'|'/var'|'/boot'|'/mnt'|"$HOME")
        guard_deny "Blocked: recursive removal targeting '$w', a system or home root." ;;
      "$HOME/Code"|"$HOME/Code/OSS_Public-Projects"|"$HOME/Code/Commercial_Private-Projects"|"$HOME/Code/Commercial_Income-Projects"|"$HOME/Code/Local_Only-Projects"|"$HOME/Code/Forks-Projects"|"$HOME/Code/GH_Clone-Projects")
        guard_deny "Blocked: recursive removal of workspace/category root ('$w'). Remove specific project directory instead." ;;
    esac
  done
}

# 5. Recursive chown on NTFS mount
check_chown_ntfs() {
  [ "$(guard_basename_cmd "$1")" = "chown" ] || return 0
  case "$1" in *--recursive*) ;; *)
    _hit=0
    for w in $(guard_words "$1"); do
      case "$w" in --*) continue ;; -*) if is_cluster "$w" R; then _hit=1; fi ;; esac
    done
    [ "$_hit" -eq 1 ] || return 0 ;;
  esac
  case "$1" in
    */mnt/Data_SSD*) guard_deny "Blocked: recursive chown under /mnt/Data_SSD. Synthetic uid/gid make this a no-op that damages MFT." ;;
  esac
}

# 6. Shell-side clobber of settings
_SETTINGS_RE='\.claude/settings[^[:space:]]*\.json'

check_settings_clobber() {
  _sub=$1
  if printf '%s' "$_sub" | grep -Eq ">>?[[:space:]]*[^[:space:]]*$_SETTINGS_RE"; then
    _deny_settings
  fi
  case "$(guard_basename_cmd "$_sub")" in
    tee|truncate)
      printf '%s' "$_sub" | grep -Eq "$_SETTINGS_RE" && _deny_settings ;;
    dd)
      for w in $(guard_words "$_sub"); do
        case "$w" in
          of=*) printf '%s' "${w#of=}" | grep -Eq "$_SETTINGS_RE" && _deny_settings ;;
        esac
      done ;;
    cp|install|mv|ln)
      _target=''; _prev=''
      for w in $(guard_words "$_sub"); do
        case "$_prev" in -t|--target-directory) _target=$w; break ;; esac
        case "$w" in
          --target-directory=*) _target=${w#--target-directory=}; break ;;
          -*) ;;
          *) _target=$w ;;
        esac
        _prev=$w
      done
      [ -n "$_target" ] && printf '%s' "$_target" | grep -Eq "$_SETTINGS_RE" && _deny_settings ;;
  esac
  return 0
}

_deny_settings() {
  guard_deny "Blocked: shell write to Claude Code settings. Use bin/mc-guard.sh or ask the user."
}

# Dispatch
IFS=$NL
for raw in $(guard_split "$COMMAND"); do
  sub=$(guard_normalize "$raw")
  [ -n "$sub" ] || continue

  case "$(guard_basename_cmd "$sub")" in
    cd|pushd)
      _target=$(guard_trim "${sub#* }")
      _target=${_target%%"$NL"*}
      # shellcheck disable=SC2088
      case "$_target" in
        '~'|'') _target=$HOME ;;
        '~/'*)  _target="$HOME/${_target#'~/'}" ;;
        /*)     ;;
        *)      _target="$CWD/$_target" ;;
      esac
      [ -d "$_target" ] && CWD=$(CDPATH='' cd -- "$_target" 2>/dev/null && pwd || printf '%s' "$CWD")
      continue ;;
  esac

  check_sudo               "$sub"
  check_nested_interpreter "$sub"
  check_inplace            "$sub"
  check_git                "$sub"
  check_rm_root            "$sub"
  check_chown_ntfs         "$sub"
  check_settings_clobber   "$sub"
done

check_egress_exec "$COMMAND"
for raw in $(guard_split "$COMMAND"); do
  sub=$(guard_normalize "$raw")
  [ -n "$sub" ] || continue
  check_egress_upload "$sub"
done

guard_pass
