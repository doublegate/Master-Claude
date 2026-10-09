#!/bin/sh
# guard-git.sh — git command analysis helper for guard-bash.sh.
# Sourced by guard-bash.sh; not standalone.

# git_is_dirty <repo-dir> [newline-separated paths in $2] [check_ignored in $3]
git_is_dirty() {
  _d=$1; _paths=${2:-}; _ign=${3:-0}
  _flags="--porcelain"
  if [ "$_ign" -eq 1 ]; then
    _flags="$_flags --ignored"
  fi
  if [ -n "$_paths" ]; then
    # shellcheck disable=SC2086
    _st=$(git -C "$_d" status $_flags -- $_paths 2>/dev/null || true)
  else
    # shellcheck disable=SC2086
    _st=$(git -C "$_d" status $_flags 2>/dev/null || true)
  fi
  [ -n "$_st" ]
}

check_git() {
  _sub=$1
  [ "$(guard_basename_cmd "$_sub")" = "git" ] || return 0

  _dir=$CWD; _verb=''; _hard=0; _force=0; _ignored=0; _dashdash=0; _paths=''; _take_dir=0; _has_msg=0
  _skip=1
  for w in $(guard_words "$_sub"); do
    if [ "$_skip" -eq 1 ]; then _skip=0; continue; fi
    if [ "$_take_dir" -eq 1 ]; then _dir=$w; _take_dir=0; continue; fi
    case "$w" in
      -C) _take_dir=1; continue ;;
      --hard) _hard=1; continue ;;
      --force|--discard-changes) _force=1; continue ;;
      --) _dashdash=1; continue ;;
      -m|--message) _has_msg=1; continue ;;
      --message=*) _has_msg=1; continue ;;
      -x|-X|--ignored) _ignored=1; continue ;;
      -*)
        if is_cluster "$w" f; then _force=1; fi
        if is_cluster "$w" m; then _has_msg=1; fi
        if is_cluster "$w" x || is_cluster "$w" X; then _ignored=1; fi
        continue ;;
    esac
    if [ -z "$_verb" ]; then _verb=$w; continue; fi
    if [ "$_dashdash" -eq 1 ] || [ -e "$_dir/$w" ] || [ -e "$CWD/$w" ] || [ -e "$w" ]; then
      if [ -z "$_paths" ]; then _paths=$w; else _paths="$_paths$NL$w"; fi
    fi
  done

  case "$_verb" in
    reset)
      [ "$_hard" -eq 1 ] || return 0
      git_is_dirty "$_dir" || return 0
      guard_deny "Blocked: 'git reset --hard' with uncommitted changes in the working tree. Those changes are in no commit, stash, or staged blob, so they are unrecoverable from git. Run 'git status --short' to see what would be lost. To undo only your own edits from this session, reverse them with the Edit tool." ;;
    checkout|restore|switch)
      if [ "$_force" -eq 1 ]; then
        git_is_dirty "$_dir" || return 0
        guard_deny "Blocked: 'git $_verb' with force/discard-changes would overwrite uncommitted changes in the working tree. Run 'git status --short' to inspect them."
      fi
      [ -n "$_paths" ] || return 0
      git_is_dirty "$_dir" "$_paths" || return 0
      guard_deny "Blocked: 'git $_verb' would overwrite uncommitted changes, permanently and unrecoverably, in: $(printf '%s' "$_paths" | tr '\n' ' '). To read the committed version without touching the working tree: git show HEAD:<path>. To undo your own session edits, reverse them with the Edit tool. If the user explicitly asked to discard these exact changes, they can run this themselves." ;;
    clean)
      [ "$_force" -eq 1 ] || return 0
      git_is_dirty "$_dir" '' "$_ignored" || return 0
      guard_deny "Blocked: 'git clean -f' with untracked, modified, or ignored files present. Files cannot be recovered from git. Run 'git status --short' first and move anything worth keeping aside." ;;
    stash)
      case " $_sub " in
        *' pop '*|*' apply '*|*' list '*|*' show '*|*' drop '*|*' branch '*) return 0 ;;
      esac
      if [ "$_has_msg" -eq 1 ]; then return 0; fi
      case " $_sub " in
        *' save '*[!-]*|*' save "'*|*" save '"*) return 0 ;;
      esac
      git_is_dirty "$_dir" || return 0
      guard_deny "Blocked: bare 'git stash' hides uncommitted work somewhere later commands routinely lose track of. If a clean tree is genuinely required, stash with an explicit message and an immediate restore plan, or let the user run it." ;;
  esac
}
