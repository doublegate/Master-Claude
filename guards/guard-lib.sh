#!/bin/sh
# guard-lib.sh — shared helpers for Master-Claude PreToolUse guards.
#
# Guards are Claude Code PreToolUse hooks. They receive the hook payload as JSON on
# stdin and decide whether a tool call may proceed. Unlike CLAUDE.md prose, a guard is
# enforced by the harness, not by the model — it fires deterministically every time.
#
# Contract (see code.claude.com/docs/en/hooks):
#   stdin  : {"tool_name":..., "tool_input":{...}, "cwd":..., ...}
#   stdout : {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#             "permissionDecision":"deny","permissionDecisionReason":"..."}}
#   exit 0 : always. Printing no JSON means "no decision" (normal permission flow).
#
# Sourced by guard-bash.sh and guard-write.sh. Not executable on its own.
# POSIX sh. No bashisms, no heredocs (fish-safe authoring).

# --- payload -----------------------------------------------------------------

# guard_payload: slurp stdin once into GUARD_PAYLOAD.
guard_payload() {
  GUARD_PAYLOAD=$(cat)
}

# guard_field <jq-path>: read a string field from the payload; empty if absent.
guard_field() {
  printf '%s' "$GUARD_PAYLOAD" | jq -r "$1 // empty" 2>/dev/null || printf ''
}

# --- decisions ---------------------------------------------------------------

# guard_deny <reason>: emit the deny envelope and stop. Always exits 0 — exit 2
# would also block, but discards stdout, and we want the reason to reach the model
# as a structured permissionDecisionReason rather than raw stderr.
guard_deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

# guard_ask <reason>: force a confirmation prompt even where permissions would have
# auto-approved. For shapes that are routinely legitimate but are also exactly how an
# injected instruction would exfiltrate or execute — denying those outright would break
# ordinary work, and staying silent is what makes `defaultMode: auto` dangerous. The
# middle tier puts a human in the loop without blocking the workflow.
guard_ask() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

# guard_pass: no decision; the normal permission flow applies.
guard_pass() {
  exit 0
}

# --- command parsing ---------------------------------------------------------

# guard_split <command>: print one subcommand per line.
# Claude Code matches permission rules per-subcommand; a guard must do the same or
# `safe-cmd && rm -rf ~` slips through on the strength of its first word.
guard_split() {
  printf '%s\n' "$1" | awk '{ gsub(/&&|\|\||\|&|[;|&]/, "\n"); print }'
}

# guard_trim <string>: strip leading and trailing whitespace.
guard_trim() {
  printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# guard_normalize <subcommand>: strip leading env assignments and the wrappers
# Claude Code itself strips before rule matching, so `FOO=1 timeout 30 sed -i ...`
# is judged as `sed -i ...`. Without this a guard is trivially evaded.
guard_normalize() {
  _s=$(guard_trim "$1")
  while [ -n "$_s" ]; do
    _first=${_s%% *}
    [ "$_first" = "$_s" ] && break   # single word left: nothing to strip
    case "$_first" in
      -*) break ;;
      *=*) _s=$(guard_trim "${_s#* }"); continue ;;
    esac
    case "$_first" in
      timeout|stdbuf)
        _s=$(guard_trim "${_s#* }")            # drop wrapper
        _s=$(guard_trim "${_s#* }") ;;         # drop its argument
      nice)
        _s=$(guard_trim "${_s#* }")
        case "$_s" in
          -n\ *) _s=$(guard_trim "${_s#* }"); _s=$(guard_trim "${_s#* }") ;;
          -*)    _s=$(guard_trim "${_s#* }") ;;
        esac ;;
      time|nohup|command|builtin|noglob|xargs)
        _s=$(guard_trim "${_s#* }") ;;
      *) break ;;
    esac
  done
  printf '%s' "$_s"
}

# guard_words <subcommand>: print one argument per line (whitespace-split).
guard_words() {
  printf '%s\n' "$1" | tr -s '[:space:]' '\n'
}

# guard_basename_cmd <subcommand>: the command word with any path stripped, so
# /usr/bin/sed and sed are judged identically.
guard_basename_cmd() {
  _c=${1%% *}
  printf '%s' "${_c##*/}"
}
