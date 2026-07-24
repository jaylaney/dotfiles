# Design: `claude-settings` sync tooling

**Date:** 2026-07-24
**Status:** Approved

## Purpose

Keep `~/.claude/settings.json` (live) and `dotfiles/claude/settings.json` (repo)
in sync without symlinking — a Claude Code bug prevents `defaultMode: "auto"`
from taking effect when settings.json is a symlink. The workflow is
review-driven: see what differs on each side, decide per setting what to apply,
and converge both sides to the same content.

## Architecture

Three pieces, one job each:

1. **`dotfiles/local/bin/claude-settings`** — mechanics only. Whole-file
   status/diff/copy operations. Never decides anything.
2. **`dotfiles/claude/commands/settings-sync.md`** — judgment layer. A
   `/settings-sync` Claude command that presents per-setting differences and
   applies the user's picks.
3. **`install.sh`** — one-line change: skip `claude/settings.json` so the
   installer can never recreate the symlink bug.

## The Script

Bash 3.2-compatible, shellcheck-clean, installed by `install.sh` as a symlink
at `~/.local/bin/claude-settings` (same model as `update-all`).

**Path resolution:** the live file is `$HOME/.claude/settings.json`. The repo
file is found by resolving the script's own path through symlinks and taking
`../../claude/settings.json` relative to the script's real directory — no
hardcoded repo location.

**Subcommands:**

- `status` — one line: in sync, differs, which side is missing, or — even
  when contents match — `live is a symlink (run: claude-settings apply)`.
  A symlinked live file is the bug state regardless of content, so it is
  never reported as in sync. Exit codes: 0 = both sides are regular files
  with identical content; 1 = they differ, a side is missing, or the live
  file is a symlink; 2 = usage error. Other tooling can test drift cheaply.
- `diff` — unified diff of repo vs live, labeled `repo` and `live` so
  direction is unambiguous. When a side is missing or the live file is a
  symlink it prints the `status` message instead of a diff. Exit codes
  mirror `status`.
- `save` — copy live → repo. No backup on this side: the repo file is
  git-tracked, so `git diff` is the review and git history is the undo.
  Prints a reminder to review and commit. Errors (message to stderr, exit 1)
  if the live file is missing.
- `apply` — copy repo → live. If the live path exists (regular file **or
  symlink**), it is first moved to a timestamped backup
  (`settings.json.backup.YYYYMMDD_HHMMSS`, install.sh's format), then the repo
  file is copied — always producing a regular file, which also repairs the
  symlink-bug scenario. Creates `~/.claude/` if missing. Errors (message to
  stderr, exit 1) if the repo file is missing.

`save` and `apply` are no-ops with an "already in sync" message (exit 0) when
the files already match. No jq, no merge logic, no interactive prompts.

## The Claude Command

`dotfiles/claude/commands/settings-sync.md`, symlinked to
`~/.claude/commands/settings-sync.md` by install.sh (command files are safe to
symlink — only settings.json itself has the bug). The `/settings-sync` flow:

1. Run `claude-settings status`. If in sync, say so and stop.
2. Run `claude-settings diff` and present each differing setting in plain
   language: which side has which value.
3. Ask the user which side wins, per setting.
4. Converge with one invariant: **reconcile in the repo file, then `apply`**.
   Edit the repo copy to the chosen merged result, run `claude-settings apply`
   to push it live. Exception: if every pick favors the live side, just run
   `claude-settings save`.
5. Run `claude-settings status` to confirm "in sync", then offer to commit the
   repo change.

## Installer Change

Add `claude/settings.json` to `SKIP_FILES` in `install.sh` (the existing
`should_skip` exact-match handles subdirectory paths). Fresh-machine setup
becomes: `./install.sh $HOME`, then `claude-settings apply`.

## Out of Scope (YAGNI)

- `settings.local.json` — machine-local by design, globally gitignored.
- Automatic or hook-triggered writes — every sync is review-driven.
- Merge logic in bash — per-setting picks are Claude's job, via file edits.
- Multi-file sync — only settings.json needs copy semantics; everything else
  under `~/.claude/` symlinks fine.

## Testing

- `shellcheck` passes on the script.
- Sandbox tests in `tests/claude-settings-test.sh` (same style as the
  update-all tests): build a fake repo layout and fake `$HOME` in a temp dir,
  copy the real script into the fake repo, invoke it through a symlink from
  the fake home so path resolution is exercised. Assert:
  - `status` exit codes and messages: in-sync (0), differs (1), live missing (1)
  - `status`/`diff` on a symlinked live file with matching content report the
    symlink state and exit 1
  - `save` copies live → repo
  - `apply` copies repo → live and creates exactly one timestamped backup
  - `apply` on a symlinked live file replaces it with a regular file
  - `save`/`apply` no-op with exit 0 when already in sync
- The `/settings-sync` command file is prose for Claude; it is reviewed, not
  machine-tested.

## Documentation Updates

- CLAUDE.md: add a Notes entry that settings.json is copied, never symlinked,
  and why; add `claude-settings` alongside `update-all` in Common Aliases;
  mention `/settings-sync` where the claude/ tree entry is described.
- AGENTS.md: Terminal and Tooling section notes the copy-not-symlink rule for
  settings.json and the sync tooling that owns it.
