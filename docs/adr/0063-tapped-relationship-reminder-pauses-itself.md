# ADR 0063: A Tapped Relationship Reminder Pauses Itself

- Status: Accepted
- Date: 2026-09-19
- Amends: ADR 0055 Decision 6 (for relationship banners only)

## Context

ADR 0055 Decision 6 keeps two intents apart: tapping a banner opens its
conversation, and dismissing it is a separate, explicit gesture. Goal banners
still follow that rule.

The relationship reminder broke it in practice. Its tap opens the person's
page. The banner wrote nothing, so it kept rotating in the dock — including
over the person page it had just opened. People tap a reminder to act on it,
but they cannot always call the person right away. So the banner looked like
it had ignored the tap, and it kept nagging after the user had responded.

The owner raised this, and a design panel on 2026-09-19 (four experts, three
personas) agreed unanimously that the tap should pause the reminder.

## Decision

1. **Tapping a relationship reminder opens the person and pauses the
   reminder for one hour.** The pause is an ordinary synced snooze
   (`NudgeInteractions.snooze` with the one-hour preset), so every device
   hides the reminder and it returns on its own. It is not a dismissal: the
   reminder stays active, comes back after the hour, and is retired only by
   a logged check-in, as before. A write that fails leaves the banner as it
   was; the page still opens.
2. **The pause says why.** Each snooze event records a `NudgeSnoozeReason`:
   `opened` for a tap, and null (read as `chosen`) for everything else. The
   agent's FACTS show an opened reminder as "opened by the user, paused
   until …", so the agent never reads the pause as the reminder being put
   off. Old clients ignore the field, and an unknown future reason decodes
   as none.
3. **The person page says what the tap did.** While the tap's pause holds,
   the page shows *Reminder paused until 15:40* with *Snooze longer*, which
   opens the existing snooze sheet. A snooze chosen there replaces the
   opened pause, and the callout goes away.
4. **Goal banners are unchanged.** Their tap only opens. Decision 6 still
   holds for them.

## Consequences

- One tap now acts on the reminder. An accidental tap costs an hour of
  quiet, which *Snooze longer* and the next wake can correct.
- There is no Undo. Clearing a snooze would have to beat the resolver's
  latest-deadline-wins merge across devices, and an hour's pause with a
  one-tap way to lengthen it did not justify that.
- The reason is the first field on a snooze event that is not about timing.
  Goal wakes, which learn display windows from snooze history, could use it
  to discount opened pauses. They do not yet, because goal banners never
  record one.
