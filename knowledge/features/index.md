# Features

One concept tree per module under `lib/features`. A feature gets a directory
rather than a single file once its knowledge outgrows a couple of hundred lines.

# Agent runtime and AI

* [Agents](agents/) - the persisted agent runtime: wake scheduling, memory, proposals, review gates.
* [Sync](sync/) - single-user multi-device replication over end-to-end encrypted Matrix.

# Related

* [Architecture](../architecture/) - the cross-cutting layers these modules sit on.
* [Conventions](../conventions/) - the rules the repository holds itself to.
