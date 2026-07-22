#!/bin/sh
# guard-bash.sh — PreToolUse guard for the Bash tool.
#
# Enforces the rules that AGENTS.md/CLAUDE.md can only ask for. Each rule here exists
# because the prose version already failed at least once on this machine.
#
# Checks, in order (first deny wins):
#   1. sudo / doas            — no TTY in an agent session; repeated failures trip faillock
#   2. sed -i / perl -i       — in-place stream edits have silently truncated files to 0 bytes
#   3. git destructive        — only when the target actually has uncommitted changes
#   4. rm -r on a root        — filesystem root, $HOME, or a workspace category root
#   5. chown -R on the NTFS mount — synthetic uid/gid make it a no-op that still hammers the MFT
#   6. clobbering settings.json  — shell-side writes to a Claude Code settings file
#
# Rule 3 is why this is a hook and not a static permissions.deny entry: `git checkout <file>`
# is perfectly legitimate on a clean tree. Only the dirty case destroys unrecoverable work,
# and only a hook can look at `git status` before deciding.
#
# POSIX sh. Helpers in guard-lib.sh. Runs on every Bash call: no git process is spawned
# unless a destructive verb already matched.
set -eu

GUARD_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
. "$GUARD_DIR/guard-lib.sh"

command -v jq >/dev/null 2>&1 || exit 0   # no jq: fail open rather than wedge every Bash call

guard_payload
COMMAND=$(guard_field '.tool_input.command')
CWD=$(guard_field '.cwd')
[ -n "$COMMAND" ] || guard_pass
[ -d "$CWD" ] || CWD=$PWD

NL='
'

# is_cluster <word> <letter>: true when <word> is a short-flag cluster (-abc, letters
# only) containing <letter>, or the long form -<letter> with an attached value (-i.bak).
# Letters-only keeps `perl -MList::Util` from reading as an "-i" cluster.
is_cluster() {
  case "$1" in
    -"$2") return 0 ;;
    -"$2".*) return 0 ;;
    --*) return 1 ;;
  esac
  printf '%s' "$1" | grep -Eq "^-[a-zA-Z]+$" || return 1
  printf '%s' "$1" | grep -q "$2"
}

# --- 1. privilege escalation -------------------------------------------------

check_sudo() {
  case "$(guard_basename_cmd "$1")" in
    sudo|doas|pkexec)
      guard_deny "Blocked: privilege escalation from an agent session. There is no TTY here, so sudo cannot prompt, and repeated failures trip faillock and lock the real user out of sudo. Hand this command to the user to run themselves." ;;
  esac
}

# --- 2. in-place stream edits ------------------------------------------------

check_inplace() {
  _cmd=$(guard_basename_cmd "$1")
  case "$_cmd" in sed|perl) ;; *) return 0 ;; esac
  _skip=1
  for w in $(guard_words "$1"); do
    if [ "$_skip" -eq 1 ]; then _skip=0; continue; fi
    case "$w" in --in-place*) ;; *) is_cluster "$w" i || continue ;; esac
    guard_deny "Blocked: in-place stream edit ($_cmd -i). This has silently truncated a file to 0 bytes here before: 'sed -n ... -i' writes nothing, because -n suppresses auto-print. Use the Edit tool for edits. To read the committed version without touching the working tree: git show HEAD:<path>"
  done
}

# --- 3. destructive git against uncommitted work ------------------------------

# git_is_dirty <repo-dir> [newline-separated paths in $2] -> 0 if uncommitted work in scope
# Callers run under IFS=newline, so the unquoted $_pp below splits on newlines only:
# a path containing spaces stays one argument.
git_is_dirty() {
  _d=$1
  if [ -n "${2:-}" ]; then
    _pp=$2
    # shellcheck disable=SC2086
    _st=$(git -C "$_d" status --porcelain -- $_pp 2>/dev/null || true)
  else
    _st=$(git -C "$_d" status --porcelain 2>/dev/null || true)
  fi
  [ -n "$_st" ]
}

check_git() {
  _sub=$1
  [ "$(guard_basename_cmd "$_sub")" = "git" ] || return 0

  _dir=$CWD; _verb=''; _hard=0; _force=0; _dashdash=0; _paths=''; _take_dir=0
  _skip=1
  for w in $(guard_words "$_sub"); do
    if [ "$_skip" -eq 1 ]; then _skip=0; continue; fi
    if [ "$_take_dir" -eq 1 ]; then _dir=$w; _take_dir=0; continue; fi
    case "$w" in
      -C) _take_dir=1; continue ;;
      --hard) _hard=1; continue ;;
      --force) _force=1; continue ;;
      --) _dashdash=1; continue ;;
      -*) if is_cluster "$w" f; then _force=1; fi; continue ;;
    esac
    if [ -z "$_verb" ]; then _verb=$w; continue; fi
    # Resolve a candidate path against the repo dir first: with `git -C <repo> checkout f.txt`
    # the argument is relative to <repo>, not to the shell's cwd.
    if [ "$_dashdash" -eq 1 ] || [ -e "$_dir/$w" ] || [ -e "$CWD/$w" ] || [ -e "$w" ]; then
      if [ -z "$_paths" ]; then _paths=$w; else _paths="$_paths$NL$w"; fi
    fi
  done

  case "$_verb" in
    reset)
      [ "$_hard" -eq 1 ] || return 0
      git_is_dirty "$_dir" || return 0
      guard_deny "Blocked: 'git reset --hard' with uncommitted changes in the working tree. Those changes are in no commit, stash, or staged blob, so they are unrecoverable from git. Run 'git status --short' to see what would be lost. To undo only your own edits from this session, reverse them with the Edit tool." ;;
    checkout|restore)
      # A bare branch switch has no paths, and git itself refuses to clobber. Only the
      # path form overwrites the working tree from the index/HEAD without warning.
      [ -n "$_paths" ] || return 0
      git_is_dirty "$_dir" "$_paths" || return 0
      guard_deny "Blocked: 'git $_verb' would overwrite uncommitted changes, permanently and unrecoverably, in: $(printf '%s' "$_paths" | tr '\n' ' '). To read the committed version without touching the working tree: git show HEAD:<path>. To undo your own session edits, reverse them with the Edit tool. If the user explicitly asked to discard these exact changes, they can run this themselves." ;;
    clean)
      [ "$_force" -eq 1 ] || return 0
      git_is_dirty "$_dir" || return 0
      guard_deny "Blocked: 'git clean -f' with untracked or modified files present. Untracked files are in no commit and cannot be recovered. Run 'git status --short' first and move anything worth keeping aside." ;;
    stash)
      case " $_sub " in
        *' pop '*|*' apply '*|*' list '*|*' show '*|*' drop '*|*' branch '*) return 0 ;;
      esac
      git_is_dirty "$_dir" || return 0
      guard_deny "Blocked: bare 'git stash' hides uncommitted work somewhere later commands routinely lose track of. If a clean tree is genuinely required, stash with an explicit message and an immediate restore plan, or let the user run it." ;;
  esac
}

# --- 4. recursive removal of a root ------------------------------------------

check_rm_root() {
  _sub=$1
  [ "$(guard_basename_cmd "$_sub")" = "rm" ] || return 0
  _rec=0
  _skip=1
  for w in $(guard_words "$_sub"); do
    if [ "$_skip" -eq 1 ]; then _skip=0; continue; fi
    case "$w" in
      --recursive) _rec=1; continue ;;
      --*) continue ;;
      -*) if is_cluster "$w" r || is_cluster "$w" R; then _rec=1; fi; continue ;;
    esac
    [ "$_rec" -eq 1 ] || continue
    _t=${w%/}
    # The command string arrives as the model wrote it, before any shell expansion, so the
    # unexpanded home forms have to be resolved here or `rm -rf ~/Code` reads as a literal
    # relative path and slips through.
    # SC2088: the literal tilde is the point -- we are matching text the model wrote, not
    # asking the shell to expand it.
    # shellcheck disable=SC2016,SC2088
    case "$_t" in
      '~/'*)      _t="$HOME/${_t#'~/'}" ;;
      '$HOME/'*)  _t="$HOME/${_t#'$HOME/'}" ;;
      '${HOME}/'*) _t="$HOME/${_t#'${HOME}/'}" ;;
    esac
    # shellcheck disable=SC2016
    case "$_t" in
      ''|'~'|'$HOME'|'/'|'/home'|'/usr'|'/etc'|'/var'|'/boot'|'/mnt'|"$HOME")
        guard_deny "Blocked: recursive removal targeting '$w', a system or home root." ;;
      "$HOME/Code"|"$HOME/Code/OSS_Public-Projects"|"$HOME/Code/Commercial_Private-Projects"|"$HOME/Code/Commercial_Income-Projects"|"$HOME/Code/Local_Only-Projects"|"$HOME/Code/Forks-Projects"|"$HOME/Code/GH_Clone-Projects")
        guard_deny "Blocked: recursive removal of the workspace root or a project category root ('$w'). Remove a specific project directory instead, and only when explicitly asked." ;;
    esac
  done
}

# --- 5. recursive chown on the NTFS mount ------------------------------------

check_chown_ntfs() {
  _sub=$1
  [ "$(guard_basename_cmd "$_sub")" = "chown" ] || return 0
  case "$_sub" in *--recursive*) ;; *)
    _hit=0
    for w in $(guard_words "$_sub"); do
      case "$w" in --*) continue ;; -*) if is_cluster "$w" R; then _hit=1; fi ;; esac
    done
    [ "$_hit" -eq 1 ] || return 0 ;;
  esac
  case "$_sub" in
    */mnt/Data_SSD*)
      guard_deny "Blocked: recursive chown under /mnt/Data_SSD. The uid/gid there are synthetic mount options, so chown changes nothing -- but it still walks and rewrites the entire MFT, which is how that volume was damaged before. Set ownership via the uid=/gid= mount options instead." ;;
  esac
}

# --- 6. shell-side clobber of a Claude Code settings file --------------------
#
# Must match the WRITE, not the mere mention. An earlier version tested the whole command
# string for a '>' and a settings path anywhere in it, which denied the entirely legitimate
# `jq . ~/.claude/settings.json >/dev/null`. Reading settings is fine; only a redirect whose
# target is the settings file, or tee/cp writing to it, is a clobber.

_SETTINGS_RE='\.claude/settings[^[:space:]]*\.json'

check_settings_clobber() {
  _sub=$1
  # redirect (>, >>) whose target is a settings file
  if printf '%s' "$_sub" | grep -Eq ">>?[[:space:]]*[^[:space:]]*$_SETTINGS_RE"; then
    _deny_settings
  fi
  case "$(guard_basename_cmd "$_sub")" in
    tee)
      printf '%s' "$_sub" | grep -Eq "$_SETTINGS_RE" && _deny_settings ;;
    cp|install|dd)
      # only the destination (last argument) counts
      _last=''
      for w in $(guard_words "$_sub"); do _last=$w; done
      printf '%s' "$_last" | grep -Eq "$_SETTINGS_RE" && _deny_settings ;;
  esac
  return 0
}

_deny_settings() {
  guard_deny "Blocked: shell write to a Claude Code settings file. Settings hold the permission and hook rules that constrain this session, so an agent must not rewrite them mid-session. Reading them is fine. Use bin/mc-guard.sh for guard configuration, or ask the user to edit the file."
}

# --- dispatch ----------------------------------------------------------------
# IFS=newline so the loops below stay in the main shell. A `| while read` pipeline
# would run in a subshell, where guard_deny's exit could not stop the script and a
# second match would emit a second JSON object.

IFS=$NL
for raw in $(guard_split "$COMMAND"); do
  sub=$(guard_normalize "$raw")
  [ -n "$sub" ] || continue

  # Track `cd` across the compound command. Without this, `cd repo && git checkout f.txt`
  # is checked for dirtiness against the session cwd instead of the repo actually being
  # operated on -- the check silently passes and the work is destroyed. The `cd &&` form is
  # how the overwhelming majority of these commands are written, so this is load-bearing.
  case "$(guard_basename_cmd "$sub")" in
    cd|pushd)
      _target=$(guard_trim "${sub#* }")
      _target=${_target%%"$NL"*}
      # shellcheck disable=SC2088
      case "$_target" in
        '~')     _target=$HOME ;;
        '~/'*)   _target="$HOME/${_target#'~/'}" ;;
        '')      _target=$HOME ;;
        /*)      ;;
        *)       _target="$CWD/$_target" ;;
      esac
      if [ -d "$_target" ]; then
        CWD=$(CDPATH='' cd -- "$_target" 2>/dev/null && pwd || printf '%s' "$CWD")
      fi
      continue ;;
  esac

  check_sudo             "$sub"
  check_inplace          "$sub"
  check_git              "$sub"
  check_rm_root          "$sub"
  check_chown_ntfs       "$sub"
  check_settings_clobber "$sub"
done

guard_pass
