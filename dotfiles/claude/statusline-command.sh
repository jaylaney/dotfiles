#!/bin/sh
# Claude Code status line — mirrors Starship default prompt style
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // ""')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# Shorten home directory to ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Git branch (skip optional locks)
branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree --no-optional-locks >/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Build status line
printf "\033[34m%s\033[0m" "$short_cwd"

if [ -n "$branch" ]; then
    printf " \033[35mon\033[0m \033[36m%s\033[0m" "$branch"
fi

if [ -n "$model" ]; then
    printf " \033[33m[%s]\033[0m" "$model"
fi

if [ -n "$remaining" ]; then
    printf " \033[32mctx:%s%%\033[0m" "$(printf '%.0f' "$remaining")"
fi

printf "\n"
