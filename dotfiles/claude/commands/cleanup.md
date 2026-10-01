---
description: After a PR is merged and its remote branch deleted, leave and remove the current worktree, delete the local branch, and fast-forward the default branch. Manual only.
disable-model-invocation: true
allowed-tools: Bash(git:*), ExitWorktree
---

## Context

Worktree toplevel:
!`git rev-parse --show-toplevel`

Current branch:
!`git branch --show-current`

Worktrees:
!`git worktree list --porcelain`

Status:
!`git status --porcelain`

## Task

Clean up after a merged PR. A "stop" means: report what was found and delete nothing. Steps 1-3 are read-only and must all pass before anything destructive happens. The remote is only ever read (`ls-remote`, non-pruning `fetch` and `pull`); never push, and no pruning fetch or pull (`--prune`) runs anywhere in this command.

1. **Identify.** Record: worktree path (toplevel), branch name, branch tip SHA (`git rev-parse HEAD`), main checkout path (the first `worktree` entry of the porcelain list), and default branch (`git symbolic-ref --short refs/remotes/origin/HEAD` with the `origin/` prefix stripped; fall back to `main`). Stop if the toplevel equals the main checkout path (not in a linked worktree), HEAD is detached, or the branch is the default branch.

2. **Clean tree.** If `git status --porcelain` is non-empty (untracked files included), stop and list the entries.

3. **Premise check: merged, remote branch deleted, everything pushed.**
   a. `git ls-remote --exit-code --heads origin <branch>`: exit 0 means the remote branch still exists, so stop (PR probably not merged). Exit 2 means it is gone; continue. Any other exit means the remote is unreachable; stop.
   b. Prove every local commit was pushed. Never run `git fetch --prune`, `git pull --prune`, or any pruning fetch, here or later; it deletes this evidence. Squash merges mean the branch's commits never appear on the default branch, so ancestry against the default branch proves nothing; the remote-tracking ref is the record of what was pushed. Inspect `refs/remotes/origin/<branch>`:
      - Missing: either the branch was never pushed, or an earlier pruning fetch removed the ref. If `git config branch.<branch>.merge` equals exactly `refs/heads/<branch>`, the branch was pushed at least once, but its latest commits can't be proven pushed. Any other value, or no value, is no evidence of a past push (branching from `origin/<default>` sets the upstream to the default branch even if the branch was never pushed). Show `git log --oneline origin/<default>..<branch>`, say which case applies, and ask the user to confirm before continuing.
      - Present and `git merge-base --is-ancestor <branch> refs/remotes/origin/<branch>` succeeds: everything was pushed; continue.
      - Present but that check fails: local commits were never pushed. Show `git log --oneline refs/remotes/origin/<branch>..<branch>` and stop.

4. **Leave and remove.** If ExitWorktree is a deferred tool, load it via ToolSearch first. Call `ExitWorktree(action: "remove", discard_changes: true)`. `discard_changes` is needed because squash-merged commits aren't on the original branch, so the tool would otherwise refuse; it is safe because steps 2-3 proved nothing is uncommitted or unpushed. Outcomes:
   - Removed: continue.
   - No active worktree session (not entered via EnterWorktree in this session, e.g. a resumed session or `claude` launched inside the worktree): the session's working directory is the worktree, and deleting it would strand the session. Stop without deleting anything and print these commands for the user to run from the main checkout: `cd <main>`, `git worktree remove <path>`, `git branch -D <branch>`, and the step 6 update command.
   - Refused because the worktree was entered by path: call `ExitWorktree(action: "keep")`, then `git -C <main> worktree remove <path>`.

   Afterwards, if `<path>` still appears in `git -C <main> worktree list`, run `git -C <main> worktree remove <path>`. Never add `--force` to this fallback `git worktree remove` that you run yourself; the tree was proven clean. (The WorktreeRemove hook behind ExitWorktree uses `--force` on its own, and that's fine.) From this step on, run every git command as `git -C <main> ...` since the worktree directory no longer exists.

5. **Delete branch.** If `refs/heads/<branch>` still exists, run `git -C <main> branch -D <branch>`. `-D` is required because `-d` refuses after a squash merge. Then, if `refs/remotes/origin/<branch>` exists, run `git -C <main> update-ref -d refs/remotes/origin/<branch>`; the remote branch was confirmed gone in 3a, and this removes only this branch's stale tracking ref.

6. **Update default branch.** If the main checkout is on the default branch: `git -C <main> pull --ff-only --no-prune`. Otherwise: `git -C <main> fetch --no-prune origin <default>:<default>`. Never add `--prune`: a pruning fetch deletes other worktrees' `origin/<branch>` refs, and their own `/cleanup` needs those as step 3b evidence; `--no-prune` overrides a `fetch.prune` or `remote.origin.prune` setting in the user's config. Never force, rebase, or create a merge commit; if the update fails (non-fast-forward, conflicting local changes), report it and leave it.

7. **Report.** Briefly: worktree path removed; branch deleted with its tip SHA and the recovery command `git branch <branch> <sha>`; result of the default-branch update. If the user confirmed past step 3b rather than it being proven, say so.
