# Tasks

The task-specific layer on Lotti's shared journal substrate.

* [Overview](overview.md) - what it owns versus borrows, the browse page, the desktop detail stack, sidebar activity.
* [Data model and progress](data-model.md) - `TaskData`, its deliberate boundaries, the pickers, and how progress is computed.
* [Checklists](checklists.md) - the subsystem, its motion contract, and the sorting state machine.
* [Typed relationships and blockedness](relationships.md) - the link types as one directed choice, and readiness derived at read time.
* [Detail composition](detail-composition.md) - band order, the header's two lanes, section surfaces, scroll stability.
* [Filtering and saved filters](filtering.md) - the shared query stack, the filter modal, saved-filter navigation, keyboard commands.

# Related

* [Journal](../journal/) - the entry substrate and paging controller.
* [Daily OS](../daily_os_next/) - consumes blockedness for planning.
* [Agents](../agents/) - produces the reports and proposals the detail page renders.
