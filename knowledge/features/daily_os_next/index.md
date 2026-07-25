# Daily OS

The day-planning runtime: a coordinator plus per-day agents, a durable device-local
processing outbox, and the voice-first Capture → Reconcile → Draft → Refine ritual.

* [Overview](overview.md) - the surface, the module shape, inference settings and preferences.
* [Day-agent identities](agent-identities.md) - coordinator versus per-day agents, and the day-forward cutover.
* [Wake context and prompt](wake-prompt.md) - tagged plaintext sections, the task corpus, knowledge tiers, week context, memory links.
* [Capture and planning](capture-and-planning.md) - the tool surface, batch-first voice capture, the review fence.
* [Processing outbox](processing-outbox.md) - the job table, claim priority, retention, the job executor.
* [Coordinator and day-agent protocol](coordination-protocol.md) - directives, status events, the digest wake, week rollups.
* [Dependency-aware planning](dependency-aware-planning.md) - how typed `blocks` links reach the planner.
* [UI surfaces](ui-surfaces.md) - the Day page, voice template, timeline editing, capacity ring, onboarding walkthrough.
* [Evaluation and benchmarks](evaluation.md) - measuring what the model plans, and that storage does not degrade.

# Related

* [Agents](../agents/) - the shared runtime this builds on.
* [AI](../ai/) - transcription and inference routing.
