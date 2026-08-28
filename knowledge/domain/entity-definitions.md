---
type: Domain Model
title: Entity definitions
description: The five configuration entities — categories, labels, habits, dashboards, measurables — why the category flag is a consent switch rather than a preference, and how a measurable records a number or one of its own choices.
resource: ../../lib/classes/entity_definitions.dart
tags: [domain, categories, labels, habits, dashboards, measurables]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T02:30:00Z }
stale_after: 2027-07-12
sources:
  - id: definitions
    resource: ../../lib/classes/entity_definitions.dart
    title: EntityDefinition union
    last_modified: 2026-08-28
---

`EntityDefinition` is a union of five configuration entities:
`measurableDataType`, `categoryDefinition`, `labelDefinition`, `habit`,
`dashboard`.

They are **not** journal entries — they are the vocabulary journal entries are
described with, and they sync as their own `SyncMessage.entityDefinition` family.

# `CategoryDefinition` is the most load-bearing

A category is the app's primary scoping unit. Beyond presentation (`name`,
`color`, `icon`) and flags (`private`, `active`, `favorite`,
`isAvailableForDayPlan`), it carries the defaults and consent that downstream
features read:

| Field | Consumed by |
|-------|-------------|
| `defaultLanguageCode` | Speech and transcription |
| `defaultProfileId` | AI profile resolution for new tasks |
| `defaultTemplateId`, `defaultEventTemplateId` | Agent auto-attach for tasks and events |
| `speechDictionary` | Transcription prompt context and `context_bias` |
| `correctionExamples` | Category-scoped AI guidance from user corrections |
| `automaticInferenceEnabled` | **The consent gate for automatic inference** |
| `automaticAgentWakesEnabled` | Seeds whether auto-created task agents wake on their own |

## The consent flag

`automaticInferenceEnabled` is the category's explicit opt-in to running inference
**without a user gesture** — auto-transcription of new audio, auto-analysis of new
images.

It is **nullable, and an absent value means off** — including for categories that
already carry a `defaultProfileId`.

That default is the whole point. **Selecting a profile is not consent**: seeded
inference profiles ship `automate: true` skill assignments, so binding a profile to
a category would otherwise silently start spending tokens. Consent comes from one
of two places — a switch in the category settings form, or onboarding at the moment
it creates the areas, where having just connected a provider and picked those areas
*is* the consent.

`ProfileAutomationService` consults it before **every** automatic path — the
profile-driven one and the direct transcription fallback alike — so this flag, not
the profile, is the switch that decides whether automation runs. See
[AI execution paths](../features/ai/execution-paths.md).

## The agent-wake seed is a different thing

`automaticAgentWakesEnabled` is **independent** of the consent gate: it seeds
`AgentConfig.automaticUpdatesEnabled` on task agents this category auto-creates,
and switching it off leaves automatic transcription and image analysis running.

It is a **seed, not a gate** — the per-task switch owns the preference afterwards,
so a later category edit does not reach back into existing agents. See
[categories](../features/categories.md) and
[task agents](../features/agents/task-agents.md).

The category model deliberately does **not** contain prompt allowlists, and the
old `automaticPrompts` concept is not part of it.

# `MeasurableDataType` records a number or a choice

A measurable's `valueKind` decides what a `MeasurementData` for it carries:

| `valueKind` | Recorded as | `MeasurementData` |
|-------------|-------------|-------------------|
| `number` (or absent) | a `num` with the definition's `unitName` | `value` |
| `choice` | one of the definition's `choices` | `choiceId`, with `value: 1` |

**Absent means `number`.** Every measurable that predates the choice kind has
no `valueKind` key, and `@JsonKey(unknownEnumValue: number)` makes a kind this
build does not know read the same way, so an older client sees a newer
definition as a numeric measurable rather than failing to decode it.

**A choice is an id with a title, never a Dart enum.** `MeasurableChoice` is
`{id, title, archived?}`: the id is what a measurement stores and stays
constant for the choice's lifetime; the title is presentation and may be
renamed at will without touching recorded history. That split is the whole
point — a serialized enum value cannot be relabelled, and a user's own
vocabulary ("clear", "pale", "dark") changes. `archived` retires a choice from
the recording surfaces while entries that recorded it keep resolving to its
title; an archived choice can be restored. The list order is the user's
display order, and the only structure the set has.

**The data decides, not the definition.** `measurementValueLabel`
(`lib/features/journal/util/entry_tools.dart`) reads a measurement as a choice
recording iff `choiceId` is set: a number recorded before the measurable was
switched to choices still reads as its number, and a choice id still resolves
after a switch back. A choice the definition no longer lists reads as a
localized "removed choice" label.

**`value` is `1` for a choice recording — one occurrence.** That is what lets
every consumer that sums measurements per day — the signal window behind
habits and goals, the numeric aggregators — count recordings instead of
breaking on a missing number, and it is why a habit rule on a choice
measurable can only be "any entry today": the sum is a count, not a quantity.
`MeasurableDataTypeChoices` (`isChoice`, `activeChoices`, `archivedChoices`,
`choiceById`) is the extension the surfaces read the kind through.

# Related

* [Categories feature](../features/categories.md) - the repository and settings surfaces.
* [AI execution paths](../features/ai/execution-paths.md) - where the consent gate sits in the chain.
