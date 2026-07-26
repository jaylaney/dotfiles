#!/bin/sh
# Claude Code status line: shows current directory (~ for $HOME) and git branch.
# Helps distinguish between git worktrees when sessions switch directories.

input=$(cat)
dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -z "$dir" ] && dir="$PWD"

# Abbreviate $HOME as ~
disp=$(printf '%s' "$dir" | sed "s|^$HOME|~|")

branch=""
if git --no-optional-locks -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git --no-optional-locks -C "$dir" branch --show-current 2>/dev/null)
  if [ -z "$branch" ]; then
    branch=$(git --no-optional-locks -C "$dir" rev-parse --short HEAD 2>/dev/null)
    [ -n "$branch" ] && branch="detached:$branch"
  fi
fi

# Worktree name (from a --worktree session, e.g. via superpowers) is free to read
# from the input JSON and makes it obvious which worktree a session is in.
wt=$(printf '%s' "$input" | jq -r '.worktree.name // empty')

out=$(printf '\033[1;36m%s\033[0m' "$disp")
if [ -n "$branch" ]; then
  out="$out $(printf '\033[2m(\033[0;32m%s\033[2m)\033[0m' "$branch")"
fi
if [ -n "$wt" ] && [ "$wt" != "$branch" ]; then
  out="$out $(printf '\033[2m[\033[0;33m%s\033[2m]\033[0m' "$wt")"
fi

printf '%s' "$out"
