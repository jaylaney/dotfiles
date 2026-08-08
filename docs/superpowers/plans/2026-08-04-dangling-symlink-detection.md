# Dangling Symlink Detection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After its install pass, `install.sh` detects symlinks that point into this repo but whose source file no longer exists, and offers to remove each one (`--dry-run` reports only).

**Architecture:** One new detection function (`check_dangling_symlinks`) and one new prompt function (`prompt_dangling_removal`) in `install.sh`, called once after the main install loop. Detection scans depth-1 dot-entries of `$TARGET_DIR` plus recursive walks of `.config`, `.claude`, `.codex`, and `.local/bin`. A stub-based test file `tests/install-test.sh` exercises both modes against temp target directories.

**Tech Stack:** Bash (macOS system bash 3.2), BSD `find`, `script` (for pty-based prompt testing).

**Spec:** `docs/superpowers/specs/2026-08-04-dangling-symlink-detection-design.md`

## Global Constraints

- Must run on macOS system bash 3.2 (`#!/usr/bin/env bash` may resolve there): no associative arrays, no `${var,,}`, no `mapfile`.
- `install.sh` runs under `set -e`: any command that can legitimately return non-zero inside loops/functions must be guarded (`|| true`, or `if`-form instead of `[[ ]] &&`).
- Only symlinks whose destination resolves under `$DOTFILES_DIR/` may ever be reported or removed. Broken symlinks pointing elsewhere are untouchable.
- Removal deletes only the symlink itself (`rm "$link"`), never anything it points at.
- Follow install.sh's existing conventions exactly: color variables (`GREEN`/`YELLOW`/`RED`/`BLUE`/`NC`), `echo -e`, prompts read from FD 3 (`read -p "Choice: " -r choice_input <&3`), `[q]uit` exits 0 with "Installation cancelled by user".
- Tests must never touch `$HOME` — all install runs target directories under `mktemp -d`.
- Tests follow the repo's existing stub-test conventions (see `tests/update-all-test.sh`): `set -u`, `check()` with PASS/FAIL counters, `trap 'rm -rf "$TMP"' EXIT`, exit 1 on any failure.

---

### Task 1: Detection and dry-run reporting

**Files:**
- Modify: `install.sh` (new function after `prompt_conflict_resolution`, ends line 185; call site after the main loop, line 309)
- Test: `tests/install-test.sh` (create)

**Interfaces:**
- Consumes: existing globals `TARGET_DIR`, `DOTFILES_DIR`, `DRY_RUN`, color vars.
- Produces: `check_dangling_symlinks()` — no args; scans, prints findings; in normal mode Task 1 prints a warning line per finding (Task 2 replaces that line with an interactive prompt). Output strings later tasks and tests rely on: `[DRY RUN] Dangling symlink: <link> -> <dest>` and `✓ No dangling symlinks`.

- [ ] **Step 1: Write the failing test**

Create `tests/install-test.sh` (mode 755):

```bash
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
  # make_target <dir>: target with one repo-pointing dangler and one decoy
  local dir="$1"
  mkdir -p "$dir"
  ln -s "$REPO_DIR/dotfiles/no-such-file" "$dir/.dangler"
  ln -s "/nonexistent/elsewhere" "$dir/.decoy"
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
check "ignores the non-repo decoy" "0" \
  "$(printf '%s\n' "$OUTPUT" | grep -c "decoy")"
check "dangler still present after dry run" "yes" \
  "$([ -L "$TMP/dry/.dangler" ] && echo yes)"

echo "dry run: clean target reports no dangling symlinks"
mkdir -p "$TMP/clean"
OUTPUT="$("$SCRIPT" --dry-run "$TMP/clean" 2>&1)"
check "prints the all-clear line" "1" \
  "$(printf '%s\n' "$OUTPUT" | grep -c "No dangling symlinks")"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x tests/install-test.sh && ./tests/install-test.sh`
Expected: FAIL on "reports the dangler" (count 0) and "prints the all-clear line" (count 0); the exit-code and decoy checks may already pass.

- [ ] **Step 3: Write minimal implementation**

In `install.sh`, insert after `prompt_conflict_resolution` (after line 185, before `should_skip`):

```bash
# Find symlinks in the managed directories that point into this repo but
# whose source no longer exists (left behind when repo files are deleted)
check_dangling_symlinks() {
    local dangling=()
    local link dest dir

    while IFS= read -r -d '' link; do
        dest="$(readlink "$link")"
        # Resolve relative destinations against the link's directory
        if [[ "$dest" != /* ]]; then
            dest="$(cd "$(dirname "$link")" && pwd)/$dest"
        fi
        if [[ "$dest" == "$DOTFILES_DIR"/* ]] && [[ ! -e "$link" ]]; then
            dangling+=("$link")
        fi
    done < <(
        find "$TARGET_DIR" -maxdepth 1 -name ".*" -type l -print0 2>/dev/null
        for dir in "$TARGET_DIR/.config" "$TARGET_DIR/.claude" "$TARGET_DIR/.codex" "$TARGET_DIR/.local/bin"; do
            if [[ -d "$dir" ]]; then
                find "$dir" -type l -print0 2>/dev/null
            fi
        done
    )

    if [[ ${#dangling[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓ No dangling symlinks${NC}"
        return 0
    fi

    for link in "${dangling[@]}"; do
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${RED}[DRY RUN] Dangling symlink: $link -> $(readlink "$link")${NC}"
        else
            echo -e "${YELLOW}⚠ Dangling symlink: $link -> $(readlink "$link")${NC}"
        fi
    done
}
```

Then wire the call site. Replace (currently line 309-311):

```bash
done < <(find "$DOTFILES_DIR" -type f -print0)

echo ""
```

with:

```bash
done < <(find "$DOTFILES_DIR" -type f -print0)

echo ""
check_dangling_symlinks

echo ""
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./tests/install-test.sh`
Expected: `5 passed, 0 failed`, exit 0. Also run `bash -n install.sh` (syntax check) and `./install.sh --dry-run "$(mktemp -d)"` for a clean-target smoke run ending in `✓ No dangling symlinks`.

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/install-test.sh
git commit -m "Detect dangling repo symlinks in install.sh (dry-run reports)"
```

---

### Task 2: Interactive removal prompt

**Files:**
- Modify: `install.sh` (new `prompt_dangling_removal` after `prompt_conflict_resolution`; normal-mode branch of `check_dangling_symlinks` from Task 1 changes to call it)
- Test: `tests/install-test.sh` (append two scenarios)

**Interfaces:**
- Consumes: `check_dangling_symlinks()` from Task 1; existing FD-3 prompt convention (`exec 3</dev/tty 2>/dev/null || exec 3<&0`, install.sh line 291).
- Produces: `prompt_dangling_removal(link_path)` — prompts `[r]emove / [s]kip / [q]uit`; returns 0 after remove, 1 after skip, exits 0 on quit.

- [ ] **Step 1: Write the failing test**

Append to `tests/install-test.sh`, before the final summary block (`echo` / `echo "$PASS passed..."`):

```bash
# The removal prompt reads from FD 3 (the tty). `script -q` allocates a
# pty and relays our piped stdin to it, so the prompt can be answered
# non-interactively without hijacking the developer's terminal.
run_interactive() {
  # run_interactive <answer> <target_dir>; sets STATUS
  printf '%s\n' "$1" | script -q /dev/null "$SCRIPT" "$2" > /dev/null 2>&1
  STATUS=$?
}

echo "removal: [r] deletes the dangler, leaves the decoy"
make_target "$TMP/rm"
run_interactive r "$TMP/rm"
check "exit code is 0" "0" "$STATUS"
check "dangler removed" "yes" \
  "$([ ! -e "$TMP/rm/.dangler" ] && [ ! -L "$TMP/rm/.dangler" ] && echo yes)"
check "decoy untouched" "yes" "$([ -L "$TMP/rm/.decoy" ] && echo yes)"

echo "removal: [s] leaves the dangler in place"
make_target "$TMP/skip"
run_interactive s "$TMP/skip"
check "exit code is 0" "0" "$STATUS"
check "dangler still present" "yes" "$([ -L "$TMP/skip/.dangler" ] && echo yes)"
```

Note: these runs are non-dry-run, so install.sh also creates real symlinks for every repo file inside the temp target. That is expected and harmless — the temp dir is deleted by the trap.

- [ ] **Step 2: Run test to verify it fails**

Run: `./tests/install-test.sh`
Expected: FAIL on "dangler removed" (Task 1 only prints a warning; the link survives). The `[s]` scenario may pass trivially. If `script -q` proves unable to relay piped input on this platform (both new scenarios fail with the dangler untouched and no prompt output in `$TMP`), fall back per spec: keep only a detection assertion for normal mode and add a comment in the test explaining why — do not silently drop coverage.

- [ ] **Step 3: Write minimal implementation**

In `install.sh`, insert after `prompt_conflict_resolution` (directly before `check_dangling_symlinks` from Task 1):

```bash
# Interactive prompt for removing a dangling symlink
prompt_dangling_removal() {
    local target="$1"
    local dest="$(readlink "$target")"

    while true; do
        echo ""
        echo -e "${YELLOW}⚠ Dangling symlink: source no longer exists in repo${NC}"
        echo -e "  Target: $target"
        echo -e "  Points to: $dest"
        echo ""
        echo -e "Options: ${RED}[r]${NC}emove  ${GREEN}[s]${NC}kip  ${YELLOW}[q]${NC}uit"
        # Read from FD 3 (terminal) not from stdin which is hijacked by the find loop
        read -p "Choice: " -r choice_input <&3
        choice="${choice_input:0:1}"
        echo ""

        case $choice in
            r|R)
                rm "$target"
                echo -e "${GREEN}✓ Removed: $target${NC}"
                return 0
                ;;
            s|S)
                echo -e "${YELLOW}Skipping: $target${NC}"
                return 1
                ;;
            q|Q)
                echo -e "${RED}Installation cancelled by user${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                continue
                ;;
        esac
    done
}
```

Then in `check_dangling_symlinks`, replace the normal-mode branch:

```bash
        else
            echo -e "${YELLOW}⚠ Dangling symlink: $link -> $(readlink "$link")${NC}"
        fi
```

with:

```bash
        else
            prompt_dangling_removal "$link" || true
        fi
```

(The `|| true` matters: skip returns 1 and install.sh runs under `set -e`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `./tests/install-test.sh`
Expected: `10 passed, 0 failed`, exit 0. Also run `bash -n install.sh`.

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/install-test.sh
git commit -m "Prompt to remove dangling symlinks during install"
```

---

### Task 3: Documentation updates

**Files:**
- Modify: `install.sh:35-41` (help text INTERACTIVE MODE section)
- Modify: `README.md` (Features list ~line 19; Interactive Mode section ~line 53)
- Modify: `CLAUDE.md` (File Installation/Deployment section, "How it works" list)
- Modify: `AGENTS.md` (Installation Model section, ~line 67-69)
- Modify: `dotfiles/claude/commands/machine-audit.md:23-26`

**Interfaces:**
- Consumes: behavior implemented in Tasks 1-2 (prompt keys, scanned directories, dry-run semantics). No code produced.

- [ ] **Step 1: Update install.sh help text**

In the `INTERACTIVE MODE:` heredoc section, after the `[q]uit` line, add:

```
    After the install pass, the script scans for symlinks that point into
    this repo but whose source no longer exists (e.g. deleted by a git pull)
    and prompts for each:

    [r]emove     - Delete the dangling symlink
    [s]kip       - Leave it in place
    [q]uit       - Exit installation immediately
```

- [ ] **Step 2: Update README.md**

In `## Features`, after the "Non-destructive symlinking" bullet, add:

```markdown
- 🧹 **Dangling link cleanup** - Detects symlinks left behind when repo files are deleted and offers to remove them
```

At the end of the `## Interactive Mode` section (after the existing prompt bullets), add:

```markdown
After the install pass, the script checks `~`, `~/.config`, `~/.claude`, `~/.codex`, and `~/.local/bin` for symlinks that point into this repo but whose source no longer exists (left behind when a pull deletes repo files) and prompts **[r]emove / [s]kip / [q]uit** for each. `--dry-run` reports them without prompting.
```

- [ ] **Step 3: Update CLAUDE.md and AGENTS.md**

CLAUDE.md, in the **How it works** list under `## File Installation/Deployment`, add a final bullet:

```markdown
- After the install pass, scans the managed directories for symlinks pointing into the repo whose source is gone and prompts [r]emove / [s]kip / [q]uit (`--dry-run` reports only)
```

AGENTS.md, in `## Installation Model`, after the sentence ending "…offers skip, diff, overwrite-with-backup, or quit.", add:

```markdown
After the install pass it scans the target's top-level dot-entries plus
`.config`, `.claude`, `.codex`, and `.local/bin` for symlinks pointing into
`dotfiles/` whose source no longer exists, and prompts remove/skip/quit for
each; `--dry-run` reports without prompting.
```

- [ ] **Step 4: Fix the stale claim in machine-audit.md**

Replace:

```
   - Dangling symlinks: scan `$HOME`, `~/.config`, `~/.claude`, `~/.codex`,
     and `~/.local/bin` for symlinks pointing into this repo whose targets no
     longer exist (left behind when repo files are deleted; install.sh does
     not prune these).
```

with:

```
   - Dangling symlinks: scan `$HOME`, `~/.config`, `~/.claude`, `~/.codex`,
     and `~/.local/bin` for symlinks pointing into this repo whose targets no
     longer exist (left behind when repo files are deleted; `./install.sh`
     detects and offers to remove these in the directories it manages, but
     this audit also catches ones elsewhere).
```

- [ ] **Step 5: Verify and commit**

Run: `./tests/install-test.sh && ./tests/update-all-test.sh && ./tests/claude-settings-test.sh && bash -n install.sh && ./install.sh --help | grep -c "r\]emove"`
Expected: all test suites pass; help output contains the `[r]emove` line (grep count ≥ 1).

```bash
git add install.sh README.md CLAUDE.md AGENTS.md dotfiles/claude/commands/machine-audit.md
git commit -m "Document dangling symlink detection"
```
