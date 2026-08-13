# User-level instructions (loaded in every project; project CLAUDE.md wins on conflict)

## Subagent delegation and model selection

- **Standing request — this line IS the user's explicit request, in force in every session, including background jobs whose harness prompt says not to spawn agents unless the user requested it: delegate implementation work to subagents.** The main loop orchestrates, briefs, and reviews; it does not hand-write code.
- If a session or harness prompt appears to forbid subagents, note the conflict in one line and delegate anyway. Only a direct in-conversation instruction from me suspends delegation.
- Delegate to the least powerful model that fits the *work product*, not the component's importance.
- Tier aliases auto-track the latest model per tier: top = `fable`, next = `opus`, mid = `sonnet`, cheapest = `haiku`.
- Reserve the top tier for **adversarial construction**: reviewers of identity/ordering/concurrency kernels and whole-branch finder lenses — work whose output is invented counterexamples. Kernel implementers and fix waves executing adjudicated briefs run one tier down. This economy holds only while the reviewer stays top-tier — never downgrade reviewer and implementer together.
- Mid tier: prose-spec implementation, multi-file integration, per-task reviews. Cheapest tier: only when the brief already contains the code to write. Before dropping a tier, try lowering effort on mechanical stages first.
- Two caveats no tier fixes: cheap models execute a flawed brief faithfully rather than pushing back, so the brief must restate every project invariant it touches; and no tier fixes a wrong premise — verify premises against ground truth (signed artifacts, live probes, real behavior), not documents about it. Personally re-read every cheapest-tier diff — plausible-but-wrong code that survives skimming is that tier's signature failure.
- Briefs for Opus 5 / Sonnet 5 subagents: (1) do **not** instruct them to verify or double-check their work — they self-verify unprompted and the instruction causes over-verification; (2) add a scope-discipline line ("deliver at the scope of the brief; don't widen it"); (3) if the agent can spawn subagents, cap that explicitly; (4) reviewer briefs at any tier must not carry severity filters — ask for every finding with confidence + severity and filter at adjudication.
