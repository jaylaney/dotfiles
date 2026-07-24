# Design: `update-all`

**Date:** 2026-07-24
**Status:** Approved

## Purpose

Replace the routine manual upgrade dance (`claude update`, `brew upgrade`, `npm -g update`) with a single command that runs every step and reports what passed and what failed.

## Placement & Installation

- Script lives in the repo at `dotfiles/local/bin/update-all` (bash, executable bit set).
- `install.sh` already symlinks subdirectory files with structure preserved, so it maps to `~/.local/bin/update-all` with no installer changes.
- `~/.local/bin` is already on the PATH (added in `dotfiles/zshrc`), so once symlinked the command is available as `update-all`.
- One-time activation: run `./install.sh $HOME` (or create the single symlink directly).

## Behavior

The script runs these steps, in order:

1. `claude update`
2. `brew upgrade`
3. `brew cleanup`
4. `npm update -g`

Each step goes through a small `run_step` helper that:

- Prints a colored banner naming the step before it runs.
- Runs the command with stdout/stderr streaming directly to the terminal, so progress bars and any interactive prompts (e.g., sudo for casks) work normally.
- Records the step name and exit status for the summary.

## Error Handling

- No `set -e`: a failing step is recorded but never prevents later steps from running.
- After all steps, the script prints a summary — one ✓/✗ line per step, in execution order.
- Exit code is 0 only if every step succeeded, otherwise 1, so `update-all && ...` chains correctly.
- Ctrl-C aborts the whole script (default SIGINT behavior, no trap).

## Out of Scope (YAGNI)

- No flags, log files, or "outdated" pre-reports.
- No explicit `brew update` (implied by `brew upgrade`).
- No handling for non-interactive contexts (cron, CI); this is an interactive convenience script that inherits the login shell's PATH.

## Testing

- `shellcheck` passes on the script.
- Stub-based tests: run the script with a temp directory of `claude`/`brew`/`npm` stubs prepended to `PATH`, so no real upgrades run and the production script is never edited. Each stub records its invocation to a file.
  - Failure path: the stub for an early step (`claude`) exits non-zero while the rest succeed. Assert that every subsequent command still ran (via the stubs' invocation records), that all four summary rows appear in execution order with ✗ only on the failed step, and that the script exits 1. Failing an *early* step is what proves continue-on-error — a `set -e` regression would pass a last-step-fails test.
  - Success path: all stubs exit 0. Assert four ✓ rows and exit 0.
- One real run at the end to confirm the actual commands behave as expected interactively.
