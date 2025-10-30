# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for macOS development environment configuration. It manages shell configurations (bash/zsh), Neovim setup, and terminal (Ghostty) settings.

## Architecture

### Shell Configuration
- **zshrc**: Primary shell configuration using Oh-My-Zsh framework
  - Uses random theme selection
  - Homebrew initialization via `/opt/homebrew/bin/brew shellenv`
  - rbenv for Ruby version management
  - Docker CLI completions enabled
  - Custom PATH includes: Ruby gems, Docker, LM Studio CLI
  - PostgreSQL alias: `start_postgres` command available

- **bash_profile**: Bash login shell configuration
  - JAVA_HOME setup, git aliases, Rails helpers
  - rbenv initialization
  - Volta integration

- **bashrc**: Bash runtime configuration
  - Java 1.7 configuration
  - Volta and LM Studio PATH additions

- **profile**: Generic shell profile (fallback for POSIX-compliant shells)
  - Volta and LM Studio PATH configuration

- **zprofile**: Minimal, primarily handles Homebrew shellenv initialization

### Neovim Configuration (`config/nvim/`)
- **Plugin Manager**: lazy.nvim (auto-bootstrapping from init.lua)
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
- **Ghostty** terminal emulator configured at `config/ghostty/config`
- Option key mapped as Alt key for better keybinding support

## Key Environment Variables & Paths

- Homebrew: `/opt/homebrew` (Apple Silicon)
- Ruby: Managed by rbenv + Homebrew Ruby at `/opt/homebrew/opt/ruby`
- Java: Uses macOS `java_home` utility
- Docker: Completions and binaries in `~/.docker/`
- LM Studio: CLI available in `~/.lmstudio/bin`
- Volta: Node.js toolchain in `~/.volta`

## Common Aliases

- `glog`: Git log with file names
- `glogme`: Git log filtered to current user
- `ptl`: Tail Rails development log
- `psx`: Process search wrapper
- `start_postgres`: Launch PostgreSQL server from Homebrew installation

## File Installation/Deployment

Use the `install.sh` script for non-destructive symlinking:

```bash
./install.sh                    # Install to $HOME (default)
./install.sh /path              # Install to custom directory
./install.sh --dry-run          # Preview changes without making them
./install.sh --dry-run /path    # Dry run to custom directory
```

**How it works:**
- Files in root directory are prefixed with a dot (e.g., `zshrc` → `~/.zshrc`)
- Files in subdirectories maintain structure (e.g., `config/nvim/init.lua` → `~/.config/nvim/init.lua`)
- Automatically creates necessary parent directories
- Skips files that already exist (won't overwrite)
- Skips symlinks that already point to the correct location
- Warns about symlinks pointing elsewhere
- Auto-skips: `.git`, `.DS_Store`, `README.md`, `CLAUDE.md`, `install.sh`

## Notes

- `.DS_Store` files are gitignored
- PostgreSQL is installed via Homebrew and requires manual starting (use `start_postgres` alias)
