# Dotfiles

Personal macOS development environment configuration files with an interactive installation script.

## What's Included

- **Shell configurations**: zsh (primary, with Starship prompt), bash (legacy)
- **Editor configs**: Neovim (with lazy.nvim), Vim, MacVim
- **Terminal**: Ghostty configuration
- **Multiplexer**: tmux configuration
- **Tool configs**: git, gh, opencode
- **Claude Code**: settings, user-level `CLAUDE.md`, custom commands (`/commit`, `/push`, `/settings-sync`, `/codex-review`), worktree lifecycle hooks, and status line script
- **Scripts**: `update-all` and `claude-settings`, installed to `~/.local/bin`
- **Development tools**: Homebrew Ruby, Rust, and Docker integrations

## Features

- 🔄 **Non-destructive symlinking** - Symlinks dotfiles from this repo to your home directory
- 💬 **Interactive conflict resolution** - Prompts for conflicts with skip/diff/overwrite/quit options
- 🔍 **Diff support** - View differences between existing and new files before overwriting
- 💾 **Automatic backups** - Creates timestamped backups when overwriting (e.g., `.zshrc.backup.20251030_143022`)
- 🧪 **Dry-run mode** - Preview changes without making them
- 📁 **Directory preservation** - Only symlinks files, creates necessary parent directories automatically

## Quick Start

```bash
# Clone the repository
git clone https://github.com/jaylaney/dotfiles.git ~/Development/dotfiles
cd ~/Development/dotfiles

# Preview what would be installed (recommended first step)
./install.sh --dry-run

# Install with interactive prompts
./install.sh $HOME

# Or see all options
./install.sh --help
```

## Usage

```bash
./install.sh                    # Show help
./install.sh --help             # Show detailed help message
./install.sh $HOME              # Install to $HOME with interactive prompts
./install.sh /path              # Install to custom directory
./install.sh --dry-run          # Preview changes without making them
```

## Interactive Mode

When the installer detects a conflict (file already exists or symlink points elsewhere), you'll be prompted:

- **[s]kip** - Leave existing file as-is and continue
- **[d]iff** - Show unified diff between existing and new file, then re-prompt
- **[o]verwrite** - Create timestamped backup and replace with new symlink
- **[q]uit** - Exit installation immediately

## How It Works

The installation script:
1. Reads configuration files from `dotfiles/` subdirectory
2. Symlinks files to target directory (default: `$HOME`)
3. Files are prefixed with a dot (e.g., `dotfiles/zshrc` → `~/.zshrc`)
4. Subdirectories maintain structure (e.g., `dotfiles/config/nvim/init.lua` → `~/.config/nvim/init.lua`)
5. Creates parent directories as needed
6. Skips files already correctly symlinked

## Repository Structure

```
/
├── dotfiles/           # Configuration files
│   ├── bash_profile
│   ├── bashrc
│   ├── profile
│   ├── zshrc
│   ├── zprofile
│   ├── vimrc
│   ├── gvimrc
│   ├── tmux.conf
│   ├── claude/        # Claude Code settings, commands, and hooks
│   │   ├── CLAUDE.md  # User-level instructions (symlinked to ~/.claude/CLAUDE.md)
│   │   ├── commands/  # /commit, /push, /settings-sync, /codex-review
│   │   ├── hooks/     # Worktree lifecycle hooks
│   │   └── statusline-command.sh  # Status line: cwd, git branch, worktree name
│   ├── config/        # Application configs (nvim, ghostty, git, gh, opencode)
│   └── local/bin/     # Scripts symlinked into ~/.local/bin
├── install.sh         # Installation script
├── tests/             # Stub-based tests for scripts
├── docs/              # Design specs and implementation plans
├── AGENTS.md          # Agent-neutral repository guidance
├── CLAUDE.md          # Developer documentation
└── README.md          # This file
```

## Scripts

Installed to `~/.local/bin` via symlinks from `dotfiles/local/bin/`:

- **`update-all`** - Runs `claude update`, `brew upgrade`, `brew cleanup`, and `npm update -g`, continuing past failures and printing a ✓/✗ summary
- **`claude-settings`** - Syncs `~/.claude/settings.json` with the repo copy (`status`/`diff`/`save`/`apply`); the `/settings-sync` Claude Code command runs a guided per-setting review

Tests for both live in `tests/` and can be run directly (e.g., `./tests/update-all-test.sh`).

## Notes

- Backups are saved with format: `filename.backup.YYYYMMDD_HHMMSS`
- The script automatically skips: `.git`, `.DS_Store`, documentation files, and `claude/settings.json`
- `claude/settings.json` is copied, never symlinked — Claude Code ignores `defaultMode: "auto"` when settings.json is a symlink. Use `claude-settings apply` to install it
- See `CLAUDE.md` for detailed architecture and configuration information
