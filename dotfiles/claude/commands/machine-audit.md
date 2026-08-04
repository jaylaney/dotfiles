---
description: Audit this machine against the dotfiles repo - dead configs, orphaned tool dirs, dangling symlinks
---

Audit this machine for configuration drift: config that references tools no
longer installed here, tool directories no longer referenced by config, and
symlinks left dangling by repo changes. Cleanup decisions are machine-specific
— a tool that is dead on one machine may be active on another — so this
command detects and reports; the user decides what gets removed.

Core rule: verify every claim against the filesystem, never against memory or
docs. The docs describe what the repo intends, not what this machine has. A
tool the user believes uninstalled may be present and current (check versions
and mtimes); a tool the config references may be long gone.

Steps:

1. Sync the repo first: `git pull --ff-only` so the audit runs against
   current configs. If the pull fails, say so and continue against the local
   state.

2. Probe, in read-only mode:
   - Dangling symlinks: scan `$HOME`, `~/.config`, `~/.claude`, `~/.codex`,
     and `~/.local/bin` for symlinks pointing into this repo whose targets no
     longer exist (left behind when repo files are deleted; install.sh does
     not prune these).
   - Orphaned tool directories: for suspects like `~/.volta`, `~/.lmstudio`,
     `~/.oh-my-zsh`, `~/.vim`, `~/.cargo`/`~/.rustup`, and anything similar
     found in `$HOME` — is it referenced by the active shell config? Is its
     binary on PATH? Do versions/mtimes say relic or recently used?
   - Dead config references: every PATH entry, alias target, sourced file,
     and env-var path in the repo's shell configs — does it exist on this
     machine?
   - Doc claims: every tool README/CLAUDE.md/AGENTS.md say is integrated —
     does `command -v` find it?
   - Untracked assistant config: files in `~/.claude` and `~/.codex` (e.g. a
     `CLAUDE.md` or `AGENTS.md`) that are regular files rather than symlinks
     into the repo — candidates to bring under version control.

3. Report findings in two tiers, with evidence (paths, versions, mtimes):
   - Clearly dead: the referenced thing does not exist, or the directory is
     provably unused (not on PATH in the active shell, years-old mtime).
   - Judgment calls: installed-but-maybe-unused tools, configs possibly kept
     for other machines. Do not present these as safe to delete.

4. Get explicit per-item approval before deleting anything. Never bulk-remove
   judgment-call items; remember configs may intentionally serve other
   machines even when the tool is absent here.

5. For approved removals that touch repo files: make the edits, scrub all
   mentions from README.md, CLAUDE.md, and AGENTS.md, syntax-check the edited
   shell files (`zsh -n` / `bash -n`), grep the repo to confirm no references
   remain (historical `docs/` plans are archives — leave them), then offer to
   commit and push so other machines pick up the change.
