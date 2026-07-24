---
description: Adversarial code review via codex CLI (current branch or a PR). Manual only — never invoke proactively; run solely when the user explicitly types /codex-review.
allowed-tools: Bash(command -v:*), Bash(codex:*), Bash(git:*), Bash(gh pr view:*), Bash(mktemp:*), Bash(sed:*), Agent
---

Only run this command when the user explicitly invoked `/codex-review`. If you loaded it on your own initiative — because a code review seemed useful or was requested in general terms — stop and ask the user whether they want codex involved; a plain "review this" is not an invocation of this command.

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

Step 1 — run codex, waiting by blocking rather than by ending your turn (a subagent that stops after launching a background job may never be re-invoked when it exits). Never add --dangerously-* flags or any workspace-write sandbox override — codex must stay in its default read-only sandbox. Do not append a custom prompt argument: codex rejects a prompt combined with --base/--uncommitted; its built-in review instructions apply.

1a. Run `OUT=$(mktemp); ERR=$(mktemp); DONE=$(mktemp); echo "$OUT $ERR $DONE"` and note the three paths — shell state does not persist between Bash calls, so use them as literal paths wherever $OUT, $ERR, or $DONE appears below.

1b. Launch codex as ONE Bash call with run_in_background set to true (reviews may exceed the 10-minute foreground cap):

    (cd WORKDIR && codex exec review MODE --ephemeral -o "$OUT" 2> "$ERR"); echo "exit=$?" > "$DONE"

1c. Block until the marker appears — run this in the FOREGROUND with a 570000 ms timeout; if it times out, run it again, up to 12 times total (~2 hours), after which treat it as "codex failed (no exit marker)" and go to Step 4:

    until [ -s "$DONE" ]; do sleep 5; done; cat "$DONE"

Step 2 — read the outcome ($DONE holds exit=CODE):
- CODE non-zero → your report is "codex failed (exit CODE)" plus the last 20 lines of $ERR. Go to Step 4.
- $OUT empty or missing → your report is "codex produced no output" plus the last 20 lines of $ERR. This is a failure — never present it as "no findings". Go to Step 4.
- Otherwise $OUT contains codex's review.

Step 3 — verify every finding independently. For each finding, Read the cited file and line range inside WORKDIR plus enough surrounding context to judge it, then classify:
- CONFIRMED — the issue is real and reachable.
- FALSE POSITIVE — misread, already handled, or unreachable; note why in one line.
- UNCERTAIN — you cannot disprove it; note the caveat.
If codex plainly said there are no findings, verify nothing and report that.

Step 4 — cleanup, always, even after failures: run CLEANUP, then `rm -f "$OUT" "$ERR" "$DONE"`.

Step 5 — return exactly this as your final message (omit empty sections):

## Codex adversarial review — TARGET
**Confirmed (N)**
- `file:line` — issue — one sentence on why it is real
**Uncertain (N)**
- `file:line` — issue — the caveat
**Dropped as false positives (N)**
- `file:line` — issue — one-line reason it is not real
---- SUBAGENT PROMPT END ----
