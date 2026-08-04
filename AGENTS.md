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

The destination is derived from the path relative to `dotfiles/`:

- `dotfiles/zshrc` becomes `<target>/.zshrc`.
- `dotfiles/config/nvim/init.lua` becomes
  `<target>/.config/nvim/init.lua`.
- `dotfiles/local/bin/update-all` becomes
  `<target>/.local/bin/update-all`.

Parent directories are created as needed. Existing symlinks to the correct
absolute source are left unchanged. Because installed commands remain symlinks,
their executable bit must be set on the source file in this repository.

## Current Configuration

### Shells

- `dotfiles/zshrc` is the primary interactive configuration. It initializes
  Apple Silicon Homebrew, sets Neovim as the editor, adds Homebrew Ruby,
  Ruby gem binaries, and `~/.local/bin` to `PATH`, initializes shell
  completions and Starship, and uses Emacs-style key bindings.
- `dotfiles/bash_profile` and `dotfiles/bashrc` retain legacy Bash setup for
  Homebrew Ruby and Java detection; `dotfiles/profile` is currently empty.
- `dotfiles/zprofile` is currently empty.

### Editors

- Neovim bootstraps `lazy.nvim` from
  `dotfiles/config/nvim/lua/config/lazy.lua`.
- Plugins are declared under `dotfiles/config/nvim/lua/plugins/`.
- The leader is Space and the local leader is Backslash.
- `nvim-tree` replaces netrw. Window navigation uses Control or Option with
  `h`, `j`, `k`, and `l`.
- tmux configuration remains in its top-level file under `dotfiles/`.

### Terminal and Tooling

- Ghostty uses SF Mono, light/dark themes, Option-as-Alt, `xterm-256color`, and
  a Shift-Enter escape binding.
- `dotfiles/config/gh/config.yml` configures GitHub CLI defaults and the
  `gh co` alias.
- `dotfiles/config/git/ignore` globally ignores Claude local settings files.
- `dotfiles/config/opencode/opencode.jsonc` enables the Superpowers plugin.
- `dotfiles/claude/` contains Claude-specific commands and settings, including
  worktree lifecycle hooks and the status line script
  (`statusline-command.sh`, symlinked to `~/.claude/`). Treat these as tool
  configuration, not as repository-wide agent instructions.
- `dotfiles/claude/settings.json` syncs with `~/.claude/settings.json` by
  copying only (`claude-settings` script, `/settings-sync` command). Never
  symlink it: Claude Code ignores `defaultMode: "auto"` through a symlink.
  `install.sh` skips this file.
- `dotfiles/codex/AGENTS.md` holds user-level Codex guidance, symlinked to
  `~/.codex/AGENTS.md`. Like `dotfiles/claude/`, treat it as tool
  configuration, not repository-wide agent instructions.

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
- For installer changes, use a temporary target and verify the reported source
  and destination paths. Exercise interactive conflict handling only in an
  isolated temporary target.
- For command-orchestration scripts, prefer deterministic `PATH` stubs over
  real package upgrades. Include a failure before a later successful command so
  tests prove execution continues, the complete summary is printed, and the
  aggregate exit status is nonzero.
- Avoid validation commands that bootstrap plugins or mutate the live editor,
  shell, package-manager, or assistant configuration unless the user asks for
  an integration test.

## Design Spec: `update-all`

`docs/superpowers/specs/2026-07-24-update-all-design.md` specifies the
`update-all` command, implemented at `dotfiles/local/bin/update-all` with
stub-based tests at `tests/update-all-test.sh`. The design calls for
sequential Claude, Homebrew, cleanup, and global npm update steps; streaming
terminal output; continuation after individual failures; a final per-step
summary; and an aggregate success/failure exit code. The implementation and
tests match that specification.
