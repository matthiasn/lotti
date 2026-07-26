---
type: Domain Model
title: Entity definitions
description: The five configuration entities — categories, labels, habits, dashboards, measurables — and why the category flag is a consent switch rather than a preference.
resource: ../../lib/classes/entity_definitions.dart
tags: [domain, categories, labels, habits, dashboards]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T02:30:00Z }
stale_after: 2027-01-31
sources:
  - id: definitions
    resource: ../../lib/classes/entity_definitions.dart
    title: EntityDefinition union
    last_modified: 2026-07-25
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

## The consent flag

`automaticInferenceEnabled` is the category's explicit opt-in to running inference
**without a user gesture** — auto-transcription of new audio, auto-analysis of new
images.

It is **nullable, and an absent value means off** — including for categories that
already carry a `defaultProfileId`.

That default is the whole point. **Selecting a profile is not consent**: seeded
inference profiles ship `automate: true` skill assignments, so binding a profile to
a category would otherwise silently start spending tokens. The one caller that sets
it to `true` is onboarding, at the moment it creates the areas — having just
connected a provider and picked those areas *is* the consent.

`ProfileAutomationService` consults it before **every** automatic path — the
profile-driven one and the direct transcription fallback alike — so this flag, not
the profile, is the switch that decides whether automation runs. See
[AI execution paths](../features/ai/execution-paths.md).

The category model deliberately does **not** contain prompt allowlists, and the
old `automaticPrompts` concept is not part of it.

# Related

* [Categories feature](../features/categories/) - the repository and settings surfaces.
* [AI execution paths](../features/ai/execution-paths.md) - where the consent gate sits in the chain.
