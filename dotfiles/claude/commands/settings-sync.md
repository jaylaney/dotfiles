---
description: Reconcile ~/.claude/settings.json with the repo copy, per setting
allowed-tools: Bash(claude-settings:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), AskUserQuestion
---

Reconcile Claude settings between the live file (`~/.claude/settings.json`)
and the repo copy (`dotfiles/claude/settings.json`). Both are regular files
kept in sync by copying — never symlink settings.json (a Claude Code bug
ignores `defaultMode: "auto"` through a symlink).

Steps:

1. Run `claude-settings status`. If it reports "in sync", say so and stop.
2. Run `claude-settings diff` (`-` lines = repo side, `+` lines = live side)
   and present each differing setting in plain language: the setting name,
   the repo value, and the live value.
3. Ask which side should win, per differing setting (AskUserQuestion works
   well when there are several).
4. Converge:
   - If every pick favors the live side, run `claude-settings save`.
   - Otherwise, edit the repo file to the chosen merged result, then run
     `claude-settings apply` to push it live (it backs up the old live file
     automatically).
5. Run `claude-settings status` to confirm it now reports "in sync".
6. If the repo file changed, show `git diff dotfiles/claude/settings.json`
   and offer to commit.
