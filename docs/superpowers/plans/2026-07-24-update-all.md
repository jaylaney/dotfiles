# update-all Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A single `update-all` command that runs the routine upgrade dance (`claude update`, `brew upgrade`, `brew cleanup`, `npm update -g`), continues past failures, and prints a pass/fail summary.

**Architecture:** One bash script in `dotfiles/local/bin/` (symlinked to `~/.local/bin/` by the existing `install.sh`, no installer changes) with a `run_step` helper that streams command output to the terminal and records exit codes for an end-of-run summary. A stub-based test script proves continue-on-error behavior without running real upgrades.

**Tech Stack:** bash (macOS system bash 3.2-compatible), shellcheck for linting.

**Spec:** `docs/superpowers/specs/2026-07-24-update-all-design.md`

## Global Constraints

- Both scripts must run under macOS system bash 3.2 (`#!/usr/bin/env bash`, no bash-4-only features like `declare -A` or `${var,,}`).
- `update-all` must NOT use `set -e` — every step runs even if an earlier one fails.
- Step order is fixed: `claude update` → `brew upgrade` → `brew cleanup` → `npm update -g`.
- Step output streams directly to the terminal (never captured), so progress bars and interactive prompts work.
- Colors are emitted only when stdout is a tty; otherwise all color variables are empty strings.
- Summary row format, exactly: `  ✓ <name>: <command>` for success, `  ✗ <name>: <command> (exit N)` for failure, in execution order.
- Exit code: 0 only if every step succeeded, otherwise 1.
- No new runtime dependencies. shellcheck is dev-time only (`brew install shellcheck` if missing).

---

### Task 1: `update-all` script with stub-based tests (TDD)

**Files:**
- Create: `tests/update-all-test.sh`
- Create: `dotfiles/local/bin/update-all`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: executable script at `dotfiles/local/bin/update-all` that exits 0 on all-pass, 1 otherwise, with the exact summary-row format in Global Constraints. Task 2 symlinks and documents it.

- [ ] **Step 1: Write the failing test**

Create `tests/update-all-test.sh` with exactly this content:

```bash
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
```

Then make it executable:

```bash
chmod +x tests/update-all-test.sh
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./tests/update-all-test.sh`

Expected: `0 passed, 5 failed` and exit code 1. The failures occur because `dotfiles/local/bin/update-all` does not exist yet (the script invocation exits 127, the stub log is never written, and no summary rows are printed).

- [ ] **Step 3: Write the script**

Create `dotfiles/local/bin/update-all` with exactly this content:

```bash
#!/usr/bin/env bash

# update-all: run the routine upgrade dance and report pass/fail per step.
# Deliberately no `set -e` — every step runs even if an earlier one fails.

if [ -t 1 ]; then
  GREEN=$'\033[0;32m'
  RED=$'\033[0;31m'
  BLUE=$'\033[0;34m'
  NC=$'\033[0m'
else
  GREEN='' RED='' BLUE='' NC=''
fi

STEP_LABELS=()
STEP_EXITS=()

run_step() {
  local name="$1" status
  shift
  printf '\n%s==> %s: %s%s\n' "$BLUE" "$name" "$*" "$NC"
  "$@"
  status=$?
  STEP_LABELS+=("$name: $*")
  STEP_EXITS+=("$status")
}

run_step "Claude Code" claude update
run_step "Homebrew"    brew upgrade
run_step "Homebrew"    brew cleanup
run_step "npm globals" npm update -g

printf '\n%sSummary%s\n' "$BLUE" "$NC"
failures=0
for i in "${!STEP_LABELS[@]}"; do
  if [ "${STEP_EXITS[$i]}" -eq 0 ]; then
    printf '  %s✓%s %s\n' "$GREEN" "$NC" "${STEP_LABELS[$i]}"
  else
    printf '  %s✗%s %s (exit %s)\n' "$RED" "$NC" "${STEP_LABELS[$i]}" "${STEP_EXITS[$i]}"
    failures=$((failures + 1))
  fi
done

[ "$failures" -eq 0 ] || exit 1
```

Then make it executable (the symlink created in Task 2 inherits this bit):

```bash
chmod +x dotfiles/local/bin/update-all
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./tests/update-all-test.sh`

Expected: `5 passed, 0 failed`, exit code 0, with `ok:` on every line.

- [ ] **Step 5: Lint both scripts**

Run: `shellcheck dotfiles/local/bin/update-all tests/update-all-test.sh`
(If shellcheck is missing: `brew install shellcheck` first.)

Expected: no output, exit code 0.

- [ ] **Step 6: Commit**

```bash
git add dotfiles/local/bin/update-all tests/update-all-test.sh
git commit -m "Add update-all script for the routine upgrade dance"
```

---

### Task 2: Install the symlink, verify a real run, document

**Files:**
- Modify: `CLAUDE.md` (repository-structure tree and Common Aliases section)
- Creates outside the repo: symlink `~/.local/bin/update-all`

**Interfaces:**
- Consumes: executable `dotfiles/local/bin/update-all` from Task 1.
- Produces: working `update-all` command on the user's PATH; documentation in CLAUDE.md.

- [ ] **Step 1: Confirm the install mapping**

Run: `./install.sh --dry-run "$HOME" | grep update-all`

Expected output (source path will be the absolute repo path):

```
[DRY RUN] Would symlink: /Users/jay/.local/bin/update-all -> /Users/jay/Development/dotfiles/dotfiles/local/bin/update-all
```

- [ ] **Step 2: Create the symlink**

Create it directly (equivalent to what `install.sh` would do, but avoids interactive prompts for unrelated pre-existing conflicts):

```bash
mkdir -p "$HOME/.local/bin"
if [ -e "$HOME/.local/bin/update-all" ] || [ -L "$HOME/.local/bin/update-all" ]; then
  echo "already exists:"; ls -l "$HOME/.local/bin/update-all"
else
  ln -s "/Users/jay/Development/dotfiles/dotfiles/local/bin/update-all" "$HOME/.local/bin/update-all"
fi
command -v update-all
```

Expected: `command -v` prints `/Users/jay/.local/bin/update-all`. If the target already exists and is not a symlink to the repo file, stop and surface it to the user instead of overwriting.

- [ ] **Step 3: One real run**

Run: `update-all`

Expected: a `==>` banner per step, live output from each tool, then a Summary block with four ✓ rows and exit code 0. This performs real upgrades and can take several minutes (mostly `brew upgrade`); that is intended — it is the user's routine. If run non-interactively, use a generous timeout; if the environment can't support a long interactive run, report that the first real run should be done by the user in their terminal and continue to Step 4.

- [ ] **Step 4: Document in CLAUDE.md**

Edit 1 — in the repository-structure tree, replace:

```
│   ├── claude/        # Claude Code custom commands
│   │   └── commands/
│   └── config/        # Application configs (nvim, ghostty)
```

with:

```
│   ├── claude/        # Claude Code custom commands
│   │   └── commands/
│   ├── config/        # Application configs (nvim, ghostty)
│   └── local/bin/     # Scripts symlinked into ~/.local/bin
```

Edit 2 — in the same tree, replace:

```
├── install.sh         # Installation script
```

with:

```
├── install.sh         # Installation script
├── tests/             # Stub-based tests for scripts
```

Edit 3 — at the end of the "Common Aliases" section, after the `start_postgres` line, add:

```
- `update-all`: Script (not an alias) that runs `claude update`, `brew upgrade`, `brew cleanup`, and `npm update -g`, continuing past failures and printing a ✓/✗ summary
```

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "Document update-all command"
```
