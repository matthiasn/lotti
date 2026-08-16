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
  read. Relevant project and linked-task activity schedules one coalesced
  refresh; an idle project has no recurring wake.
- **Is honest when it does not know.** If the agent has not produced a usable
  health payload, the detail says that no report exists yet — nothing is
  invented locally. Agent health stays categorical and explains its rationale.
- **Groups the overview by area.** The projects tab groups projects under their
  category with task counts and filters. It opens on current work, keeps
  completed/archived projects behind All, prioritizes actionable work, and lets
  each category collapse for focus. Agent one-liners load in one overview batch
  and participate in search instead of shifting into rows one by one.
- **Makes room to focus on one project.** On desktop, the project list can be
  hidden after a project is selected and restored without losing its filters,
  search or scroll position. The embedded detail has no misleading Back action.
- **Keeps agent output actionable.** Recommended next steps can be resolved or
  dismissed, and pending project changes can be confirmed or rejected directly
  beneath the shared AI report.

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

**→ [knowledge/features/projects.md](../../../knowledge/features/projects.md)**
