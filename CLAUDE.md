# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for macOS development environment configuration. It manages shell configurations (zsh primary, bash legacy), editor setups (Neovim, Vim), terminal (Ghostty), tool configs (git, gh, tmux, opencode), and scripts installed to `~/.local/bin`.

**Repository Structure:**
```
/
├── dotfiles/           # Actual configuration files
│   ├── bash_profile
│   ├── bashrc
│   ├── profile
│   ├── zshrc
│   ├── zprofile
│   ├── vimrc
│   ├── gvimrc
│   ├── tmux.conf
│   ├── claude/        # Claude Code settings, commands, and hooks
│   │   ├── commands/  # /commit, /push, /settings-sync, /codex-review
│   │   ├── hooks/     # Worktree lifecycle hooks (symlinked to ~/.claude/hooks)
│   │   └── statusline-command.sh  # Status line: cwd, git branch, worktree name
│   ├── config/        # Application configs (nvim, ghostty, git, gh, opencode)
│   └── local/bin/     # Scripts symlinked into ~/.local/bin
├── install.sh         # Installation script
├── tests/             # Stub-based tests for scripts
├── docs/              # Design specs and implementation plans
├── AGENTS.md          # Agent-neutral repository guidance
├── CLAUDE.md          # This documentation
├── README.md          # Repository readme
└── .gitignore         # Git ignore rules
```

## Architecture

### Shell Configuration
- **zshrc**: Primary shell configuration (zsh is the active shell)
  - Starship prompt (`starship init zsh`); Oh-My-Zsh remains only as commented-out examples
  - Homebrew initialization via `/opt/homebrew/bin/brew shellenv`
  - `EDITOR`/`VISUAL` set to nvim; emacs-style key bindings (`bindkey -e`)
  - Homebrew Ruby (keg-only) and gem binaries added to PATH — no version manager
  - Docker CLI completions enabled
  - PATH additions: Docker, LM Studio CLI, `~/.local/bin`
  - PostgreSQL alias: `start_postgres` command available

- **bash_profile**: Bash login shell configuration (bash is not the primary shell)
  - Legacy PATH entries (python@3.8, /usr/local), Homebrew Ruby block
  - Custom PS1 with git branch, bash completion
  - Volta, Rust (cargo), LM Studio

- **bashrc**: Bash runtime configuration
  - JAVA_HOME via `/usr/libexec/java_home`, set only when a JDK is installed
  - Volta, LM Studio, Rust (cargo)

- **profile**: Generic shell profile (fallback for POSIX-compliant shells)
  - Volta, LM Studio, Rust (cargo)

- **zprofile**: Currently empty (Homebrew shellenv lives in zshrc)

### Neovim Configuration (`dotfiles/config/nvim/`)
- **Plugin Manager**: lazy.nvim (bootstrapped from `lua/config/lazy.lua`, required by init.lua)
- **Leader Key**: Space (`<leader>` = ` `)
- **Local Leader**: Backslash (`<localleader>` = `\`)
- **Plugin Structure**: Modular - plugins defined in `lua/plugins/*.lua`
- **Key Plugin**: nvim-tree (file explorer with `<C-h/j/k/l>` and `<A-h/j/k/l>` window navigation)
- netrw is disabled in favor of nvim-tree

### Vim Configuration
- **vimrc**: Classic Vim configuration
  - Leader key: `,` (comma)
  - Pathogen plugin manager
  - Molokai colorscheme
  - 2-space indentation
  - Tab mappings, FuzzyFinder, Ack integration
  - Window navigation with `<C-h>` and `<C-l>`

- **gvimrc**: GUI Vim (MacVim) settings
  - Font: Menlo 14pt
  - Dark background
  - No toolbar/scrollbar
  - UTF-8 encoding

### Terminal Configuration
- **Ghostty** terminal emulator configured at `dotfiles/config/ghostty/config`
- Option key mapped as Alt key for better keybinding support

## Key Environment Variables & Paths

- Homebrew: `/opt/homebrew` (Apple Silicon)
- Ruby: Homebrew keg-only Ruby at `/opt/homebrew/opt/ruby` (no version manager)
- Java: Uses macOS `java_home` utility (bashrc, only when a JDK is installed)
- Docker: Completions and binaries in `~/.docker/`
- LM Studio: CLI available in `~/.lmstudio/bin`
- Volta: Node.js toolchain in `~/.volta`
- Rust: `~/.cargo/env` sourced by bash_profile, bashrc, and profile
- Prompt: Starship (initialized in zshrc)

## Common Aliases

- `start_postgres`: Launch PostgreSQL server from Homebrew installation
- `update-all`: Script (not an alias) that runs `claude update`, `brew upgrade`, `brew cleanup`, and `npm update -g`, continuing past failures and printing a ✓/✗ summary
- `claude-settings`: Script syncing `~/.claude/settings.json` with the repo copy (`status`/`diff`/`save`/`apply`); `/settings-sync` runs a guided per-setting review in Claude

## File Installation/Deployment

Use the `install.sh` script for non-destructive symlinking:

```bash
./install.sh                    # Show help (no arguments)
./install.sh --help             # Show help message
./install.sh $HOME              # Install to $HOME with interactive prompts
./install.sh /path              # Install to custom directory
./install.sh --dry-run          # Preview changes without making them
./install.sh --dry-run /path    # Dry run to custom directory
```

**How it works:**
- Reads configuration files from the `dotfiles/` subdirectory
- Files in root of dotfiles/ are prefixed with a dot (e.g., `dotfiles/zshrc` → `~/.zshrc`)
- Files in subdirectories maintain structure (e.g., `dotfiles/config/nvim/init.lua` → `~/.config/nvim/init.lua`)
- Automatically creates necessary parent directories
- Symlinks already pointing to the correct location are left as-is
- Auto-skips: `.git`, `.DS_Store`, `README.md`, `CLAUDE.md`, `install.sh`, `claude/settings.json`

**Interactive conflict resolution:**
When a file/symlink conflict is detected (not in --dry-run mode), you'll be prompted with:
- **[s]kip** - Leave the existing file/symlink as-is and continue
- **[d]iff** - Show unified diff between existing and new file, then re-prompt
- **[o]verwrite** - Backup existing file (with timestamp) and create new symlink
- **[q]uit** - Exit the installation immediately

Backups are created with format: `filename.backup.YYYYMMDD_HHMMSS`

## Notes

- `.DS_Store` files are gitignored
- PostgreSQL is installed via Homebrew and requires manual starting (use `start_postgres` alias)
- `claude/settings.json` is copied, never symlinked: Claude Code ignores `defaultMode: "auto"` when settings.json is a symlink. install.sh skips it; use `claude-settings apply` to install it.
