#!/usr/bin/env bash

# Tests for dotfiles/local/bin/update-all.
# Uses PATH stubs for claude/brew/npm so no real upgrades run; each stub
# records its invocation so a failure test can prove later steps still ran.

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_DIR/dotfiles/local/bin/update-all"

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

make_stubs() {
  # make_stubs <stub_dir> <log_file> <failing_command_or_empty>
  local dir="$1" log="$2" failing="$3" cmd code
  mkdir -p "$dir"
  for cmd in claude brew npm; do
    code=0
    [ "$cmd" = "$failing" ] && code=1
    cat > "$dir/$cmd" <<EOF
#!/bin/sh
echo "$cmd \$@" >> "$log"
exit $code
EOF
    chmod +x "$dir/$cmd"
  done
}

run_script() {
  # run_script <stub_dir>; sets OUTPUT and STATUS
  OUTPUT="$(PATH="$1:$PATH" "$SCRIPT" 2>&1)"
  STATUS=$?
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "failure path: claude fails, everything else still runs"
make_stubs "$TMP/fail" "$TMP/fail.log" claude
run_script "$TMP/fail"
check "exit code is 1" "1" "$STATUS"
check "all commands ran in order" \
  "$(printf 'claude update\nbrew upgrade\nbrew cleanup\nnpm update -g')" \
  "$(cat "$TMP/fail.log" 2>/dev/null)"
check "summary rows in order with ✗ only on failed step" \
  "$(printf '  ✗ Claude Code: claude update (exit 1)\n  ✓ Homebrew: brew upgrade\n  ✓ Homebrew: brew cleanup\n  ✓ npm globals: npm update -g')" \
  "$(printf '%s\n' "$OUTPUT" | grep -E '^  [✓✗]')"

echo "success path: everything passes"
make_stubs "$TMP/ok" "$TMP/ok.log" ""
run_script "$TMP/ok"
check "exit code is 0" "0" "$STATUS"
check "four ✓ rows in order" \
  "$(printf '  ✓ Claude Code: claude update\n  ✓ Homebrew: brew upgrade\n  ✓ Homebrew: brew cleanup\n  ✓ npm globals: npm update -g')" \
  "$(printf '%s\n' "$OUTPUT" | grep -E '^  [✓✗]')"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
