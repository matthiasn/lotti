# ADR 0107: A Conflict Shows Every Task Field

- Status: Accepted
- Date: 2026-09-27

## Context

[ADR 0103](./0103-task-fields-are-changed-on-the-stored-row.md) made every
local task field write a change of the stored data, so one device never
loses a field. Two devices that write the same task before they sync still
produce two concurrent versions, and the user resolves the conflict
(ADR 0083, ADR 0092) — by keeping one side, or by combining them field by
field.

The conflict screen's diff (`entry_field_diff.dart`) modelled a task's title
and the metadata every entry has (category, dates, starred, private, flag).
A task's status, priority, estimate and due date were not modelled: a
difference in any of them was one "other details" line, and the field
followed whichever side the user kept. So a user who kept this device's
version to keep its title also put back the other device's status change
without having seen it, and "Combine" could not take a status from one side
and a priority from the other.

`specs/tla/TaskFieldWrites.tla` now models the resolution the screen offers:
the user keeps a side as the base and picks each field the screen shows
(`ShownFields`) from either side; a field it does not show follows the
base. `NoSilentFieldLoss` says a resolution settles a field the two sides
differ in only after the screen showed that difference. With the screen as
it was (`ShownFields = {}` for the task fields), TLC breaks it in seven
states: the user sets the status on one device, the agent the priority on
the other, the versions meet as a conflict, and keeping either side settles
a field the user was never shown.

Two designs were weighed:

- **Merge disjoint field edits automatically.** When the two versions
  changed different fields, merge them without asking. This needs a common
  ancestor to tell which side changed what, and the journal keeps none: a
  version is its whole row and its clock. Per-field stamps (as
  `ChecklistItemData` has for its title and check) would supply one, at the
  cost of a schema change on every task and a merge rule the model would
  have to prove first.
- **Show every task field, and let the user pick each.** The diff reports
  the four fields as fields of their own; "Combine" takes each from the side
  picked. No schema change, and the resolution is the user's, with nothing
  hidden.

## Decision

- `EntryField` gains `status`, `priority`, `estimate` and `dueDate`. A
  task's status is compared with the reason a blocked or on-hold status
  carries, so two reasons behind one status are a difference to show. The
  screen labels them in every catalog and shows each as the task page does
  (the localized status and priority, the estimate as a duration, the due
  date in the device's date format).
- "Combine" takes each of them from the side the user picks
  (`buildMergedEntity`); a field without a pick follows the base side.
- What the resolution joins from both sides whatever the user picks — the
  status history and the applied agent changes (ADR 0098, ADR 0103) — is no
  longer reported as "other details". Those paths are left out of the
  catch-all only when both sides are tasks, so an event's or a project's
  status stays reported.

`ShownFields` in the spec is the switch; the conformance trace checks, before
every resolution it makes on the real `ConflictResolutionService`, that the
real diff shows every field the two sides differ in.

## Consequences

- A task conflict shows every field that differs, and "Combine" can keep
  this device's status and the other device's priority.
- Two devices editing different fields of one task still ask the user; the
  screen now shows both changes, and combining them is one pick per field.
- A task's language, cover art and inference profile remain "other
  details", following the side kept.
