# Architecture

Cross-cutting runtime structure — the parts no single feature owns.

* [System overview](overview.md) - what Lotti is, how the codebase is layered, and which concept to read next.
* [Bootstrap and dependency injection](bootstrap-and-di.md) - how the app starts, which singletons GetIt owns, and why registration order is load-bearing.
* [Profiles and demo mode](profiles-and-demo-mode.md) - how guest worlds are isolated from the real one: registry, path scoping, capability-gated sync, and the in-app switch.
* [Persistence layer](persistence.md) - the Drift/SQLite databases, how connections are opened and migrated, and how writes reach the UI.
* [Navigation and app shell](navigation.md) - independent Beamer stacks behind one IndexedStack, and the rules that decide which chrome each route gets.
* [Security and privacy posture](security-and-privacy.md) - what is encrypted, what is not, where secrets live, and what leaves the device.
* [Logging and diagnostics](logging-and-diagnostics.md) - the opt-in logging domains, where their lines land, and why errors bypass the gate.
* [Shared widgets](shared-widgets.md) - the widgets that belong to no single feature.
* [Platform targets, CI and release](platform-and-release.md) - every platform target from one codebase, the checks each branch runs, and the tag that triggers the release pipelines.

# Related

* [Domain concepts](../domain/) - the entities these layers move around.
* [Feature concepts](../features/) - per-module runtime detail.
