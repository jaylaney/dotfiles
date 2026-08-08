#!/usr/bin/env bash

# Tests for install.sh's dangling-symlink detection.
# Runs install.sh against temp target directories; the repo's own dotfiles/
# is the symlink source, so a dangler is a link to a path under it that
# does not exist. Non-repo broken links (decoys) must never be reported.

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_DIR/install.sh"

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

make_target() {
  # make_target <dir>: target with two repo-pointing danglers (one top-level,
  # one nested under .config to exercise the recursive scan) and one decoy
  local dir="$1"
  mkdir -p "$dir"
  ln -s "$REPO_DIR/dotfiles/no-such-file" "$dir/.dangler"
  ln -s "/nonexistent/elsewhere" "$dir/.decoy"
  mkdir -p "$dir/.config/nested"
  ln -s "$REPO_DIR/dotfiles/also-gone" "$dir/.config/nested/dead"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "dry run: reports repo-pointing dangler only, changes nothing"
make_target "$TMP/dry"
OUTPUT="$("$SCRIPT" --dry-run "$TMP/dry" 2>&1)"
STATUS=$?
check "exit code is 0" "0" "$STATUS"
check "reports the dangler" "1" \
  "$(printf '%s\n' "$OUTPUT" | grep -c "Dangling symlink: $TMP/dry/.dangler")"
check "reports the nested dangler" "1" \
  "$(printf '%s\n' "$OUTPUT" | grep -c "Dangling symlink: $TMP/dry/.config/nested/dead")"
check "ignores the non-repo decoy" "0" \
  "$(printf '%s\n' "$OUTPUT" | grep -c "decoy")"
check "dangler still present after dry run" "yes" \
  "$([ -L "$TMP/dry/.dangler" ] && echo yes)"

echo "dry run: clean target reports no dangling symlinks"
mkdir -p "$TMP/clean"
OUTPUT="$("$SCRIPT" --dry-run "$TMP/clean" 2>&1)"
check "prints the all-clear line" "1" \
  "$(printf '%s\n' "$OUTPUT" | grep -c "No dangling symlinks")"

# The removal prompt reads from FD 3 (the tty). `script -q` allocates a
# pty and relays our piped stdin to it, so the prompt can be answered
# non-interactively without hijacking the developer's terminal.
run_interactive() {
  # run_interactive <answer> <target_dir>; sets STATUS
  # Two answers: the fixture has two danglers (top-level and nested). The
  # trailing q's quit rather than starve the pty if anything prompts again.
  # The trailing sleep keeps the pipe open: if stdin hits EOF before the
  # script reaches its first prompt, `script` hands the pty an immediate EOF
  # and that first read fails instead of blocking for the relayed answer.
  { printf '%s\n%s\nq\nq\n' "$1" "$1"; sleep 3; } |
    script -q /dev/null "$SCRIPT" "$2" > /dev/null 2>&1
  STATUS=$?
}

echo "removal: [r] deletes the dangler, leaves the decoy"
make_target "$TMP/rm"
run_interactive r "$TMP/rm"
check "exit code is 0" "0" "$STATUS"
check "dangler removed" "yes" \
  "$([ ! -e "$TMP/rm/.dangler" ] && [ ! -L "$TMP/rm/.dangler" ] && echo yes)"
check "nested dangler removed" "yes" \
  "$([ ! -e "$TMP/rm/.config/nested/dead" ] && [ ! -L "$TMP/rm/.config/nested/dead" ] && echo yes)"
check "decoy untouched" "yes" "$([ -L "$TMP/rm/.decoy" ] && echo yes)"

echo "removal: [s] leaves the dangler in place"
make_target "$TMP/skip"
run_interactive s "$TMP/skip"
check "exit code is 0" "0" "$STATUS"
check "dangler still present" "yes" "$([ -L "$TMP/skip/.dangler" ] && echo yes)"
check "nested dangler still present" "yes" \
  "$([ -L "$TMP/skip/.config/nested/dead" ] && echo yes)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
