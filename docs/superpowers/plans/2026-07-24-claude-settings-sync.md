# claude-settings Sync Tooling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep `~/.claude/settings.json` and `dotfiles/claude/settings.json` in sync by copying (never symlinking — a Claude Code bug ignores `defaultMode: "auto"` through a symlink), with a review-driven `/settings-sync` Claude command on top.

**Architecture:** A whole-file mechanics script (`dotfiles/local/bin/claude-settings` with `status`/`diff`/`save`/`apply`) plus a Claude command (`dotfiles/claude/commands/settings-sync.md`) that layers per-setting judgment on it, plus a one-line install.sh skip so the installer can never symlink settings.json. Sandbox tests run the real script against a fake repo and fake `$HOME`.

**Tech Stack:** bash (macOS system bash 3.2-compatible), shellcheck for linting.

**Spec:** `docs/superpowers/specs/2026-07-24-claude-settings-sync-design.md`

## Global Constraints

- Both new scripts run under macOS system bash 3.2 (`#!/usr/bin/env bash`; no bash-4-only features). Quote all expansions; no `eval`. Source files carry the executable bit.
- settings.json is NEVER symlinked by any of this tooling — `apply` always produces a regular file via `cp`, even when the live path is currently a symlink.
- Live file: `$HOME/.claude/settings.json`. Repo file: resolved from the script's own symlink-resolved location as `<script_dir>/../../claude/settings.json` — no hardcoded repo path.
- Backup format, exactly: `settings.json.backup.YYYYMMDD_HHMMSS` (via `date +%Y%m%d_%H%M%S`), created only by `apply`, only when a live file/symlink exists.
- Exit codes: `status`/`diff` exit 0 when in sync, 1 when the files differ or a side is missing; `save`/`apply` exit 1 on errors (message to stderr); unknown/missing subcommand prints usage to stderr and exits 2.
- `save`/`apply` are no-ops printing `already in sync` (exit 0) when files already match — except `apply` still replaces a symlinked live file.
- Tests never touch the real `~/.claude` — every invocation runs with a sandboxed `HOME`.
- No jq, no merge logic, no interactive prompts in the script.

---

### Task 1: `claude-settings` script with sandbox tests (TDD)

**Files:**
- Create: `tests/claude-settings-test.sh`
- Create: `dotfiles/local/bin/claude-settings`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: executable `dotfiles/local/bin/claude-settings` implementing `status`, `diff`, `save`, `apply` with the exit codes in Global Constraints. Task 2 symlinks it to `~/.local/bin/claude-settings` and writes a Claude command that calls it by those subcommand names.

- [ ] **Step 1: Write the failing test**

Create `tests/claude-settings-test.sh` with exactly this content:

```bash
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
```

Then make it executable:

```bash
chmod +x tests/claude-settings-test.sh
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./tests/claude-settings-test.sh`

Expected: exit code 1 with nearly all of the 25 checks failing because `dotfiles/local/bin/claude-settings` does not exist (the sandbox symlink dangles, so every invocation exits 127). One check ("live content matches repo") can pass vacuously when both files are unreadable, so `1 passed, 24 failed` is also acceptable. Stray `cat: ... No such file or directory` noise on stderr is expected at this stage.

- [ ] **Step 3: Write the script**

Create `dotfiles/local/bin/claude-settings` with exactly this content:

```bash
#!/usr/bin/env bash

# claude-settings: keep ~/.claude/settings.json and the repo copy in sync.
# Copies only — a Claude Code bug ignores defaultMode: "auto" when
# settings.json is a symlink, so this file must never be symlinked.

set -u

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_FILE="$(cd "$(dirname "$SCRIPT_PATH")/../.." && pwd)/claude/settings.json"
LIVE_FILE="$HOME/.claude/settings.json"

usage() {
  cat >&2 <<'EOF'
Usage: claude-settings <status|diff|save|apply>

  status  Report whether live (~/.claude/settings.json) and repo copies match
  diff    Unified diff, repo vs live (+ lines are live-side content)
  save    Copy live -> repo (review with git diff, then commit)
  apply   Copy repo -> live (timestamped backup of the old live file first)

status/diff exit 0 when in sync, 1 when they differ or a side is missing.
EOF
  exit 2
}

cmd_status() {
  if [ ! -f "$LIVE_FILE" ] && [ ! -f "$REPO_FILE" ]; then
    echo "both missing: $LIVE_FILE, $REPO_FILE"
    return 1
  fi
  if [ ! -f "$LIVE_FILE" ]; then
    echo "live missing: $LIVE_FILE"
    return 1
  fi
  if [ ! -f "$REPO_FILE" ]; then
    echo "repo missing: $REPO_FILE"
    return 1
  fi
  if cmp -s "$REPO_FILE" "$LIVE_FILE"; then
    echo "in sync"
    return 0
  fi
  echo "differs (run: claude-settings diff)"
  return 1
}

cmd_diff() {
  if [ ! -f "$REPO_FILE" ] || [ ! -f "$LIVE_FILE" ]; then
    cmd_status
    return
  fi
  if cmp -s "$REPO_FILE" "$LIVE_FILE"; then
    echo "in sync"
    return 0
  fi
  diff -u -L repo -L live "$REPO_FILE" "$LIVE_FILE"
  return 1
}

cmd_save() {
  if [ ! -f "$LIVE_FILE" ]; then
    echo "error: live file missing: $LIVE_FILE" >&2
    return 1
  fi
  if [ -f "$REPO_FILE" ] && cmp -s "$LIVE_FILE" "$REPO_FILE"; then
    echo "already in sync"
    return 0
  fi
  cp "$LIVE_FILE" "$REPO_FILE"
  echo "saved live -> repo: $REPO_FILE"
  echo "review and commit: git diff $REPO_FILE"
}

cmd_apply() {
  local backup
  if [ ! -f "$REPO_FILE" ]; then
    echo "error: repo file missing: $REPO_FILE" >&2
    return 1
  fi
  # A symlinked live file is never left in place — it must become a copy.
  if [ -f "$LIVE_FILE" ] && [ ! -L "$LIVE_FILE" ] && cmp -s "$REPO_FILE" "$LIVE_FILE"; then
    echo "already in sync"
    return 0
  fi
  mkdir -p "$(dirname "$LIVE_FILE")"
  if [ -e "$LIVE_FILE" ] || [ -L "$LIVE_FILE" ]; then
    backup="$LIVE_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    mv "$LIVE_FILE" "$backup"
    echo "backed up live to: $backup"
  fi
  cp "$REPO_FILE" "$LIVE_FILE"
  echo "applied repo -> live: $LIVE_FILE"
}

case "${1-}" in
  status) cmd_status ;;
  diff)   cmd_diff ;;
  save)   cmd_save ;;
  apply)  cmd_apply ;;
  *)      usage ;;
esac
```

Then make it executable (the symlink created in Task 2 inherits this bit):

```bash
chmod +x dotfiles/local/bin/claude-settings
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./tests/claude-settings-test.sh`

Expected: `25 passed, 0 failed`, exit code 0, with `ok:` on every line.

- [ ] **Step 5: Lint both scripts**

Run: `shellcheck dotfiles/local/bin/claude-settings tests/claude-settings-test.sh`
(If shellcheck is missing: `brew install shellcheck` first.)

Expected: no output, exit code 0.

- [ ] **Step 6: Commit**

```bash
git add dotfiles/local/bin/claude-settings tests/claude-settings-test.sh
git commit -m "Add claude-settings script for settings.json sync"
```

---

### Task 2: Installer skip, /settings-sync command, symlinks, docs

**Files:**
- Modify: `install.sh` (the `SKIP_FILES` line, currently line 85)
- Create: `dotfiles/claude/commands/settings-sync.md`
- Modify: `CLAUDE.md` (structure tree, Common Aliases, Notes)
- Modify: `AGENTS.md` (Terminal and Tooling section)
- Creates outside the repo: symlinks `~/.local/bin/claude-settings` and `~/.claude/commands/settings-sync.md`

**Interfaces:**
- Consumes: executable `dotfiles/local/bin/claude-settings` from Task 1, with subcommands `status`/`diff`/`save`/`apply` and exit codes 0 = in sync, 1 = differs/missing.
- Produces: working `claude-settings` command on PATH, `/settings-sync` Claude command, installer that never touches claude/settings.json, updated docs.

- [ ] **Step 1: Make install.sh skip claude/settings.json**

In `install.sh`, replace:

```bash
SKIP_FILES=(".git" ".DS_Store" "README.md" "CLAUDE.md" "install.sh")
```

with:

```bash
# claude/settings.json is skipped: symlinking it breaks Claude Code's
# defaultMode "auto"; the claude-settings script owns that file instead.
SKIP_FILES=(".git" ".DS_Store" "README.md" "CLAUDE.md" "install.sh" "claude/settings.json")
```

- [ ] **Step 2: Verify the skip with a dry run against a temp target**

Never dry-run against `$HOME` for validation. Run:

```bash
tmp_target="$(mktemp -d)"
./install.sh --dry-run "$tmp_target" | grep -E 'claude/settings\.json' || echo "settings.json correctly skipped"
./install.sh --dry-run "$tmp_target" | grep -c 'local/bin/claude-settings'
rm -rf "$tmp_target"
```

Expected: first command prints `settings.json correctly skipped` (no installer line mentions claude/settings.json); second prints `1` (the new script would be symlinked normally).

- [ ] **Step 3: Create the /settings-sync command**

Create `dotfiles/claude/commands/settings-sync.md` with exactly this content:

```markdown
Reconcile Claude settings between the live file (`~/.claude/settings.json`)
and the repo copy (`dotfiles/claude/settings.json`). Both are regular files
kept in sync by copying — never symlink settings.json (a Claude Code bug
ignores `defaultMode: "auto"` through a symlink).

Steps:

1. Run `claude-settings status`. If it reports "in sync", say so and stop.
2. Run `claude-settings diff` (`-` lines = repo side, `+` lines = live side)
   and present each differing setting in plain language: the setting name,
   the repo value, and the live value.
3. Ask which side should win, per differing setting (AskUserQuestion works
   well when there are several).
4. Converge:
   - If every pick favors the live side, run `claude-settings save`.
   - Otherwise, edit the repo file to the chosen merged result, then run
     `claude-settings apply` to push it live (it backs up the old live file
     automatically).
5. Run `claude-settings status` to confirm it now reports "in sync".
6. If the repo file changed, show `git diff dotfiles/claude/settings.json`
   and offer to commit.
```

- [ ] **Step 4: Create the symlinks**

The script symlink is safe (only settings.json itself must not be symlinked):

```bash
mkdir -p "$HOME/.local/bin" "$HOME/.claude/commands"
for pair in \
  "$HOME/.local/bin/claude-settings:/Users/jay/Development/dotfiles/dotfiles/local/bin/claude-settings" \
  "$HOME/.claude/commands/settings-sync.md:/Users/jay/Development/dotfiles/dotfiles/claude/commands/settings-sync.md"; do
  link="${pair%%:*}"; target="${pair#*:}"
  if [ -e "$link" ] || [ -L "$link" ]; then
    echo "already exists:"; ls -l "$link"
  else
    ln -s "$target" "$link"
  fi
done
command -v claude-settings
```

Expected: `command -v` prints `/Users/jay/.local/bin/claude-settings`. If either link already exists and does not point at the repo file, stop and surface it to the user instead of overwriting.

- [ ] **Step 5: Real run**

Run: `claude-settings status && claude-settings diff`

Expected: both print `in sync` and exit 0 (the live and repo files are currently identical). If they differ, do NOT reconcile — report the drift to the user and continue; reconciliation is the user's call via /settings-sync.

- [ ] **Step 6: Document in CLAUDE.md**

Edit 1 — in the repository-structure tree, replace:

```
│   │   ├── commands/
```

with:

```
│   │   ├── commands/  # /commit, /push, /settings-sync
```

Edit 2 — at the end of the "Common Aliases" section, after the `update-all` line, add:

```
- `claude-settings`: Script syncing `~/.claude/settings.json` with the repo copy (`status`/`diff`/`save`/`apply`); `/settings-sync` runs a guided per-setting review in Claude
```

Edit 3 — in the "Notes" section, add this bullet at the end:

```
- `claude/settings.json` is copied, never symlinked: Claude Code ignores `defaultMode: "auto"` when settings.json is a symlink. install.sh skips it; use `claude-settings apply` to install it.
```

- [ ] **Step 7: Document in AGENTS.md**

In the "Terminal and Tooling" section, after the `dotfiles/claude/` bullet (ends "not as repository-wide agent instructions."), add:

```
- `dotfiles/claude/settings.json` syncs with `~/.claude/settings.json` by
  copying only (`claude-settings` script, `/settings-sync` command). Never
  symlink it: Claude Code ignores `defaultMode: "auto"` through a symlink.
  `install.sh` skips this file.
```

- [ ] **Step 8: Commit**

```bash
git add install.sh dotfiles/claude/commands/settings-sync.md CLAUDE.md AGENTS.md
git commit -m "Wire up claude-settings: installer skip, /settings-sync command, docs"
```
