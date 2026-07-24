#!/bin/bash
# WorktreeCreate hook: create session worktrees in <repo-root>/.worktrees/<name>
# instead of the default .claude/worktrees/<name>.
# Contract: JSON on stdin ({name, cwd, session_id, ...}); print the created
# worktree's path on stdout; exit 0.
set -euo pipefail

input=$(cat)

root=$(git rev-parse --show-toplevel)
name=$(printf '%s' "$input" | jq -r '.name // empty')
if [ -z "$name" ]; then name="worktree-$$"; fi
dir="$root/.worktrees/$name"

# Keep the worktree checkout out of git status without touching .gitignore.
exclude="$root/.git/info/exclude"
if [ -f "$root/.git" ]; then
  # $root is itself a worktree; use the common git dir.
  exclude="$(git -C "$root" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
fi
grep -qxF '.worktrees/' "$exclude" 2>/dev/null || echo '.worktrees/' >> "$exclude"

mkdir -p "$root/.worktrees"

# Match native default (worktree.baseRef "fresh"): branch from origin's default
# branch when known, otherwise from HEAD.
base=$(git -C "$root" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
branch="$name"
if git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
  git -C "$root" worktree add "$dir" "$branch" >&2
elif [ -n "$base" ]; then
  git -C "$root" worktree add -b "$branch" "$dir" "$base" >&2
else
  git -C "$root" worktree add -b "$branch" "$dir" >&2
fi

echo "$dir"
