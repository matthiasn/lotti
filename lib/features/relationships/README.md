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
A person can also carry a banner image: it fills the whole top of the page,
down to the avatar, which sits across its lower edge; the header's actions
stay legible over it. Both
pictures are managed from the person editor's Photo card — the banner is
dragged sideways into place there — and the face from the page's avatar too.
The bottom action bar offers a check-in, voice capture and an available
contact action.

## Briefings and suggestions

The agent card has six states: not enrolled, no briefing, running, failed,
current and out of date. One status line under the title says which, in
that state's colour; the footer offers one quiet action (log a check-in, or
see the activity after a failure) and one primary: mark important, brief
now, choose a model, retry, update, or call. An out-of-date briefing shows
its age in the header; open task proposals are counted by their own band
under the body. The model row carries the inference cost, and a current
briefing names its sources once it is expanded. A first cloud briefing
names the provider before sending relationship context.

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

Check-ins are user-authored. One composer opens on the narrative, with
Dictate inside the field; how you connected, when and for how long are one
row of chips, and optional details fold under More. Recording, the
transcript wait, the finished transcript and both failure cards render in
place of the text. Voice capture records against the person, transcribes
with the system default profile and fills the narrative for review; it
never saves automatically or overwrites existing typed text. Editing a
check-in that was saved with words offers no Dictate: the saved text is
edited as text. A missing
transcript can be asked for again without recording again. A missing
transcription model is explained before recording. Dictated words are
corrected against the person's name and nickname, the names that come up
with them (set in the person editor), the other people in their category and
the category's speech dictionary, so a misheard name arrives spelled the way
the user writes it. Save waits for a few words
and says so while it waits. Closing the composer with unsaved words, or
while a recording is running, asks first, and confirming discards the
recording too; an untouched draft closes at once. A failure card offers
its own Try again, and typing under one that has nothing to retry
dismisses it; choosing to type instead of waiting for a missing
transcript keeps its retry on one line. Re-record is offered only while
the transcript is unedited. The started chip shows the time in the
device's own clock format, the same one its picker uses. At a large text setting the header keeps its whole title and
shortens its status line word by word, keeping the person's name, rather
than cutting it off.

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
