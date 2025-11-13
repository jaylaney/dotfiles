# Repository Guidelines

## Project Structure & Module Organization
All shipping configs live in `dotfiles/`, mirroring the desired layout inside `$HOME`. Root-level files (`zshrc`, `vimrc`, `tmux.conf`, etc.) become dot-prefixed when linked, while nested assets under `dotfiles/config/` (such as `nvim/` and `ghostty/`) retain their subdirectories. `install.sh` is the only executable entry point and handles discovery, filtering, and symlinking; keep helper scripts colocated with it to avoid surfacing extra files to end users. Documentation is split between `README.md` (user-facing), `CLAUDE.md` (architecture notes), and this contributor guide.

## Build, Test, and Development Commands
- `./install.sh --dry-run`: Enumerates every link operation without touching the filesystem—use this before submitting changes to verify paths and skips.
- `./install.sh $HOME`: Runs the fully interactive installer with conflict prompts; ideal for smoke-testing happy paths.
- `./install.sh /tmp/test-home`: Targets a disposable directory so you can inspect the resulting tree or run `diff -r` against expectations.
Pass `--help` whenever you add new flags to confirm the usage text stays accurate.

## Coding Style & Naming Conventions
Shell work should stay POSIX-friendly but use Bash-only features sparingly and document them inside `install.sh`. Follow the established 4-space indentation in shell functions, uppercase constant variables (`SKIP_FILES`), and lower_snake_case helpers (`show_diff`). Configuration files keep their native conventions: Vimscript favors 2-space indents and comma leaders, Lua modules under `dotfiles/config/nvim/lua/` mirror lazy.nvim's plugin-per-file pattern, and filenames remain extensionless unless the target program requires one. Name new dotfiles exactly as they should appear in `$HOME` to keep the installer logic simple.

## Testing Guidelines
There is no automated CI, so lean on deterministic manual checks. Run `./install.sh --dry-run` after modifying the installer or adding files to confirm they are discovered and not skipped. For resolver changes, create a throwaway directory, run the installer, and inspect symlinks with `ls -l` plus `readlink`. When editing Neovim or Vim configs, open those editors locally to ensure they parse cleanly; note regressions and how to reproduce them in your PR.

## Commit & Pull Request Guidelines
Git history favors concise, imperative subject lines (`set term type`, `Tmux integration`). Keep commits focused on a single topic and include rationale when behavior changes (e.g., why a new default alias is needed). Pull requests should summarize the motivation, list notable files touched, and paste the exact verification commands/output (dry-runs, editor launch checks, screenshots for Ghostty themes). Reference related issues when relevant and call out any manual follow-up steps reviewers must perform.

## Security & Configuration Tips
Never commit machine-specific secrets, API keys, or licenses; prefer sourcing them from untracked local files that the installer deliberately skips. When introducing new tools, document any required Homebrew formulas or environment variables in `README.md` so contributors can reproduce the setup. Before merging, double-check that newly added files are safe to symlink on all platforms the repo targets (currently macOS) and that backups remain enabled for destructive operations.
