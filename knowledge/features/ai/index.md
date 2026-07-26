# AI

The shared inference plumbing: configuration, prompt assembly, provider routing,
conversation state and embeddings. It does not own agent lifecycles.

* [Overview](overview.md) - the configuration model, the skill/profile split, startup seeding, and sharp edges.
* [Execution paths](execution-paths.md) - the legacy prompt path, the skill/profile path, the category consent gate, and per-invocation overrides.
* [Profile resolution, pinning and locality](profile-resolution.md) - which profile drives a run, and the fail-closed check that keeps synced audio local.
* [Provider routing](provider-routing.md) - the routing table, per-provider catalogs and quirks, audio transcoding, Gemini thinking, MLX Audio.
* [Conversations and tool calling](conversations-and-tools.md) - the reusable multi-turn loop.
* [Seeding and config lifecycle](seeding-and-lifecycle.md) - gated seeds, tombstones, migration-safe upgrades.
* [Embeddings and semantic search](embeddings-and-search.md) - local vector search over ObjectBox shards.
* [AI work attribution](attribution.md) - how every call becomes an auditable, costed record.
* [Activity visualization](activity-visualization.md) - the shader-driven activity surfaces.
* [AI settings UI](settings-ui.md) - the single-scroll layout, three tabs, and the first-run path.
* [Model evaluation](model-evaluation.md) - the eval harnesses and what they established.

# Related

* [Agents](../agents/) - the lifecycle layer above this plumbing.
* [Sync](../sync/) - config replication and the synced-audio auto-trigger.
