---
type: Feature Module
title: Seeding and config lifecycle
description: Provider-gated profile seeds, why deletion needed a tombstone, and the migration-safe upgrade pass that never overwrites user choices.
resource: ../../../lib/features/ai/util/profile_seeding_service.dart
tags: [ai, seeding, migration, soft-delete, lifecycle]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T00:00:00Z }
stale_after: 2026-10-26
sources:
  - id: seeding
    resource: ../../../lib/features/ai/util/profile_seeding_service.dart
    title: ProfileSeedingService
    last_modified: 2026-07-25
  - id: repo
    resource: ../../../lib/features/ai/repository/ai_config_repository.dart
    title: AiConfigRepository — soft and hard delete
    last_modified: 2026-07-25
---

# Seeds are gated on a usable provider

`ProfileSeedingService.seedDefaults()` knows a set of default profile templates,
each gated on a provider type via `providerTypeByProfileId`:

| Profile | Gate |
|---------|------|
| `Gemini Flash`, `Gemini Pro` | Gemini provider |
| `OpenAI` | OpenAI provider |
| `Mistral (EU)` | Mistral provider |
| `Melious.ai` | Melious provider |
| `Chinese AI Profile` | Alibaba provider |
| `Anthropic Claude` | Anthropic provider |
| `Local (Ollama)`, `Local Gemma 4 (Ollama)`, `Local Gemma 4 Power (Ollama)` | Ollama provider |
| `Local Power (oMLX)`, `Local Gemma 4 (oMLX)` | oMLX provider |

A template is seeded only once a **usable** provider of its gate type exists —
`isUsable` means a non-blank API key, or for keyless local types a non-blank base
URL. A fresh install therefore starts with **zero** inference profiles;
connecting a provider seeds exactly its own.

Seeding runs at startup and again right after a provider is created, updated
(for example when an API key is added to a draft), or finishes FTUE setup — so
onboarding can bind categories to a profile immediately after the key step.

Operational details of the seeded definitions:

- The five local profiles are `desktopOnly`.
- `Local (Ollama)` and `Local Gemma 4 (Ollama)` ship with image-analysis
  automation but **no** transcription slot.
- `Local Power (oMLX)` uses `Qwen3.6-35B-A3B-4bit` for thinking and image
  recognition, `whisper-large-v3-turbo` for transcription.
- `Local Gemma 4 (oMLX)` uses `gemma-4-26B-A4B-it-QAT-MLX-4bit` plus the same
  transcription model.
- `Melious.ai` uses Qwen3.5 122B A10B for thinking, Mistral Small 4 119B
  Instruct for image recognition, GLM 5.2 for high-end thinking, Flux 2 Klein 9B
  for image generation, Voxtral Small 24B for transcription.
- `Local Gemma 4 Power (Ollama)` currently ships with no default skill
  assignments.

# The retroactive counterpart

`removeOrphanedDefaultSeeds()` runs at startup only, after `upgradeExisting()`.
It deletes default seeds whose gate type has no usable provider — covering
installs that seeded the full catalog before the gate existed, and providers
deleted since the last launch.

It is deliberately conservative. A profile is removed only while it **still looks
like an untouched seed** — template name (or the legacy `Local Power (Ollama)`
name), no description, no pinned host, template flags — *and* none of its model
slots resolve to a model row owned by a usable provider. Renamed, described,
pinned or rewired profiles always survive.

# Deleted seeds stay deleted

Every seeding pass is idempotent **by presence**: `seedDefaults()` writes a
gated-in template whenever its row is missing, and
`ModelPrepopulationService.backfillNewModels()` recreates any known model a
configured provider lacks. Both run at startup and again after a provider is
created or updated.

So a hard delete was undone within the same session — **deletion had no memory,
only presence was state.**

Deleting an AI config therefore **soft-deletes** it: `deleteConfig` stamps
`deletedAt` on the row and re-saves it.

```mermaid
stateDiagram-v2
    [*] --> Absent: never seeded
    Absent --> Active: seedDefaults() — gate type has a usable provider
    Active --> Active: upgradeExisting() heals slots, never overwrites choices
    Active --> Tombstoned: deleteConfig() stamps deletedAt
    Tombstoned --> Tombstoned: seedDefaults() reads it as PRESENT and skips
    Tombstoned --> Active: restoreConfig() clears the stamp
    Absent --> Active: hardDeleteConfig() then a later seed
    Active --> Absent: removeOrphanedDefaultSeeds() — untouched seed, gate lost
    Active --> Absent: provider cascade removes its model rows
    note right of Tombstoned
      The row IS the tombstone, so
      "deleted" is distinguishable from
      "never seeded" in the same database
      and replicates on the existing
      sync path.
    end note
    note right of Absent
      Only hard delete returns here, and
      only where re-seeding is the intent.
    end note
``` The row itself is the tombstone, which
makes "deleted" distinguishable from "never seeded" in the same database and the
same write. Because `SyncMessage.aiConfig` already carries the whole config, the
deletion replicates on the existing sync path and converges across devices with
no separate ledger and no new message type — mirroring how the journal domain
deletes synced entities.

Reads split by intent:

| Caller | Behaviour |
|--------|-----------|
| `getConfigById` / `getConfigsByType` | Hide soft-deleted rows by default, so no picker, settings tab or resolver surfaces them |
| Seeding passes | Call with `includeDeleted: true`, because they need a deleted row to read as **present** so they skip recreating it |
| `watchConfigsByType` (backs the UI) | Always filters them out |

Two paths must **not** leave a stamp and use `hardDeleteConfig`:

- **`removeOrphanedDefaultSeeds()`** sheds bundled profiles whose gate type has
  no usable provider and deliberately re-seeds them when that provider returns. A
  soft delete there would make the removal permanent — the opposite of what the
  pass means.
- **A provider cascade** removes the provider's model rows, which must come back
  if the user re-adds that provider.

`restoreConfig` clears the stamp for the one case where the user asks for
something back: re-running onboarding for a provider whose bundled profile they
had deleted, which happens before FTUE setup seeds.

# Upgrades never overwrite a choice

`seedDefaults()` is **strictly seed-on-create**: it looks each gated-in profile up
by well-known id and writes only when the row is missing. Freshly seeded profiles
write `AiConfigModel.id` slot values when the corresponding model rows exist. Once
a profile exists, the seeder never overwrites user-edited names, descriptions,
flags or skill assignments.

**`upgradeExisting()` no longer backfills default skill assignments.** The old
guard was `skillAssignments.isEmpty` — so clearing every assignment, the obvious
way to say "stop doing things automatically", was exactly what restored them with
`automate: true` on the next launch. Automation defaults are now written only
when a profile is first seeded, and an empty assignment list is treated as a
deliberate user choice rather than a gap to fill.

What `upgradeExisting()` does backfill, after model rows exist:

- **Heals dangling model slots on default profiles.** Deleting a provider
  cascade-deletes its model rows, but the seeded profile kept pointing at the dead
  ids. Each such slot resets to the seed template's provider-native default and
  re-resolves once the rows are recreated. Catalog-known provider-native values
  are treated as *pending*, not dangling.
- Rewrites legacy provider-native slot values to `AiConfigModel.id` when the
  match is unambiguous.
- Moves the untouched old `Local Power (Ollama)` seed to the oMLX
  `Qwen3.6-35B-A3B-4bit` model.
- Gives untouched local oMLX profiles the `whisper-large-v3-turbo` transcription
  slot.
- Moves legacy Melious seeds through the Qwen thinking, GLM 5.2 high-end
  thinking, Flux 2 Klein 9B image-generation and Voxtral Small 24B transcription
  defaults.

**Melious stores a seed generation** after that one-shot migration, so later user
model choices are never reclassified as legacy defaults, and provider-native
slots resolve only against Melious-owned rows. Foreign providers with a matching
provider model id cannot satisfy or capture the migration.

User-edited names, resolvable model slots outside recognized seed generations,
and skill assignments are all preserved.

Besides startup, `upgradeExisting()` also runs right after a provider is created
or re-verified, so reconnecting a provider heals its profile immediately —
onboarding's first capture resolves through the profile seconds after the key
step.

# Model prepopulation

`ModelPrepopulationService.backfillNewModels()` seeds known model rows for
configured providers at startup.

**Known-model identity is the `providerModelId`**, while the local row id may be
deterministic or a UUID depending on whether the row came from FTUE, manual setup
or sync. Backfill therefore skips an already-configured provider model id rather
than only checking the generated row id.

It treats rows as configured only under the current provider or a usable provider
of the same type, and **ignores orphaned rows whose provider has been deleted**,
so a later valid provider can repair stale synced state. FTUE setup and the
preview modal follow the same identity rule.
