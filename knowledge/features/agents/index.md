# Agents

The persisted agent runtime: the agent kinds, their wake scheduling, memory, and
the human review gates in front of every task mutation.

* [Overview](overview.md) - agent kinds, lifecycle, startup wiring, and the code reading guide.
* [Wake orchestration](wake-orchestration.md) - how a change becomes a wake, and the three failure modes the design defends against.
* [Memory and compaction](memory-and-compaction.md) - the append-only input log, summary checkpoints, the prompt prefix invariant, and fork healing.
* [Task agents](task-agents.md) - inference setup, automation, evidence-first execution, tool policy, proposals and confirmation.
* [Project and event agents](project-and-event-agents.md) - the digest-shaped and recap-shaped variants.
* [Templates, souls and evolution](templates-souls-evolution.md) - skills versus personality, and the ritual loop that evolves both.
* [Persistence and sync](persistence-and-sync.md) - the agent.sqlite entity and link model, and exactly what leaves the device.
* [Projection kernel](projection.md) - the pure fold under the agent log, and the permutation-invariance proof that makes replay order irrelevant.
* [UI surfaces](ui-surfaces.md) - the AI summary card, internals panel, settings tabs and sidebar wake queue.

# Related

* [AI](../ai/) - the inference stack these workflows call into.
* [Daily OS](../daily_os_next/) - the day agent, whose workflow lives there.
* [Sync](../sync/) - how agent state converges across devices.
