# Projects

Projects sit between areas and tasks: a place to group work that belongs
together and see how it is actually going.

A project is not just a folder. It has a status, a target date, and — when a
project agent is attached — a summary and health read that the agent maintains.

## What it does for the user

- **Groups related tasks.** A task belongs to at most one project, and the
  project shows its tasks and their rollup.
- **Says where a project stands.** Six statuses: open, active, monitoring, on
  hold (with a required reason), completed, archived. "Monitoring" is for work
  that is not finished but has no time scheduled — checked on when something
  comes up.
- **Feeds day planning.** Active projects form the pool the day planner schedules
  from; open, monitoring and on-hold ones stay available at lower priority;
  completed and archived ones drop out.
- **Keeps a running summary.** A project agent writes a short report and health
  read, refreshed on a daily digest rather than on every task edit — so a busy
  day of small changes does not burn tokens.
- **Is honest when it does not know.** If the agent has not produced a usable
  health payload, no health is shown — nothing is invented locally.
- **Groups the overview by area.** The projects tab groups projects under their
  category with task counts and filters.

The whole visible experience is behind a feature flag; with it off there is no
projects tab, no category projects section, and no project chip on tasks.

## What it owns

Project persistence and editing; task-to-project linking; the top-level projects
tab; both project detail pages; project health assembled from project-agent
reports; and the filters and grouped list models the tab uses.

## Where the code lives

```text
lib/features/projects/
├── model/ · repository/ · state/
└── ui/{pages,widgets}
```

## How it works

The data model and its denormalized membership column, the coalesced read paths,
how health is composed from agent reports, and the three ways a project agent
wakes are documented in the knowledge bundle:

**→ [knowledge/features/projects/](../../../knowledge/features/projects/)**
