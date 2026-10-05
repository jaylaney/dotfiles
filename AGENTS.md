# AGENTS.md

This is the agent-neutral working guide for this repository. Keep it accurate to
the checked-in configuration rather than to a particular coding assistant.
`CLAUDE.md` is tool-specific documentation and should be maintained separately;
do not rewrite or synchronize it unless the user explicitly asks.

## Repository Purpose

This repository manages a personal macOS development environment. Files under
`dotfiles/` are the source of truth and are installed as symlinks by
`install.sh`.

## Repository Layout

```text
.
├── dotfiles/
│   ├── bash_profile
│   ├── bashrc
│   ├── profile
│   ├── zprofile
│   ├── zshrc
│   ├── tmux.conf
│   ├── claude/
│   │   ├── CLAUDE.md
│   │   ├── commands/
│   │   ├── hooks/
│   │   ├── settings.json
│   │   └── statusline-command.sh
│   ├── codex/
│   │   └── AGENTS.md
│   ├── config/
│   │   ├── gh/
│   │   ├── git/
│   │   ├── ghostty/
│   │   ├── nvim/
│   │   └── opencode/
│   └── local/
│       └── bin/
├── docs/superpowers/
│   ├── plans/
│   └── specs/
├── tests/
├── install.sh
├── AGENTS.md
├── CLAUDE.md
├── LICENSE
└── README.md
```

Paths are case-sensitive in documentation and code. For example, the existing
assistant configuration directories are `dotfiles/claude/` and
`dotfiles/codex/`, not `dotfiles/Claude/` or `dotfiles/Codex/`.

## Installation Model

`install.sh` accepts options followed by an optional target directory:

```bash
./install.sh --help
./install.sh --dry-run
./install.sh --dry-run /path/to/target
./install.sh "$HOME"
```

With no arguments, the script prints help and exits. During a real install it
prompts before replacing conflicts and offers skip, diff, overwrite-with-backup,
or quit.

After the install pass it scans the target's top-level dot-entries plus
`.config`, `.claude`, `.codex`, and `.local/bin` for symlinks pointing into
`dotfiles/` whose source no longer exists, and prompts remove/skip/quit for
each; `--dry-run` reports without prompting.

The destination is derived from the path relative to `dotfiles/`:

- `dotfiles/zshrc` becomes `<target>/.zshrc`.
- `dotfiles/config/nvim/init.lua` becomes
  `<target>/.config/nvim/init.lua`.
- `dotfiles/local/bin/update-all` becomes
  `<target>/.local/bin/update-all`.

Parent directories are created as needed. Existing symlinks to the correct
absolute source are left unchanged. Because installed commands remain symlinks,
their executable bit must be set on the source file in this repository.

Installed symlinks read directly from the checkout that supplied them. Editing
source files or switching branches in that checkout can immediately change the
live configuration without rerunning the installer. Some applications write
through these symlinks, so settings changes can also become repository edits.

## Configuration Notes

See [README.md](README.md#current-configuration) for the configuration inventory
and [prerequisites](README.md#prerequisites). Inspect the relevant source files
when changing behavior.

- Neovim uses built-in `vim.pack` (Neovim 0.12+). Plugin modules under
  `dotfiles/config/nvim/lua/plugins/` are required from `init.lua`.
- The lockfile `dotfiles/config/nvim/nvim-pack-lock.json` is tracked and
  symlinked; `vim.pack.update()` writes through the symlink and dirties the repo.
- `dotfiles/config/git/ignore` globally ignores Claude local settings files.
- `dotfiles/claude/settings.json` is symlinked to `~/.claude/settings.json`
  and Claude Code writes settings changes through it, including TUI toggles.
- `dotfiles/claude/` and `dotfiles/codex/AGENTS.md` are installable tool
  configuration, not repository-wide agent instructions. The latter is
  symlinked to `~/.codex/AGENTS.md` as user-level Codex guidance.

## Working Rules

- Inspect the source file and relevant neighboring configuration before
  changing behavior; this repository contains personal preferences that may
  look unusual but are intentional.
- Preserve unrelated working-tree changes. Do not normalize, reorganize, or
  modernize settings outside the requested scope.
- Add installable configuration beneath `dotfiles/` and follow the existing
  destination mapping. Repository documentation belongs at the repository
  root or under `docs/`, not under `dotfiles/`.
- Prefer `$HOME` in new portable configuration. Preserve existing absolute
  paths unless the requested change includes making them portable.
- New command scripts should use `#!/usr/bin/env bash`, quote expansions, avoid
  `eval`, and be committed with the executable bit set.
- Never add credentials, access tokens, machine-local secrets, or generated
  caches. Keep machine-local Claude settings covered by the global Git ignore.
- Describe only active behavior as active. Label planned or commented-out
  configuration explicitly so documentation does not drift from the files.
- Do not run the real installer against the user's home directory merely to
  validate a change. Use `--dry-run` with a temporary target.

## Validation

Choose checks proportional to the files changed:

```bash
bash -n install.sh
shellcheck install.sh

validation_target="$(mktemp -d)"
./install.sh --dry-run "$validation_target"

git diff --check
```

- Run `bash -n` and `shellcheck` on every changed Bash script when ShellCheck is
  available.
- For Zsh configuration changes, use `zsh -n dotfiles/zshrc` (or the changed
  Zsh file) to check syntax. Do not source it merely to validate syntax:
  sourcing executes Homebrew, Starship, and completion setup.
- For installer changes, use a temporary target and verify the reported source
  and destination paths. Exercise interactive conflict handling only in an
  isolated temporary target.
- For installer changes, run `bash tests/install-test.sh`; it tests
  dangling-symlink detection and interactive removal in temporary targets.
- For `update-all` changes, run `bash tests/update-all-test.sh`; it uses command
  stubs and does not perform real upgrades.
- For command-orchestration scripts, prefer deterministic `PATH` stubs over
  real package upgrades. Include a failure before a later successful command so
  tests prove execution continues, the complete summary is printed, and the
  aggregate exit status is nonzero.
- Avoid validation commands that bootstrap plugins or mutate the live editor,
  shell, package-manager, or assistant configuration unless the user asks for
  an integration test.

## Relevant Design Specs

- For update orchestration, use the [update-all design](docs/superpowers/specs/2026-07-24-update-all-design.md),
  [implementation](dotfiles/local/bin/update-all), and [stub-based tests](tests/update-all-test.sh).
- For installer cleanup, use the [dangling-symlink detection design](docs/superpowers/specs/2026-08-04-dangling-symlink-detection-design.md),
  [installer](install.sh), and [temporary-target tests](tests/install-test.sh).
