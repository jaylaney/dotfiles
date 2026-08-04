# Dangling Symlink Detection in install.sh — Design

**Date:** 2026-08-04
**Status:** Approved

## Problem

When a `git pull` deletes a file from `dotfiles/` (e.g. the removal of `vimrc`
and `gvimrc`), any installed symlink pointing at it is left dangling in the
target directory. install.sh only creates links; nothing surfaces the dead
ones. Today they are found by accident, or by manually running the heavyweight
`/machine-audit` command.

## Goal

Rerunning `./install.sh` after a pull surfaces every dangling repo-pointing
symlink and offers to remove it, in the script's existing interactive style.
`--dry-run` reports without prompting or changing anything.

## Non-goals

- No state file / manifest of created links (rejected as over-machinery).
- No full recursive scan of every dot-directory in the target (slow, noisy).
- No handling of broken symlinks that do not point into this repo — they are
  none of install.sh's business and must never be touched.
- No automatic (promptless) deletion in normal mode.

## Design

### Detection

A new `check_dangling_symlinks()` function in install.sh, called after the
main install loop in both normal and dry-run modes.

Scan set:

- Depth-1 dot-entries of `$TARGET_DIR` that are symlinks (catches
  `~/.vimrc`-style top-level links).
- Recursive `find -type l` over `$TARGET_DIR/.config`, `$TARGET_DIR/.claude`,
  `$TARGET_DIR/.codex`, and `$TARGET_DIR/.local/bin`, skipping any directory
  that does not exist.

The fixed directory list intentionally covers directories install.sh manages
today; a purely repo-derived list would miss a whole subdirectory deleted
from the repo (exactly the `codex/`-style case this feature exists for).

A symlink is dangling iff **both**:

1. Its resolved destination lies under `$DOTFILES_DIR/` (relative link
   destinations are resolved before the prefix check), and
2. The destination does not exist (`[ ! -e ]` on the link).

### Interaction and output

- **Dry-run mode:** print `[DRY RUN] Dangling symlink: <path> -> <target>`
  for each finding; never prompt, never modify.
- **Normal mode:** per finding, prompt `[r]emove / [s]kip / [q]uit`, reusing
  the existing conflict-resolution prompt's conventions (colors, `/dev/tty`
  input, re-prompt on invalid input). Remove deletes only the symlink itself,
  never its target. Quit exits the script immediately, matching the existing
  `[q]uit` behavior.
- **Nothing found:** a single green `✓ No dangling symlinks` line, consistent
  with the script's per-file reporting style.

### Edge cases

- Custom target directories work unchanged: the scan is rooted at
  `$TARGET_DIR`, which is also what makes the feature testable against a
  temp directory.
- Valid repo-pointing links, and broken links pointing elsewhere, are never
  reported or touched.
- Non-interactive environments (no `/dev/tty`): input falls back to stdin. If
  no input is available at all (the read fails or hits EOF), each prompt
  prints a note that it is skipping that item and returns — the dangling
  prompt leaves the link in place, the conflict prompt skips the file — and
  the script continues to the next item rather than re-prompting.

## Testing

New `tests/install-test.sh` following the repo's stub-based test conventions:

- Fixture: temp repo (`dotfiles/` with a couple of files) + temp target dir.
- Create a dangling repo-pointing symlink and a decoy: an unrelated broken
  symlink pointing outside the repo.
- Assert `--dry-run` reports exactly the repo-pointing dangler and not the
  decoy, and exits successfully.
- Assert the removal path deletes the dangler and leaves the decoy (by piping
  `r` if the prompt reads stdin in test conditions; if `/dev/tty`-only makes
  that infeasible, cover detection only and note it in the test).

## Documentation updates

- install.sh `--help` text: mention the post-install dangling-link check.
- README.md, CLAUDE.md, AGENTS.md: update the install/deployment sections.
- `dotfiles/claude/commands/machine-audit.md`: fix the now-stale claim that
  "install.sh does not prune these" — after this change it prunes
  interactively; machine-audit remains the broader drift audit.
