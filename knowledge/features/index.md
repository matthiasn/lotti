# Features

One concept per module under `lib/features` — a directory of parts once the
module's knowledge outgrows a single file. Each module's `README.md` describes
what it does for a user; these describe how it runs.

# Agent runtime and AI

* [Agents](agents/) - the persisted agent runtime: wake scheduling, memory, proposals, review gates.
* [AI](ai/) - the shared inference plumbing: configuration, provider routing, conversations, embeddings.
* [Daily OS](daily_os_next/) - the day-planning runtime: coordinator and per-day agents, durable outbox, the capture ritual.
* [Nudges](nudges.md) - the kind-agnostic banner channel: one view over two entity variants, one visibility contract, one rotating dock.
* [AI chat](ai_chat.md) - a session-scoped Q&A surface over task history.
* [AI consumption](ai_consumption.md) - the receipt for every piece of AI work.

# Entries and work

* [Journal](journal/) - the shared entry substrate: detail, browse, search, linking.
* [Tasks](tasks/) - the task layer on the journal substrate: checklists, relationships, filters.
* [Speech](speech/) - audio capture, playback, waveforms, transcripts.
* [Events](events.md) - a first-class destination for meaningful moments.
* [Habits](habits.md) - recurring definitions reconciled with completion entries.
* [Ratings](ratings.md) - catalog-driven structured judgments.
* [Surveys](surveys.md) - predefined questionnaires scored at submission.

# Organising and insight

* [Categories](categories.md) - the app's primary scoping unit and its stored defaults.
* [Projects](projects.md) - grouping between categories and tasks, with agent-authored health.
* [Relationships](relationships.md) - a personal CRM on two journal variants: check-ins bound twice, recency without an N+1, and a cascade delete.
* [Labels](labels.md) - the lightweight taxonomy and its AI-suggestion coupling.
* [Insights](insights.md) - time analysis over the journal.
* [Dashboards](dashboards.md) - user-built chart views over journal data.
* [Health import](health_import.md) - reading Apple Health / Health Connect samples into the journal: one queue, one authorization sheet at a time.

# Replication and delivery

* [Sync](sync/) - single-user multi-device replication over end-to-end encrypted Matrix.
* [Notifications](notifications.md) - durable alerts that converge across devices.
* [Backup and restore](backup-and-restore.md) - the independent recovery artifact: profile inventory, integrity manifest, and safe capture/restore boundary.

# Shell, settings and look

* [Settings](settings.md) - the settings shell: how a route becomes a page, desktop master/detail against mobile drill-down, and the shared editor kit.
* [Settings v2](settings_v2.md) - where that tree is *defined*, and how feature pages are embedded into it as headerless bodies.
* [Design system](design_system/) - tokens, theming, and the component contracts.
* [Theming](theming.md) - theme selection and construction.
* [Keyboard](keyboard.md) - the desktop command layer.
* [Lockdown](lockdown.md) - the hidden logo menu that narrows the desktop app to one category for demos.
* [Onboarding](onboarding.md) - the first-run path and its measurement substrate.
* [Demo mode](demo.md) - the seeded penguin-logistics play world: manifest lifecycle, exit copy-over, the real-AI nudge.
* [What's New](whats_new.md) - remote release notes with local gating.

# Supporting

* [User activity gate](user_activity.md) - the idle gate background work waits on.
* [Checklist corrections](checklist.md) - learning from title edits.
* [Text-to-speech](tts.md) - on-device spoken summaries.

# Exploratory

* [Knowledge-graph explorer](knowledge_graph.md) - a walkable ego-centric graph view.

# Related

* [Architecture](../architecture/) - the cross-cutting layers these modules sit on.
* [Conventions](../conventions/) - the rules the repository holds itself to.
