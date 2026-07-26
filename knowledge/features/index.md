# Features

One concept tree per module under `lib/features`. A feature gets a directory
rather than a single file once its knowledge outgrows a couple of hundred lines.

# Agent runtime and AI

* [Agents](agents/) - the persisted agent runtime: wake scheduling, memory, proposals, review gates.
* [AI](ai/) - the shared inference plumbing: configuration, provider routing, conversations, embeddings.
* [Daily OS](daily_os_next/) - the day-planning runtime: coordinator and per-day agents, durable outbox, the capture ritual.

# Work and entries

* [Journal](journal/) - the shared entry substrate: detail, browse, search, linking.
* [Speech](speech/) - audio capture, playback, waveforms, transcripts.
* [Categories](categories/) - the app's primary scoping unit and its stored defaults.
* [Projects](projects/) - grouping between categories and tasks, with agent-authored health.
* [Labels](labels/) - the lightweight taxonomy and its AI-suggestion coupling.
* [Tasks](tasks/) - the task layer on the journal substrate: checklists, relationships, filters.

# Infrastructure

* [Sync](sync/) - single-user multi-device replication over end-to-end encrypted Matrix.

# Shell and configuration

* [Settings](settings/) - the declarative settings tree and its shared editor kit.

# UI foundation

* [Design system](design_system/) - tokens, theming, and the component contracts.

# Related

* [Architecture](../architecture/) - the cross-cutting layers these modules sit on.
* [Conventions](../conventions/) - the rules the repository holds itself to.
