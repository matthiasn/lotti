# Domain

The entities the whole app is built on.

* [JournalEntity](journal-entity.md) - the union every recorded entry is, what sits outside it, and the Metadata envelope every variant shares.
* [Entry links](entry-links.md) - one row per relationship, every variant sharing one shape, and why the type column keeps old consumers working.
* [Entity definitions](entity-definitions.md) - categories, labels, habits, dashboards, measurables — and why the category flag is a consent switch, not a preference.

# Related

* [Persistence](../architecture/persistence.md) - which database each of these lands in, and how a write reaches the UI.
* [Vector clocks and conflicts](../features/sync/vector-clocks-and-conflicts.md) - how concurrent edits to them converge, and what the user sees when they cannot.
