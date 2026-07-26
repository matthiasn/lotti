# Domain

The entities the whole app is built on.

* [JournalEntity](journal-entity.md) - the sixteen-variant union and the Metadata envelope every variant shares.
* [Entry links](entry-links.md) - one row per relationship, eight variants sharing one shape.
* [Entity definitions](entity-definitions.md) - categories, labels, habits, dashboards, measurables — and the category consent gate.

# Related

* [Persistence](../architecture/persistence.md) - how these are stored.
* [Vector clocks and conflicts](../features/sync/vector-clocks-and-conflicts.md) - how they converge across devices.
