#!/bin/sh
# mc-guard.sh — install, verify, audit and remove the Master-Claude enforcement layer.
#
# Master-Claude distributes knowledge (master-core/) and memory (memory-core/). Those are
# instructions to a model. This installs the part the harness enforces regardless of what
# the model decides: permissions.deny rules plus PreToolUse guard hooks.
#
# Usage:
#   mc-guard.sh install [--dry-run] [--settings <file>]   merge guards into settings.json
#   mc-guard.sh verify  [--settings <file>]               report what is installed
#   mc-guard.sh audit   [--root <dir>]                    read-only permission-surface audit
#   mc-guard.sh uninstall [--settings <file>]             remove guards, keep everything else
#
# install backs the settings file up to *.mc-bak first, merges (never replaces), and is
# idempotent: an existing rtk/other hook on the same matcher is preserved.
set -eu

die() { printf 'mc-guard: %s\n' "$1" >&2; exit 1; }

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
GUARDS="$REPO_ROOT/guards"
[ -d "$GUARDS" ] || die "no guards/ dir in repo"
command -v jq >/dev/null 2>&1 || die "jq is required"

SETTINGS="$HOME/.claude/settings.json"
ROOT="$HOME/Code"
DRY=0

CMD="${1:-}"
[ -n "$CMD" ] || { sed -n '2,20p' "$0"; exit 0; }
shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --settings) SETTINGS="${2:-}"; shift 2 ;;
    --root) ROOT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) die "unexpected arg: $1" ;;
  esac
done

G_BASH="$GUARDS/guard-bash.sh"
G_WRITE="$GUARDS/guard-write.sh"
DENY_FILE="$GUARDS/deny-rules.json"

# Rule files for the security-guidance plugin. The plugin looks for these by exact name in
# ~/.claude (user scope). Symlinked, not copied, so repo edits propagate like commands/ do.
SEC_GUIDE="claude-security-guidance.md"
SEC_PATTERNS="security-patterns.json"

link_sec_assets() {
  _dest=${1:-$HOME/.claude}
  for _f in "$SEC_GUIDE" "$SEC_PATTERNS"; do
    [ -f "$GUARDS/$_f" ] || continue
    _d="$_dest/$_f"
    if [ -e "$_d" ] && [ ! -L "$_d" ]; then
      printf '  [skip] %s exists as a real file (not replacing)\n' "$_f"
      continue
    fi
    rm -f "$_d"
    ln -s "$GUARDS/$_f" "$_d"
    printf '  linked %s\n' "$_f"
  done
}

ok()   { printf '  [OK]   %s\n' "$1"; }
warn() { printf '  [WARN] %s\n' "$1"; }
fail() { printf '  [FAIL] %s\n' "$1"; }

# jq program: merge deny rules and hook entries without disturbing anything else.
MERGE='
def addhook($matcher; $cmd):
  if any((.hooks.PreToolUse // [])[]; .matcher == $matcher)
  then .hooks.PreToolUse |= map(
         if .matcher == $matcher
         then .hooks = ((.hooks // [])
                        | if any(.[]; .command == $cmd) then .
                          else . + [{type: "command", command: $cmd}] end)
         else . end)
  else .hooks.PreToolUse = ((.hooks.PreToolUse // [])
                            + [{matcher: $matcher, hooks: [{type: "command", command: $cmd}]}])
  end;
.permissions = (.permissions // {})
| .permissions.deny = (((.permissions.deny // []) + $deny) | unique)
| .hooks = (.hooks // {})
| addhook("Bash"; $gbash)
| addhook("Write|Edit|NotebookEdit"; $gwrite)
'

STRIP='
def dropcmd($cmd):
  .hooks.PreToolUse |= (map(.hooks = ((.hooks // []) | map(select(.command != $cmd))))
                        | map(select((.hooks | length) > 0)));
.permissions.deny = (((.permissions.deny // []) - $deny) )
| if (.permissions.deny | length) == 0 then del(.permissions.deny) else . end
| if (.hooks.PreToolUse | type) == "array"
  then dropcmd($gbash) | dropcmd($gwrite) else . end
'

case "$CMD" in

  install)
    [ -f "$SETTINGS" ] || die "no settings file at $SETTINGS"
    jq -e . "$SETTINGS" >/dev/null 2>&1 || die "settings file is not valid JSON: $SETTINGS"
    for g in "$G_BASH" "$G_WRITE"; do
      [ -x "$g" ] || die "guard not executable: $g (run: chmod +x guards/*.sh)"
    done
    OUT=$(jq --slurpfile d "$DENY_FILE" \
             --arg gbash "$G_BASH" --arg gwrite "$G_WRITE" \
             '$d[0].deny as $deny | '"$MERGE" "$SETTINGS")
    if [ "$DRY" -eq 1 ]; then
      printf 'mc-guard: dry-run, would write to %s:\n\n' "$SETTINGS"
      printf '%s\n' "$OUT" | jq '{permissions: .permissions, hooks: .hooks}'
      exit 0
    fi
    cp "$SETTINGS" "$SETTINGS.mc-bak"
    printf '%s\n' "$OUT" > "$SETTINGS.mc-tmp"
    jq -e . "$SETTINGS.mc-tmp" >/dev/null || die "refusing to install: merged output is not valid JSON"
    mv "$SETTINGS.mc-tmp" "$SETTINGS"
    printf 'mc-guard: installed into %s (backup: %s.mc-bak)\n' "$SETTINGS" "$SETTINGS"
    link_sec_assets "$(dirname "$SETTINGS")"
    printf 'mc-guard: restart Claude Code or start a new session for hooks to load.\n'
    ;;

  uninstall)
    [ -f "$SETTINGS" ] || die "no settings file at $SETTINGS"
    cp "$SETTINGS" "$SETTINGS.mc-bak"
    jq --slurpfile d "$DENY_FILE" \
       --arg gbash "$G_BASH" --arg gwrite "$G_WRITE" \
       '$d[0].deny as $deny | '"$STRIP" "$SETTINGS" > "$SETTINGS.mc-tmp"
    jq -e . "$SETTINGS.mc-tmp" >/dev/null || die "refusing to uninstall: output is not valid JSON"
    mv "$SETTINGS.mc-tmp" "$SETTINGS"
    printf 'mc-guard: removed guards from %s (backup: %s.mc-bak)\n' "$SETTINGS" "$SETTINGS"
    ;;

  verify)
    [ -f "$SETTINGS" ] || die "no settings file at $SETTINGS"
    printf 'mc-guard verify: %s\n' "$SETTINGS"
    rc=0
    for g in "$G_BASH" "$G_WRITE"; do
      if [ -x "$g" ]; then ok "guard executable: $(basename "$g")"
      else fail "guard not executable: $g"; rc=1; fi
      if jq -e --arg c "$g" 'any((.hooks.PreToolUse // [])[]; any((.hooks // [])[]; .command == $c))' \
           "$SETTINGS" >/dev/null; then ok "hook registered: $(basename "$g")"
      else fail "hook not registered: $(basename "$g")"; rc=1; fi
    done
    n=$(jq '(.permissions.deny // []) | length' "$SETTINGS")
    want=$(jq '.deny | length' "$DENY_FILE")
    if [ "$n" -ge "$want" ]; then ok "permissions.deny has $n rules (>= $want expected)"
    else fail "permissions.deny has $n rules, expected at least $want"; rc=1; fi
    # A bare tool name in allow matches every use of that tool. Deny still wins over it,
    # so this is reported, not treated as a failure.
    bare=$(jq -r '[(.permissions.allow // [])[] | select(test("^[A-Za-z]+$"))] | join(", ")' "$SETTINGS")
    [ -z "$bare" ] || warn "allow contains bare tool names (match all uses): $bare"
    exit $rc
    ;;

  audit)
    # Read-only. Two classes of finding, per the Claude Code permissions docs:
    #   1. bare tool names in allow      -> match every use of the tool
    #   2. indirection rules             -> the allowed command runs repo-editable content,
    #      e.g. Bash(npm run *) executes whatever package.json defines, and `cargo test`
    #      compiles and runs build.rs. Environment runners (npx, devbox, docker exec) are
    #      explicitly NOT in Claude Code's stripped-wrapper list.
    printf 'mc-guard audit (read-only)\n'
    printf 'scanning: %s and %s/**/.claude/settings*.json\n\n' "$SETTINGS" "$ROOT"
    files=$(printf '%s\n' "$SETTINGS"; find "$ROOT" -path '*/.claude/settings*.json' \
              -not -path '*/node_modules/*' 2>/dev/null | sort)
    nbare=0; nind=0; nfile=0
    for f in $files; do
      [ -f "$f" ] || continue
      jq -e . "$f" >/dev/null 2>&1 || { printf '  [SKIP] invalid JSON: %s\n' "$f"; continue; }
      nfile=$((nfile+1))
      b=$(jq -r '[(.permissions.allow // [])[] | select(test("^[A-Za-z]+$"))] | join(" ")' "$f")
      i=$(jq -r '[(.permissions.allow // [])[]
                  | select(test("^Bash\\((npm run|npm test|yarn |pnpm |bun run|make |just |task |cargo test|cargo run|cargo bench|npx |devbox run|mise exec|direnv exec|docker exec|docker compose run)"))]
                 | join(" ")' "$f")
      if [ -n "$b" ] || [ -n "$i" ]; then
        printf '  %s\n' "${f#"$ROOT"/}"
        [ -z "$b" ] || { printf '    BARE  %s\n' "$b"; nbare=$((nbare+1)); }
        [ -z "$i" ] || { printf '    INDIR %s\n' "$i"; nind=$((nind+1)); }
      fi
    done
    printf '\nscanned %d settings files: %d with bare tool names, %d with indirection rules\n' \
           "$nfile" "$nbare" "$nind"
    printf 'BARE  = rule matches every use of that tool.\n'
    printf 'INDIR = allowed command executes content from a repo-editable file.\n'
    printf 'No changes made. Deny rules and guard hooks override both classes.\n'
    ;;

  *) die "unknown command: $CMD (install|verify|audit|uninstall)" ;;
esac
