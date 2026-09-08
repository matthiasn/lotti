# Relationships

A personal CRM for a small, deliberately curated set of people. Each person
has a timeline of **check-ins** — interaction type, sentiment, topics and
narrative — and can have tasks linked to them. Marking someone important
opts them into a dedicated agent that tracks contact cadence and prepares
briefings from captured check-ins.

The feature is behind `enable_relationships`. The **People** tab (`/people`)
groups people into *Due*, *On track* and *Not enrolled*, with a summary of
who is due and who lapses next. Rows show the last contact and cadence.
Desktop uses a list/detail split; phones open a dedicated person page.

The person page holds a header with category, importance, name, nickname
and recent contact, followed by the agent briefing, *Next time*, check-ins,
contact channels and linked tasks. The header opens the agent conversation
and person editor, and tapping the avatar opens the person's photo: choose
one from the library and pick which part of it is the face, adjust that
later, or remove it. The photo shows wherever the person does, inside their
usual colour; it stays on the user's devices and never enters agent context.
The bottom action bar offers a check-in, voice capture and an available
contact action.

## Briefings and suggestions

The agent card has six states: not enrolled, no briefing, running, failed,
current and out of date. It offers the appropriate action: mark important,
brief now, choose a model, retry, or update. The card shows the briefing's
age, health band, inference cost and model information. A first cloud
briefing names the provider before sending relationship context.

The agent can propose tasks from explicit commitments in check-ins. The
card and chat show the source check-in and any proposed due date before
confirmation. Confirming creates a task with inherited category/privacy,
links it to the person and briefly highlights its Tasks row. History
provides a task destination and undo while the task remains unchanged.
More than three suggestions fold, and same-kind suggestions can be
confirmed together. Call scheduling and task-note suggestions are not
implemented yet.

The conversation uses the shared agent chat surface under an identity header.
Phones open `/people/<id>/chat`; desktop keeps chat in the People detail pane.
Check-in banners use the shared nudge system and open the person page.
Cadence reminders also have an OS-notification projection for when the app
is closed. The deterministic cadence tier does not require an AI model.

## Capturing and linking

Check-ins are user-authored. Voice capture records against the person,
transcribes with their inference configuration and fills the narrative for
review; it never saves automatically or overwrites existing typed text.
A missing transcription model is explained before recording. Category
speech dictionaries can improve recognition of names.

On Android and iOS, contact import lets the user select contacts and set
importance and cadence before creating people. Linking or refreshing a
contact preserves hand-edited channels and names. Available call, message
and email actions use the device's capabilities; returning after a contact
action can offer a prefilled check-in. Desktop retains manual channel entry.

Tasks can be linked, unlinked, or created from the person's task picker.
Deleting a person removes their check-ins and agent; it does not delete
independent tasks linked to them.

## Ownership and privacy

- `lib/classes/` owns the relationship/check-in journal variants and data.
- `repository/` owns person and check-in persistence and relationship links.
- `runtime/` owns deterministic cadence evaluation; `workflow/` owns agent
  context, tool policy, briefing production and deferred task proposals.
- `service/` owns agent lifecycle, chat, proposal confirmation, reminders,
  contact integration and the post-contact check-in loop.
- `state/` and `ui/` own the People surfaces and their reactive state.
  Shared agents, tasks, speech, nudges and design-system modules provide the
  underlying capabilities.

Relationships and check-ins live in People, outside the main journal
stream. Data stays on-device and syncs through the user's own end-to-end
encrypted Matrix rooms. Private people are hidden from both list and detail
routes when private entries are hidden; new check-ins inherit that privacy.
Contact channels never enter agent context.

Phases 1–8 of the original implementation plan are built; phase 9's privacy
manuals and release readiness remain outstanding. The architecture,
lifecycles, invariants, original plan and decision records are mapped in
[the relationship knowledge concept](../../../knowledge/features/relationships.md).
