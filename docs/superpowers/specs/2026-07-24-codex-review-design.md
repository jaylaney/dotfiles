# Design: `/codex-review` — adversarial code review via codex CLI

**Date:** 2026-07-24
**Status:** Approved

## Purpose

Add a `/codex-review` slash command that gets a second-model adversarial review of in-progress work: it hands the current worktree's changes (or a GitHub PR) to the codex CLI (`codex exec review`, codex-cli ≥ 0.145.0), then has Claude independently verify each finding before reporting, so the user reads confirmed issues rather than raw false positives.

## Placement & Installation

- One new file: `dotfiles/claude/commands/codex-review.md`.
- `install.sh` symlinks it to `~/.claude/commands/codex-review.md` with no installer changes (same mechanism as `/commit` and `/push`), making the command available in every project, not just this repo.
- Requires `codex` on PATH (installed via Homebrew) and `gh` authenticated for PR mode. The command is markdown instructions to Claude; there is no shell script.

## Interface & Target Resolution

- `/codex-review` — review the current worktree's changes:
  - Resolve the base branch from `origin/HEAD`, falling back to `main`, then `master`.
  - On a feature branch → `codex exec review --base <base>`.
  - On the base branch itself → `codex exec review --uncommitted` (staged, unstaged, and untracked changes).
  - Nothing to review → say so and stop; codex is never invoked.
- `/codex-review <PR#>` — review a GitHub PR without touching the user's working tree:
  1. `gh pr view <PR#> --json baseRefName,headRefName` for metadata.
  2. `git fetch origin pull/<PR#>/head`.
  3. Create a temporary detached worktree from `FETCH_HEAD` (created by the main thread during target resolution).
  4. Run the review against that worktree (`codex exec -C <tmpdir> review --base <baseRefName>`).
  5. The subagent removes the temp worktree when the review finishes, always — success or failure.

Open implementation question: whether `--base` includes uncommitted changes on a feature branch. Verify during implementation; if it does not and dirty files exist, the report must note that uncommitted work was not reviewed.

## Architecture: main thread vs. subagent

The main conversation does only the cheap, fast part — target resolution and validation (a handful of git/gh commands) — then spawns **one background subagent** (built-in general-purpose type; its instructions live inline in the command markdown, so no separate agent file). The subagent:

1. Launches codex as a **background job** (`run_in_background`), sidestepping the 10-minute foreground Bash timeout — reviews may run longer.
2. Invocation shape: `codex exec review --ephemeral -o <outfile> [--base <base> | --uncommitted] "<adversarial instructions>" 2><errfile>`, relying on codex's default read-only sandbox. Never pass `workspace-write` or any approval/sandbox bypass flag: a reviewer must not be able to edit anything.
3. When codex exits, reads the review from `<outfile>` and runs the verification pass: for each finding, read the cited file and line range plus enough surrounding context, then classify as **confirmed** (real and reachable), **false positive** (misread, already handled, unreachable), or **uncertain** (cannot disprove).
4. Returns only the compact final report.

The main conversation therefore sees exactly two things: "review started" and the final verified report (delivered as a background-task notification). Raw codex output and verification file-reading never enter the user's context, and the user can keep working while the review runs.

## Adversarial Instructions (the codex prompt)

Baked into the command file as the `PROMPT` argument:

> Look only for actionable correctness, security, concurrency, data-loss, and regression issues. Verify each finding against the surrounding code before reporting it. Give the file and smallest relevant line range for every finding. No style or nit feedback. If there are no real findings, say so plainly.

## Report Format

- Confirmed findings first, each with `file:line` and a one-sentence explanation of why it is real.
- Uncertain findings flagged with their caveat.
- Dropped false positives listed one line each at the end, so the user can see what was filtered and overrule.
- No `--output-schema` in v1: the prompt requires `file:line` per finding and Claude parses the markdown directly.

## Error Handling

Checked in the main thread, before spawning the subagent:

- `codex` not on PATH → report it, suggest `brew install codex`.
- Not a git repository, or nothing to review → say so plainly and stop.
- PR mode: `gh pr view` fails (bad number, no auth, no remote) → surface gh's error and stop.

Inside the subagent:

- codex stderr goes to a temp file — discarded on success, tail surfaced if codex exits non-zero, so auth/network failures are diagnosable.
- An empty output file is reported as "codex produced no output", never conflated with "codex found no issues" (codex is instructed to state the latter explicitly).
- Temp worktree (PR mode) and temp files are always cleaned up.

## Out of Scope (YAGNI)

- No `codex mcp-server` integration or multi-turn debate threads; one-shot review + independent verification was chosen instead.
- No automatic triggering (hooks, pre-PR steps); on-demand only.
- No posting findings to GitHub; the report stays in the conversation and publishing remains a human decision.
- No structured-output schema, custom agent definition file, or helper script in `local/bin`.

## Testing

Markdown command, not a script — no stub tests in `tests/`. Manual verification plan, executed during implementation:

1. Feature branch with a planted bug → the finding survives verification and is reported with `file:line`.
2. On the base branch with only uncommitted changes → exercises the `--uncommitted` path.
3. `/codex-review <PR#>` against a real PR → exercises fetch, temp worktree, and cleanup.
4. Bad PR number → fast failure in the main thread, no subagent spawned.
5. Settle the open question: does `--base` see uncommitted changes on a feature branch?

## Documentation

- Add `/codex-review` to the commands listed in CLAUDE.md's repository-structure comment (alongside `/commit`, `/push`, `/settings-sync`).
