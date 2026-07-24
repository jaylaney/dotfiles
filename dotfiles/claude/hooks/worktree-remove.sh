#!/bin/bash
# WorktreeRemove hook: clean up worktrees created by worktree-create.sh.
# Notification-style — exit code cannot block removal. Only touches paths
# under a .worktrees/ directory; everything else is left to native cleanup.
set -uo pipefail

input=$(cat)
path=$(printf '%s' "$input" | jq -r '.worktree_path // empty')

case "$path" in
  */.worktrees/*) ;;
  *) exit 0 ;;
esac

repo=$(dirname "$(dirname "$path")")
if [ -d "$path" ]; then
  git -C "$repo" worktree remove --force "$path" >&2 || true
fi
git -C "$repo" worktree prune >&2 || true
exit 0
