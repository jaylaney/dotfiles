# Global Codex Guidance

This file defines default behavior for Codex work on this machine. A closer repository or directory-specific `AGENTS.md` may refine or override it.

## Primary-agent and subagent roles

Core principle: coding runs in subagents; the primary agent orchestrates, reviews, integrates, and performs final verification.

- For implementation, bug fixes, refactors, tests, and substantive code review, make subagent delegation the default.
- The primary agent decomposes work, selects models and reasoning effort, writes bounded briefs, resolves conflicting findings, inspects diffs, and runs final verification.
- The primary agent may directly handle read-only investigation, planning, user communication, small documentation/configuration edits, and integration-only corrections.
- If subagent tools are unavailable or work cannot be isolated safely, continue in the primary agent and state the reason.
- Delegate independent work in parallel only when scopes do not overlap. Do not assign multiple writers to the same files.
- The primary owns the concurrency budget. Subagents may spawn further agents only when their brief explicitly authorizes delegation and allocates capacity within the current runtime limit. Keep capacity available for required independent review.

Delegate to the least powerful model that fits the required work product, not the importance of the component being changed.

## Model and reasoning tiers

Keep this policy independent of model names and versions. Before the first dispatch in a session, resolve the capability tiers below from the models and supported reasoning efforts actually exposed by the current subagent tool. Use the tool's capability descriptions. Never rank models solely by version number or assume that a model available elsewhere can be dispatched here. Re-resolve if availability changes.

Choose the least powerful exposed model that meets both the tier and the brief. If the required capability is unavailable or unclear, prefer a stronger available route and disclose the substitution. Pass the resolved model ID and supported reasoning effort explicitly, except when deliberately inheriting a parent route that meets the tier and brief. Concrete model IDs belong in tool calls and run reports, not this policy.

### Adversarial top tier

Use the strongest available general-purpose reasoning model with `xhigh` reasoning where supported.

Reserve this tier for adversarial construction: reviewers of identity, ordering, concurrency, persistence, authorization, and security kernels; whole-branch finder lenses; and work whose required output is invented counterexamples or cross-component failure scenarios.

`xhigh` is the normal ceiling. Do not use `max` or `ultra` unless the user or a closer `AGENTS.md` explicitly requests it.

### Strong implementation tier

Use a strong coding model suited to difficult implementation with `high` reasoning. Escalate to the strongest available model when the brief requires capability beyond this route.

Use this tier for kernel implementers, architectural changes, difficult debugging, and fix waves executing an adjudicated brief.

### Standard engineering tier

Use a balanced coding model with `medium` reasoning by default and `high` when the task needs deeper checking.

Use this tier for prose-spec implementation, multi-file integration, test development, codebase exploration, documentation research, and per-task reviews. Use `high` for reviewers expected to trace subtle state, TOCTOU, reactivity, or ordering problems.

### Mechanical tier

Use an efficient model suited to a fully specified brief, with `low` reasoning.

Use this tier only when the brief is fully specified and the work is primarily transcription, localized mechanical editing, fixture generation, or running prescribed tests.

## Routing invariants

- Select the model and reasoning effort independently for each subagent. Except when deliberately inheriting both, set them explicitly using values supported by the current tool.
- Default to clean context and a bounded brief. When the tool exposes `fork_turns`, use `"none"` or a deliberately bounded positive turn count for explicit model and effort selection. Use `"all"` only for deliberate inheritance of the parent model and effort, subject to the current tool schema.
- Do not pin one model globally for every subagent.
- Route based on the output required from the subagent. A critical component does not automatically require the top tier for mechanical work, while adversarial counterexample construction does.
- Never downgrade both sides of a critical implementer/reviewer pair. Economy on implementation is acceptable only while an independent stronger reviewer remains assigned.
- A reviewer must be independent. Do not ask an implementer to approve its own work.
- For a required final whole-branch review, use a fresh read-only agent with clean context. Give it the base/head refs, repository guidance, and accepted contract in a neutral brief; let it inspect the whole branch without inheriting the implementer report, prior finding list, or task-scoped conclusions.
- If a requested tier or reasoning effort is unavailable, prefer the nearest route that meets the required capability and disclose the fallback. Do not silently downgrade.
- Do not spawn a subagent merely to repeat work already completed by the primary agent or another subagent.

## Dispatch briefs

Every subagent brief should include:

- One bounded objective and the exact work product expected.
- Files or directories in scope and explicit exclusions.
- The assigned checkout/worktree, file ownership, and any build or result paths needed to avoid interference.
- Relevant constraints, invariants, and approved design decisions.
- Commands or tests the subagent must run.
- Evidence the subagent must return, such as file references, failing scenarios, test output, or a concise diff summary.
- Whether the subagent may edit files or must remain read-only.

Give subagents only the context needed for their task. Keep implementers available for focused fix rounds until their work passes review. Use separate reviewers for requirements/conformance and code-quality/correctness checks when risk justifies both.

File ownership alone does not isolate shared Git or build state. The primary coordinates branch changes, staging, commits, and integration in a shared checkout; delegate those operations only with exclusive checkout ownership. Use isolated worktrees when concurrent writers need independent Git state, following repository-specific location rules. Serialize builds and tests that share mutable output or process state unless each run has isolated paths and cleanup, such as separate Xcode DerivedData and result bundles.

## Review and completion

- Treat subagent reports as evidence to inspect, not proof of correctness.
- The primary agent reviews the actual diff and validates findings against the repository.
- Run fresh, relevant verification before claiming work is correct, complete, fixed, or passing.
- Report unresolved reviewer findings, skipped verification, unavailable models, and fallback routing explicitly.
