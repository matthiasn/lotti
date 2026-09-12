# Guided journaling — preliminary design brief

Date: 2026-09-06
Status: Design exploration
Audience: Claude Design / product designer

## Purpose

Explore how guided journaling could look and feel in Lotti, a personal journal
and life-tracking app. Produce alternatives for discussion before implementation.
This brief fixes the product direction, but deliberately leaves presentation open.

The goal is to help people discover something worth reflecting on, especially
when a blank journal invites only “nothing interesting happened today.” The
inspiration is a deep, 25-minute conversation built around one simple question.
A question should invite sustained reflection without requiring a long sequence
of instructions or an immediate reply from an agent.

Over time, these reflections should support biographical work: understanding
what happened when in a person's life, and how their experiences, relationships,
and outlook have changed.

## Agreed product direction

- A dedicated guided space within the logbook. Explore its entry point and
  presentation; do not assume it needs a new top-level navigation destination.
- One question per reflection, with room for a long answer.
- Curated questions for the first release. Personalized selection and follow-ups
  come later.
- Answers also appear as ordinary journal entries, with their originating
  question preserved so they remain understandable years later.
- After saving, two optional five-point ratings capture how worthwhile and how
  enjoyable the question was. These are distinct: a difficult reflection can
  be valuable without being enjoyable. Either rating can be skipped.
- An optional approximate year or date range records the period being remembered,
  separately from the date the answer is written. Do not require precise dates.
- Voice interaction is outside the first release. The longer-term vision includes
  spoken reflection while travelling, so avoid making the conceptual flow depend
  on a complex visual questionnaire. Do not design a driving interface now.

Privacy remains a product requirement, but is not a blocker for this design
exercise. The product owner confirms GDPR-compliant inference providers are
available; the original zero-provider-retention requirement still applies.
Inference is not restricted to on-device models. Existing end-to-end encrypted
sync can carry answers and ratings when enabled. Treat provider configuration
as existing infrastructure, not a new setup journey to design here. Do not add
compliance claims or a separate privacy onboarding flow to these concepts.

## Explore three presentation directions

Create three meaningfully different approaches within the dedicated guided space:

| Direction | Primary experience | Main design question |
| --- | --- | --- |
| Question-led | A prominent question with a clear invitation to write; topics and history are secondary. | Can someone start reflecting immediately without the space feeling empty? |
| Topic-led | Areas of life such as health, relationships, identity, and turning points lead to a question. | Can choice feel inviting without making topic selection a prerequisite? |
| Continuity-led | A new question sits alongside previous reflections and periods of life. | Can the space feel like an evolving personal history while keeping the next action clear? |

All three should offer a quick start without mandatory setup or topic selection.
Explain the strengths and tradeoffs of each, then recommend a direction or a
specific combination worth developing further.

### Sample question content

Use varied question lengths and depths when exploring layouts:

- What has changed since June?
- How has your health changed over the past two or three years?
- Which relationship has changed you most?
- When did a place begin to feel like home?
- What do you understand about yourself now that you did not five years ago?
- Which ordinary moment would you like to remember?
- What decision marked the beginning of a new chapter in your life?
- What has become easier for you, and what helped?

Questions that reference a relative date should make the intended period clear.
For example, retain the relevant year when preserving a question about June.
These are seed examples for design, not the final localized prompt catalog.

## Essential journey and states

Show the following journey in each concept, using lightweight sketches where
full screens would repeat the same interaction:

1. **Discover:** Enter guided journaling from the logbook and understand what it
   offers without a tutorial.
2. **Choose:** See one question, request another, or optionally select a topic.
   Replacing a question before writing should be easy.
3. **Write:** Keep the question accessible without competing with the answer.
   Support a few sentences or a long reflection. Preserve an unfinished draft
   when leaving; switching questions must not silently lose written text.
4. **Place in time:** Optionally attach an approximate year or range without
   interrupting writing. Distinguish “written today” from “about 2019–2021.”
5. **Finish:** Save the answer, then offer two skippable ratings without making
   the reflection feel graded. A saved answer remains saved if feedback is skipped.
6. **Return:** Browse earlier reflections and reopen an answer with its question
   and dates intact. Show how an unfinished reflection can be resumed.

Include first use, a returning user, an unfinished draft, a long answer, and a
saved reflection. Show mobile and desktop adaptations and how the answer appears
in the ordinary logbook. Include a recoverable save-failure state that keeps the
draft available. Background refresh should preserve established content.

## Future phases to accommodate

### Phase 1 — Curated guided journaling

Focus the design on the journey above: questions, writing, optional life periods,
ratings, and reflection history. No agent response is required after saving.

### Phase 2 — Personalization and checking back in

A journal agent can later learn from ratings and question history, adapt topic
selection, and offer follow-ups to previous reflections. Leave a natural place
for an invitation such as “Would you like to revisit this?” with access to the
earlier answer. The user should be able to decline or choose something else.

Illustrate this as a clearly labeled future concept, not as behavior already
available in the curated first release. Do not require an immediate agent reply
or turn the core writing experience into a chat transcript by default.

### Phase 3 — Biographical connections

Prompts, answers, ratings, topics, and remembered periods should become connected
parts of the app's knowledge graph. Explore a light way to move from a reflection
to related entries or life periods. A graph visualization is not required to
complete the core journey.

The long-term outcome is the ability to revisit a period and understand which
experiences belong there, what changed, and how later reflections connect to it.
Avoid presenting automatically inferred dates or relationships as established
facts; any future inferred material should be distinguishable and correctable.

## Existing app context and design constraints

The journal already provides ordinary entries, rich-text editing, draft recovery,
and links between entries. Ratings already support multiple dimensions. The
knowledge-graph explorer currently emphasizes task connections; a biographical
timeline is a future extension, not an existing screen to assume.

Use Lotti's existing design-system components, typography, spacing, and color
tokens. Identify proposed additions explicitly rather than inventing a separate
visual language. Keep text localizable, allow for longer translations, and make
rating choices and approximate dates understandable with accessible labels.

Keep the tone calm, curious, and nonjudgmental. Avoid streak pressure, mandatory
disclosure, therapeutic or diagnostic claims, and completion mechanics that make
reflection feel like a productivity task. All example content must be fictional
or drawn from approved demo fixtures, never personal journal data.

Repository references for implementation context:

- [Journal overview](../../lib/features/journal/README.md)
- [Knowledge-graph overview](../../lib/features/knowledge_graph/README.md)
- [Design system](../../knowledge/features/design_system/)

## Requested output and review criteria

Deliver three concept directions, a recommended direction with rationale, and
a lightweight flow with representative mobile and desktop screens. Make the
first-release screens clear and keep future personalization sketches separate.
Call out unresolved presentation choices for discussion instead of silently
fixing them. This handoff does not ask for implementation code or a final schema.

Evaluate the concepts against these questions:

- Can someone start writing with little effort?
- Does the question support sustained reflection rather than a questionnaire?
- Can people skip topics, dates, and ratings without losing their answer?
- Are the date of writing and the period remembered clearly distinguished?
- Is it inviting to return to earlier reflections?
- Does the experience fit naturally into Lotti's existing logbook?
- Can personalization and follow-ups fit later without redesigning the core flow?
