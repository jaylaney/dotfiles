# Global Codex Guidance

This file defines default behavior for Codex work on this machine. A closer repository or directory-specific `AGENTS.md` may refine or override it.

## Primary-agent and subagent roles

Core principle: coding runs in subagents; the primary agent orchestrates, reviews, integrates, and performs final verification.

- For implementation, bug fixes, refactors, tests, and substantive code review, make subagent delegation the default.
- The primary agent decomposes work, selects models and reasoning effort, writes bounded briefs, resolves conflicting findings, inspects diffs, and runs final verification.
- The primary agent may directly handle read-only investigation, planning, user communication, small documentation/configuration edits, and integration-only corrections.
- If subagent tools are unavailable or work cannot be isolated safely, continue in the primary agent and state the reason.
- Delegate independent work in parallel only when scopes do not overlap. Do not assign multiple writers to the same files.

Delegate to the least powerful model that fits the required work product, not the importance of the component being changed.

## Model and reasoning tiers

Model availability can vary by Codex surface and account. Use the named model when available; otherwise choose the closest available model with at least the required capability and disclose any material substitution.

### Adversarial top tier

Use `gpt-5.6-sol` with `xhigh` reasoning.

Reserve this tier for adversarial construction: reviewers of identity, ordering, concurrency, persistence, authorization, and security kernels; whole-branch finder lenses; and work whose required output is invented counterexamples or cross-component failure scenarios.

`xhigh` is the normal ceiling. Do not use `max` or `ultra` unless the user or a closer `AGENTS.md` explicitly requests it.

### Strong implementation tier

Use `gpt-5.6-sol` with `high` reasoning.

Use this tier for kernel implementers, architectural changes, difficult debugging, and fix waves executing an adjudicated brief.

### Standard engineering tier

Use `gpt-5.6-terra` with `medium` reasoning by default and `high` when the task needs deeper checking.

Use this tier for prose-spec implementation, multi-file integration, test development, codebase exploration, documentation research, and per-task reviews. Use `high` for reviewers expected to trace subtle state, TOCTOU, reactivity, or ordering problems.

### Mechanical tier

Use `gpt-5.6-terra` with `low` reasoning.

Use this tier only when the brief is fully specified and the work is primarily transcription, localized mechanical editing, fixture generation, or running prescribed tests. If Codex exposes a cheaper capable model, it may replace this tier only.

## Routing invariants

- Select the model and reasoning effort independently for each subagent.
- Do not pin one model globally for every subagent.
- Route based on the output required from the subagent. A critical component does not automatically require the top tier for mechanical work, while adversarial counterexample construction does.
- Never downgrade both sides of a critical implementer/reviewer pair. Economy on implementation is acceptable only while an independent stronger reviewer remains assigned.
- A reviewer must be independent. Do not ask an implementer to approve its own work.
- If a requested tier is unavailable, prefer the nearest more capable route. Do not silently downgrade.
- Do not spawn a subagent merely to repeat work already completed by the primary agent or another subagent.

## Dispatch briefs

Every subagent brief should include:

- One bounded objective and the exact work product expected.
- Files or directories in scope and explicit exclusions.
- Relevant constraints, invariants, and approved design decisions.
- Commands or tests the subagent must run.
- Evidence the subagent must return, such as file references, failing scenarios, test output, or a concise diff summary.
- Whether the subagent may edit files or must remain read-only.

Give subagents only the context needed for their task. Keep implementers available for focused fix rounds until their work passes review. Use separate reviewers for requirements/conformance and code-quality/correctness checks when risk justifies both.

## Review and completion

- Treat subagent reports as evidence to inspect, not proof of correctness.
- The primary agent reviews the actual diff and validates findings against the repository.
- Run fresh, relevant verification before claiming work is correct, complete, fixed, or passing.
- Report unresolved reviewer findings, skipped verification, unavailable models, and fallback routing explicitly.
