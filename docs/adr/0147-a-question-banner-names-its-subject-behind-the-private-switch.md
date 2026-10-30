# ADR 0147: A Question Banner Names Its Subject Behind the Private Switch

- Status: Accepted
- Date: 2026-10-30
- Amends: [ADR 0146](./0146-a-goal-agent-asks-and-keeps-what-matters.md)
  decision 2

## Context

ADR 0146 let a goal agent ask one question after a check-in, with an optional
banner pointing at it. Review of that change cited ADR 0056's leakage rule,
and a live run had glm-5.2 head a banner "A question about your Saturday
plan", so the banner's words became fixed copy: "Your agent has a question".

That rule was written for a brief sent to an image provider, a boundary ADR
0058 removed. What remained was that a banner is seen outside its goal, on the
day page and in the dock, by whoever is looking at the screen. The app
already answers that with the `private` config flag ("show private entries").
Fixed copy also gave up what made the banner worth raising: saying what the
question is about.

## Decision

1. **The model writes the question banner's words.** `ask_goal_question`'s
   banner takes a headline (required) and a tagline again, and may name what
   the user wrote.
2. **The stored brief holds safe words; the model's ride in provenance.** The
   brief is the localised generic headline and call to action. The model's
   headline and tagline are stored under `privateHeadline` and
   `privateTagline`. Anything that reads the brief without knowing about them
   — history, ratings, an OS alert — shows the safe words.
3. **A banner shows its private words only while private entries are shown.**
   `nudgeDisplayBrief` picks the words at render time, in both the goal banner
   card and the dock, from the `private` config flag. It never rewrites the
   entity, because the banner substrate writes the view's entity back on
   snooze, dismissal and rating.

## Consequences

- With private entries shown, a question banner says what it is about. With
  them hidden, it says only that a question is waiting.
- The flag is global, not per entry: a question drawn from an entry that is
  not itself private is still hidden. That is the cautious side, and simpler
  than tracking which entries each question came from.
- The model's words sync with the banner to the user's other devices, the
  same exposure as the question in the chat; each device applies its own
  flag.
- The convention lives in the nudge substrate, so a relationship banner could
  carry private words the same way.
- P22 no longer checks the banner for private terms; it checks that the
  question follows up what was said.

## Related

- [ADR 0056](./0056-need-to-know-visual-brief-boundary.md)
- [ADR 0058](./0058-procedural-text-banners-no-generative-imagery.md)
- [ADR 0146](./0146-a-goal-agent-asks-and-keeps-what-matters.md)
