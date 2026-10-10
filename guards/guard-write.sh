#!/bin/sh
# guard-write.sh — PreToolUse guard for the Write, Edit and NotebookEdit tools.
#
# Blocks tool-level writes to paths that must never be modified by an agent:
#   - .git internals        — corrupting these loses history, not just working-tree state
#   - ~/.ssh, secrets       — private keys and credentials
#   - /etc, /usr, /boot     — system configuration; those changes belong to the user
#   - .claude/settings*.json — the permission and hook rules that constrain this session
#
# The settings.json rule is the tool-level half of the same protection guard-bash.sh
# applies to shell redirects. It exists independently of CVE-2026-25725 (settings-creation
# to plant a SessionStart hook, patched in Claude Code 2.1.2): the class of problem is
# an agent editing the rules that govern it, which stays worth blocking on principle.
#
# POSIX sh. Helpers in guard-lib.sh.
set -eu

GUARD_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
. "$GUARD_DIR/guard-lib.sh"

command -v jq >/dev/null 2>&1 || exit 0

guard_payload
FILE=$(guard_field '.tool_input.file_path')
[ -n "$FILE" ] || FILE=$(guard_field '.tool_input.notebook_path')
[ -n "$FILE" ] || guard_pass

CANON="$FILE"
if command -v realpath >/dev/null 2>&1; then
  CANON=$(realpath -m "$FILE" 2>/dev/null || printf '%s' "$FILE")
elif command -v readlink >/dev/null 2>&1; then
  CANON=$(readlink -m "$FILE" 2>/dev/null || printf '%s' "$FILE")
fi

check_path() {
  _p=$1
  case "$_p" in
    */.git/*|*/.git)
      guard_deny "Blocked: write to git internals ($FILE). Corrupting these loses commit history, not just working-tree state. Use git commands for repository operations." ;;
    "$HOME"/.ssh/*|*/.ssh/id_*|*.pem|*.key|*/.gnupg/*)
      guard_deny "Blocked: write to a private key or credential file ($FILE). Secrets are managed by the user, outside the agent session." ;;
    /etc/*|/usr/*|/boot/*|/sys/*|/proc/*)
      guard_deny "Blocked: write to a system path ($FILE). System configuration changes belong to the user, who can apply them with the privileges this session does not have." ;;
    */.claude/settings.json|*/.claude/settings.local.json)
      guard_deny "Blocked: write to a Claude Code settings file ($FILE). Settings hold the permission and hook rules that constrain this session; an agent must not rewrite them mid-session. Use bin/mc-guard.sh for guard configuration, or ask the user to edit the file." ;;
    *.env|*.env.*)
      guard_deny "Blocked: write to an environment/secrets file ($FILE). Per master-core module 60, secrets are supplied by the user via the environment and never written by an agent." ;;
  esac
}

check_path "$FILE"
check_path "$CANON"

guard_pass
