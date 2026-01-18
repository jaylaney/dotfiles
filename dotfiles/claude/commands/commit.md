---
description: Create a git commit with smart message
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*)
---

## Context

Current git status:
!`git status`

Staged and unstaged changes:
!`git diff HEAD`

Recent commit style:
!`git log --oneline -5`

## Task

Based on the changes above, create a git commit:

1. Stage relevant files (skip secrets, .env, credentials)
2. Write a descriptive commit message:
   - First line: summary in imperative mood (e.g., "Fix keyboard flicker" not "Fixed")
   - Blank line, then explain what changed and why
   - End with Co-Authored-By trailer
3. Create the commit

$ARGUMENTS
