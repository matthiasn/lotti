# ADR 0140: A Goal Is Constituted by Its Charter Entries

- Status: Accepted
- Date: 2026-10-18
- Amends: [ADR 0042](./0042-typed-task-relationship-links.md) ("the typed
  vocabulary is closed by design") by one variant that is not a task
  relationship

## Context

A goal agent knows what its goal is about from four things: a title, a
one-sentence statement, a criteria tree and a persona name. Everything else
the user writes about the goal is a **check-in**: any text or audio entry
linked from the goal's journal row.

That leaves no place to say what the goal *is*. A journaling or purpose goal
has very little in its criteria. The user wants to tell its agent what it is
for, what matters, and how to coach — for instance, to ask guided questions
in the morning briefing that build on earlier reflections.

Written as a check-in, such a text goes wrong in three ways:

- **It counts as reflection time.** `goalCheckInFrom` accepts every linked
  entry with words, and the check-in time criterion sums their spans.
- **It is summarized like a day's reflection.** The compactor turns it into
  at most 500 tokens of `whatHappened` / `committedTo`, which is the wrong
  shape for a statement of purpose.
- **It fades.** Older summaries fold into monthly, then quarterly digests.
  What a goal is about should never fade.

The agent's chat is not the place either. A chat turn is a conversation, not
a definition, and nothing guarantees that it reaches a later wake.

## Decision

1. **A charter entry is a text entry linked to the goal by a `charter`
   link.**
   - `EntryLink.charter` (`CharterLink` in the `type` column) is a new
     union variant. It reads *fromId constitutes toId*: `fromId` is the
     charter entry, `toId` is the goal's journal row.
   - The direction is the reverse of a check-in's link on purpose. Every
     check-in reader — the timeline, `GoalRepository.checkInSources` and the
     check-in minutes in `GoalSignalReader` — reads the goal's *outgoing*
     links. A charter link is incoming, so no check-in reader can see it.
   - A goal has any number of charter entries. They are read in the order
     they were written.
2. **A charter entry is never a check-in.** It is not on the check-in
   timeline, does not count toward check-in time, and is not compacted or
   digested. This follows from decision 1 rather than from a filter that
   each reader has to remember.
3. **It is written on the goal page, never in the chat.**
   - The goal page gains an *About this goal* section. It lists the charter
     entries and adds, edits and deletes them in a sheet.
   - The sheet takes text, and voice as dictation: speech is transcribed
     into the field and can be edited before saving. It never saves an
     audio entry, because the agent reads the charter word for word and an
     audio entry linked from the goal would be a check-in.
   - The chat has no write path, and the agent has no tool that writes a
     charter entry. Agent-proposed amendments are future work and would go
     through the same approval as a goal revision.
4. **The agent reads the charter verbatim on every wake.**
   - Every Phase B wake carries a `charter` section in its FACTS: the daily
     briefing, a status escalation and a chat turn alike. It is omitted when
     the goal has no charter, so existing goals render exactly as before.
   - The section is bounded at 1,200 tokens out of the wake's 8k budget
     (ADR 0057). Entries are kept in written order until the budget is
     spent. The rest are counted as omitted, and the page tells the user
     when the agent cannot read the whole charter.
   - The section carries its own interpretation policy, as `userVoice`
     does. The system prompt is at its ceiling and does not change.
5. **The charter shapes coaching, never measurement.**
   - It decides focus, framing, the questions the agent asks and its tone.
     A request for guided questions in the briefing belongs here.
   - It never changes the track status, the criteria or the rules of the
     contract. When the charter and the measured FACTS disagree, the FACTS
     win.
6. **Editing the charter marks the report stale, and does not wake the
   agent.** The link notifies the goal row, which `GoalCheckInNotifier`
   already treats as new evidence. The next briefing or *Update now* reads
   the new charter.
7. **A charter entry belongs to the journal.** It is created in the goal's
   category and survives losing the agent database. Deleting the goal
   leaves it in place, as deleting a goal leaves its check-ins.

## Consequences

- An older build folds `CharterLink` into a `BasicLink` from the entry to
  the goal. It shows the charter entry as an ordinary note with a link to
  the goal, and never as a check-in, since the link still points into the
  goal.
- ADR 0042's write-back caveat applies: if an older build hides or deletes
  such a link, it re-serializes it as basic, and the entry stops being part
  of the charter for everyone. It still never becomes a check-in. Because
  the fallback is harmless, the variant and the UI that writes it ship
  together rather than a release apart.
- `JournalDb.charterLinksToGoal` reads the links by `(to_id, type)`, which
  the existing composite index serves.
- Charter entries appear in the Logbook and in search like any note.

## Related

- [ADR 0042: Typed task relationship links](./0042-typed-task-relationship-links.md)
- [ADR 0053: Goal-driven agents](./0053-goal-driven-agents-per-goal-producers.md)
- [ADR 0057: Decade-scale agent memory](./0057-decade-scale-agent-memory.md)
- [ADR 0138: A person's timeline is their relationship links](./0138-a-persons-timeline-is-their-relationship-links.md)
