#!/usr/bin/env bash

# Tests for dotfiles/local/bin/claude-settings.
# Runs the real script in a sandbox: fake repo layout + fake HOME, invoked
# through a ~/.local/bin-style symlink so path resolution through symlinks
# is exercised. Never touches the real ~/.claude.

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SCRIPT="$REPO_DIR/dotfiles/local/bin/claude-settings"

PASS=0
FAIL=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ok: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected: $(printf '%q' "$expected")"
    echo "    actual:   $(printf '%q' "$actual")"
    FAIL=$((FAIL + 1))
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SANDBOX_DOTFILES="$TMP/repo/dotfiles"
SANDBOX_HOME="$TMP/home"
REPO_FILE="$SANDBOX_DOTFILES/claude/settings.json"
LIVE_FILE="$SANDBOX_HOME/.claude/settings.json"
CMD="$SANDBOX_HOME/.local/bin/claude-settings"

mkdir -p "$SANDBOX_DOTFILES/local/bin" "$SANDBOX_DOTFILES/claude" \
  "$SANDBOX_HOME/.claude" "$SANDBOX_HOME/.local/bin"
cp "$SOURCE_SCRIPT" "$SANDBOX_DOTFILES/local/bin/claude-settings" 2>/dev/null
ln -s "$SANDBOX_DOTFILES/local/bin/claude-settings" "$CMD"

run_cmd() {
  # run_cmd <args...>; sets OUTPUT and STATUS
  OUTPUT="$(HOME="$SANDBOX_HOME" "$CMD" "$@" 2>&1)"
  STATUS=$?
}

backup_count() {
  find "$SANDBOX_HOME/.claude" -name 'settings.json.backup.*' | grep -c .
}

echo "repo side missing"
printf '{"model":"opus"}\n' > "$LIVE_FILE"
run_cmd status
check "status exits 1"                  "1" "$STATUS"
check "status names missing side"       "repo missing: $REPO_FILE" "$OUTPUT"
run_cmd apply
check "apply refuses without repo file" "1" "$STATUS"

echo "save: live -> repo"
run_cmd save
check "save exits 0"           "0" "$STATUS"
check "repo file matches live" "$(cat "$LIVE_FILE")" "$(cat "$REPO_FILE" 2>/dev/null)"
run_cmd status
check "status now exits 0" "0" "$STATUS"
check "status says in sync" "in sync" "$OUTPUT"

echo "drift: live edited"
printf '{"model":"fable"}\n' > "$LIVE_FILE"
run_cmd status
check "status exits 1 on drift" "1" "$STATUS"
run_cmd diff
check "diff exits 1 on drift"     "1" "$STATUS"
check "diff labels repo and live" "2" \
  "$(printf '%s\n' "$OUTPUT" | grep -c -E '^(--- repo|\+\+\+ live)')"

echo "apply: repo -> live, with backup"
run_cmd apply
check "apply exits 0"            "0" "$STATUS"
check "live file matches repo"   "$(cat "$REPO_FILE")" "$(cat "$LIVE_FILE")"
check "one timestamped backup"   "1" "$(backup_count)"
check "backup holds old content" '{"model":"fable"}' \
  "$(cat "$SANDBOX_HOME/.claude"/settings.json.backup.*)"

echo "no-ops when already in sync"
run_cmd apply
check "apply no-op exits 0"  "0" "$STATUS"
check "apply no-op message"  "already in sync" "$OUTPUT"
check "no extra backup"      "1" "$(backup_count)"
run_cmd save
check "save no-op message"   "already in sync" "$OUTPUT"

echo "apply replaces a symlinked live file"
rm "$LIVE_FILE"
ln -s "$REPO_FILE" "$LIVE_FILE"
run_cmd apply
check "apply exits 0 on symlink"   "0" "$STATUS"
check "live is now a regular file" "regular" \
  "$([ -L "$LIVE_FILE" ] && echo symlink || echo regular)"
check "live content matches repo"  "$(cat "$REPO_FILE")" "$(cat "$LIVE_FILE")"

echo "errors and usage"
rm "$LIVE_FILE"
run_cmd status
check "status exits 1 without live" "1" "$STATUS"
check "status names live missing"   "live missing: $LIVE_FILE" "$OUTPUT"
run_cmd save
check "save without live exits 1"  "1" "$STATUS"
run_cmd bogus
check "unknown subcommand exits 2" "2" "$STATUS"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
