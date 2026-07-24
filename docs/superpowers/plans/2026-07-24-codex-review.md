# `/codex-review` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `/codex-review [PR#]` slash command that runs an adversarial codex CLI review of the current branch or a GitHub PR, verifies findings in a background subagent, and reports only confirmed issues.

**Architecture:** One markdown command file (`dotfiles/claude/commands/codex-review.md`, symlinked to `~/.claude/commands/`). Phase 1 of the command resolves the review target in the main conversation (base branch, `--uncommitted`, or PR temp worktree); Phase 2 spawns one background general-purpose subagent that runs `codex exec review` as a background Bash job (no timeout cap), verifies each finding against the code, cleans up, and returns a compact verified report.

**Tech Stack:** Claude Code slash commands (markdown + frontmatter), codex-cli ≥ 0.145.0, git, gh.

**Spec:** `docs/superpowers/specs/2026-07-24-codex-review-design.md`

## Global Constraints

- codex always runs with `--ephemeral` and its default read-only sandbox; NEVER pass `--dangerously-bypass-approvals-and-sandbox`, `--dangerously-bypass-hook-trust`, or any workspace-write sandbox config.
- codex is launched only via background Bash (`run_in_background: true`) — never foreground (10-minute cap).
- An empty codex output file is reported as "codex produced no output", never as "no findings".
- PR mode never touches the user's working tree — temp detached worktree only, always removed afterward.
- Only two files change in this repo: create `dotfiles/claude/commands/codex-review.md`, modify `CLAUDE.md` (plus `AGENTS.md` only if it lists commands).
- Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: Probe codex CLI behavior on a scratch repo

Settles the spec's open question (does `--base` include uncommitted changes?) and proves the invocation plumbing (`-o`, stderr redirect, exit code, planted bug actually found) before the command file is written. This is the "failing test" for the whole feature: if codex can't find a planted bug on a tiny repo, stop and report rather than proceeding.

**Files:**
- No repo files. All work in a `mktemp -d` scratch directory.

**Interfaces:**
- Produces: two recorded facts used verbatim by Task 2 —
  - `BASE_INCLUDES_UNCOMMITTED`: yes/no (does the `--base` review mention the uncommitted-only bug?)
  - `PLANTED_BUG_FOUND`: yes/no (did codex report the committed off-by-one?)

- [ ] **Step 1: Build the scratch repo with a committed bug and an uncommitted bug**

```bash
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/codex-probe.XXXXXX")
cd "$SCRATCH" && git init -q -b main
cat > pay.py <<'EOF'
def total_cents(prices):
    total = 0
    for p in prices:
        total += p
    return total
EOF
git add pay.py && git commit -qm "initial"
git checkout -qb feature
cat > pay.py <<'EOF'
def total_cents(prices):
    total = 0
    for i in range(1, len(prices)):  # committed bug: skips prices[0]
        total += prices[i]
    return total
EOF
git add pay.py && git commit -qm "sum prices"
cat >> pay.py <<'EOF'

def average_cents(prices):
    return total_cents(prices) / len(prices)  # uncommitted bug: ZeroDivisionError on []
EOF
echo "$SCRATCH"
```

- [ ] **Step 2: Run the probe review in the background**

Run with `run_in_background: true` (codex reviews can take minutes):

```bash
cd "$SCRATCH" && codex exec review --base main --ephemeral -o "$SCRATCH/out.md" \
  "Look only for actionable correctness, security, concurrency, data-loss, and regression issues. Verify each finding against the surrounding code before reporting it. Give the file and smallest relevant line range for every finding. No style or nit feedback. If there are no real findings, say so plainly." \
  2> "$SCRATCH/err.log"; echo "exit=$?"
```

- [ ] **Step 3: When it exits, record the two facts**

Read `$SCRATCH/out.md`:
- Mentions the `range(1, len(prices))` off-by-one → `PLANTED_BUG_FOUND=yes`. If no, and out.md is non-empty, retry once with a stronger hint-free prompt is NOT allowed — record `no` and stop the plan; the feature's premise failed and the user must be told.
- Mentions `average_cents` / division-by-zero (the uncommitted function) → `BASE_INCLUDES_UNCOMMITTED=yes`, else `no`.
- Also confirm: exit code was 0, `out.md` non-empty, `err.log` contains only progress noise.

- [ ] **Step 4: Clean up**

```bash
rm -rf "$SCRATCH"
```

No commit — this task changes no repo files.

---

### Task 2: Write the command file, symlink it, commit

**Files:**
- Create: `dotfiles/claude/commands/codex-review.md`
- Symlink (not committed): `~/.claude/commands/codex-review.md`

**Interfaces:**
- Consumes: `BASE_INCLUDES_UNCOMMITTED` from Task 1 (selects one sentence, marked ★ below).
- Produces: the `/codex-review` command available in every Claude Code session.

- [ ] **Step 1: Write `dotfiles/claude/commands/codex-review.md` with exactly this content**

If Task 1 recorded `BASE_INCLUDES_UNCOMMITTED=yes`, DELETE the two lines marked ★ (the DIRTY tracking and the report footnote) — the warning is unnecessary.

`````markdown
---
description: Adversarial code review via codex CLI (current branch or a PR)
allowed-tools: Bash(command -v:*), Bash(codex:*), Bash(git:*), Bash(gh pr view:*), Bash(mktemp:*), Agent
---

Get an adversarial second-model review from the codex CLI, verify its findings, and report only what survives. Optional argument: a GitHub PR number. $ARGUMENTS

# Phase 1 — resolve the review target (do this in the main conversation; it is fast)

Preconditions — stop with a single clear sentence if either fails:
1. `command -v codex` — if missing: suggest `brew install codex`.
2. `git rev-parse --show-toplevel` — must be inside a git repo. Save the output as REPO_ROOT.

**No argument — review local work:**
1. BASE = `git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null | sed 's|^origin/||'`; if empty, the first of `main`, `master` for which `git show-ref --verify --quiet refs/heads/<b>` succeeds. If none, tell the user you could not determine a base branch and stop.
2. CURRENT = `git branch --show-current`.
   - CURRENT == BASE → MODE=`--uncommitted`. If `git status --porcelain` is empty: "Nothing to review — working tree is clean and you're on BASE." Stop.
   - Otherwise → MODE=`--base BASE`. If `git rev-list --count BASE..HEAD` is 0 and `git status --porcelain` is empty: nothing to review, stop.
   - ★ If MODE is `--base` and `git status --porcelain` is non-empty, set DIRTY=yes (codex will not see uncommitted changes; the report must say so).
3. WORKDIR=REPO_ROOT; CLEANUP="true" (nothing to clean up).

**Argument N — review PR #N:**
1. `gh pr view N --json baseRefName,title,url` — on any failure, show gh's error verbatim and stop.
2. `git fetch origin "pull/N/head"` and `git fetch origin BASEREF` (baseRefName from step 1).
3. `WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/codex-review-prN.XXXXXX")/wt` then `git worktree add --detach "$WORKDIR" FETCH_HEAD`.
4. MODE=`--base BASEREF`; CLEANUP=`git -C REPO_ROOT worktree remove --force WORKDIR`.

# Phase 2 — spawn the reviewer subagent

Spawn ONE general-purpose subagent in the background with the prompt below, substituting WORKDIR, MODE, CLEANUP, and TARGET (a one-line description like "branch fix-parser vs main in ~/Development/Notes" or "PR #123: <title>"). Then tell the user the review is running in the background and the verified report will arrive when it finishes. Do not block, poll, or run the review yourself.

---- SUBAGENT PROMPT START ----
You are an adversarial code-review pipeline. Repo copy to review: WORKDIR. Target: TARGET.

Step 1 — run codex. Execute this as ONE Bash call with run_in_background set to true (reviews may exceed 10 minutes; never run it in the foreground). Never add --dangerously-* flags or any workspace-write sandbox override — codex must stay in its default read-only sandbox.

    OUT=$(mktemp); ERR=$(mktemp)
    cd WORKDIR && codex exec review MODE --ephemeral -o "$OUT" \
      "Look only for actionable correctness, security, concurrency, data-loss, and regression issues. Verify each finding against the surrounding code before reporting it. Give the file and smallest relevant line range for every finding. No style or nit feedback. If there are no real findings, say so plainly." \
      2> "$ERR"

Wait for the background job to finish — you will be re-invoked when it exits.

Step 2 — read the outcome:
- Exit non-zero → your report is "codex failed (exit CODE)" plus the last 20 lines of $ERR. Go to Step 4.
- $OUT empty or missing → your report is "codex produced no output" plus the last 20 lines of $ERR. This is a failure — never present it as "no findings". Go to Step 4.
- Otherwise $OUT contains codex's review.

Step 3 — verify every finding independently. For each finding, Read the cited file and line range inside WORKDIR plus enough surrounding context to judge it, then classify:
- CONFIRMED — the issue is real and reachable.
- FALSE POSITIVE — misread, already handled, or unreachable; note why in one line.
- UNCERTAIN — you cannot disprove it; note the caveat.
If codex plainly said there are no findings, verify nothing and report that.

Step 4 — cleanup, always, even after failures: run CLEANUP, then `rm -f "$OUT" "$ERR"`.

Step 5 — return exactly this as your final message (omit empty sections):

## Codex adversarial review — TARGET
**Confirmed (N)**
- `file:line` — issue — one sentence on why it is real
**Uncertain (N)**
- `file:line` — issue — the caveat
**Dropped as false positives (N)**
- `file:line` — issue — one-line reason it is not real
★ If DIRTY=yes, end with: "Note: uncommitted changes were present and were not part of this review."
---- SUBAGENT PROMPT END ----
`````

- [ ] **Step 2: Verify install.sh would map it correctly**

Run: `./install.sh --dry-run $HOME 2>&1 | grep codex-review`
Expected: a line showing `dotfiles/claude/commands/codex-review.md → ~/.claude/commands/codex-review.md` (exact wording per install.sh's dry-run output; the point is the source/target pair).

- [ ] **Step 3: Create the live symlink**

```bash
ln -s "$(git rev-parse --show-toplevel)/dotfiles/claude/commands/codex-review.md" ~/.claude/commands/codex-review.md
ls -l ~/.claude/commands/codex-review.md
```

Expected: symlink exists and resolves. (Matches how commit.md/push.md are installed; skip if install.sh was run instead.)

- [ ] **Step 4: Commit**

```bash
git add dotfiles/claude/commands/codex-review.md
git commit -m "Add /codex-review adversarial review command

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Update documentation

**Files:**
- Modify: `CLAUDE.md` (repository-structure comment listing commands)
- Modify: `AGENTS.md` only if it also lists the commands (check first)

**Interfaces:**
- Consumes: nothing. Produces: docs matching reality.

- [ ] **Step 1: Update the commands comment in CLAUDE.md**

Change the line

```
│   │   ├── commands/  # /commit, /push, /settings-sync
```

to

```
│   │   ├── commands/  # /commit, /push, /settings-sync, /codex-review
```

- [ ] **Step 2: Check AGENTS.md**

Run: `grep -n "settings-sync\|/commit" AGENTS.md`
If it lists the slash commands, add `/codex-review` in the same style; otherwise leave it untouched.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md AGENTS.md
git commit -m "Document /codex-review command

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: End-to-end verification

**Files:** none (scratch repo + this repo read-only).

**Interfaces:**
- Consumes: the finished command file from Task 2.
- Produces: evidence the pipeline works, plus a short acceptance checklist for the user.

- [ ] **Step 1: Re-create the Task 1 scratch repo** (same script, fresh `mktemp -d`, committed off-by-one on `feature`, uncommitted `average_cents` bug).

- [ ] **Step 2: Execute the command file's instructions literally against the scratch repo**

Acting as the command would (Phase 1 then Phase 2): resolve BASE=main, CURRENT=feature, MODE=`--base main`, DIRTY=yes; spawn the background general-purpose subagent with the exact SUBAGENT PROMPT from the command file, substituting WORKDIR/MODE/CLEANUP/TARGET.

- [ ] **Step 3: Check the subagent's report**

Expected:
- The off-by-one appears under **Confirmed** with `pay.py:` and a line number.
- The report ends with the uncommitted-changes note (if Task 1 recorded `BASE_INCLUDES_UNCOMMITTED=no`).
- No raw codex output leaked into the main conversation — only the structured report.

- [ ] **Step 4: Exercise the `--uncommitted` path**

In the scratch repo: `git checkout main`, append the uncommitted `average_cents` bug to `pay.py` again, then run (background Bash):

```bash
cd "$SCRATCH" && codex exec review --uncommitted --ephemeral -o "$SCRATCH/out2.md" \
  "Look only for actionable correctness, security, concurrency, data-loss, and regression issues. Verify each finding against the surrounding code before reporting it. Give the file and smallest relevant line range for every finding. No style or nit feedback. If there are no real findings, say so plainly." \
  2> "$SCRATCH/err2.log"; echo "exit=$?"
```

Expected: exit 0, `out2.md` non-empty and mentions `average_cents` division by zero — proves the base-branch/`--uncommitted` arm of Phase 1 produces a working invocation.

- [ ] **Step 5: Failure path — bad PR number**

In this dotfiles repo run: `gh pr view 99999 --json baseRefName,title,url`
Expected: gh errors; per the command file, Phase 1 stops before any subagent is spawned. (This validates the check itself; no subagent involved.)

- [ ] **Step 6: Clean up scratch repo, then hand the user this acceptance checklist**

```bash
rm -rf "$SCRATCH"
```

User acceptance (needs a real session, not scriptable here):
1. In `~/Development/Notes` on a feature branch: run `/codex-review` — verified report arrives as a background notification.
2. On a repo with an open PR: run `/codex-review <PR#>` — temp worktree created and removed (`git worktree list` clean afterward), report cites PR files.
