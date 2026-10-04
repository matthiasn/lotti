---
type: Feature Module
title: Seeding and config lifecycle
description: Provider-gated profile seeds, why deletion needed a tombstone, how stamped config versions converge across devices, and the migration-safe upgrade pass that never overwrites user choices.
resource: ../../../lib/features/ai/util/profile_seeding_service.dart
tags: [ai, seeding, migration, soft-delete, lifecycle, sync, tombstone, last-writer-wins]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-09-26T13:00:00Z }
stale_after: 2026-12-26
sources:
  - id: seeding
    resource: ../../../lib/features/ai/util/profile_seeding_service.dart
    title: ProfileSeedingService
    last_modified: 2026-08-19
  - id: repo
    resource: ../../../lib/features/ai/repository/ai_config_repository.dart
    title: AiConfigRepository — orphan cleanup, soft and hard delete
    last_modified: 2026-10-02
  - id: model-prepopulation
    resource: ../../../lib/features/ai/util/model_prepopulation_service.dart
    title: ModelPrepopulationService — backfill and renamed-id repair
    last_modified: 2026-10-02
  - id: tla-spec
    resource: ../../../specs/tla/AiConfigReplication.tla
    title: AiConfigReplication — the model TLC checks replication against
    last_modified: 2026-10-02
  - id: skill-lookup
    resource: ../../../lib/features/ai/skills/skill_lookup.dart
    title: resolveAssignedSkill — why skills resolve from code, not the store
    last_modified: 2026-08-18
---

# Seeds are gated on a usable provider

`ProfileSeedingService.seedDefaults()` knows a set of default profile templates,
each gated on a provider type via `providerTypeByProfileId`:

| Profile | Gate |
|---------|------|
| `Gemini Flash`, `Gemini Pro` | Gemini provider |
| `OpenAI` | OpenAI provider |
| `Mistral (EU)` | Mistral provider |
| `Melious.ai`, `Melious.ai (Flash)` | Melious provider |
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
- `Melious.ai` uses GLM 5.2 for thinking, Kimi K3 for **both** high-end thinking
  and image recognition, Whisper Large v3 for transcription, and Flux 2 Klein 9B
  for image generation. Melious FTUE installs a wider set than the profile
  binds — Qwen3.5 122B A10B, Mistral Small 4 119B Instruct, Voxtral Small 24B
  and Whisper Large v3 Turbo are offered as one-dropdown alternatives.
- `Melious.ai (Flash)` is the same stack with the cheap thinking model in
  front: DeepSeek V4 Flash for everyday thinking, Kimi K3 retained for high-end
  thinking *and* image recognition because Flash is text-in/text-out, and the
  same Whisper Large v3 and Flux 2 Klein 9B. It seeds ALONGSIDE `Melious.ai`
  rather than replacing it, and carries no seed generation of its own — the
  Melious migrations below are keyed on `profileMeliousId` and never touch it.
- `Local Gemma 4 Power (Ollama)` currently ships with no default skill
  assignments.

# Skills are never seeded

Everything above seeds **profiles**, **providers** and **models**. It does not
seed **skills**, and nothing else does either: `builtInSkills` is a compile-time
list, and a profile's `SkillAssignment` holds only the skill's id.

That makes the registry the sole source of truth for a built-in id, and
`resolveAssignedSkill` the only correct way to resolve one — registry first,
the config store second for ids the registry does not know (demo seeds, and
the per-user layer the skill-management UI will add).

**Resolving an assignment through the store alone is a bug, and a silent one.**
Installs that carry `skill-*` rows in `ai_config.sqlite` got them from a release
that seeded them; a fresh install has none. Every assignment on every profile
then resolves to `null`, so each automated capability is skipped without
failing:

- `ProfileAutomationService` matches nothing and transcription falls through to
  its **direct fallback** — a rank-ordered search across every configured audio
  model that never reads the subject's category or profile. A category pinned
  to one provider transcribes through whichever provider wins that ranking.
- `SyncedAudioInferenceDispatcher` has no fallback by design, so synced audio
  transcribes nothing at all.

Both symptoms look like a provider problem and are not.

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

Deleting a model or profile therefore **soft-deletes** it: `deleteConfig`
stamps `deletedAt` on the row and re-saves it.

```mermaid
stateDiagram-v2
    [*] --> Absent: never seen here
    Absent --> Active: seedDefaults() or backfillNewModels()
    Active --> Active: upgradeExisting() heals slots, never overwrites choices
    Active --> Tombstoned: deleteConfig() of a model or profile stamps deletedAt
    Tombstoned --> Tombstoned: seeding reads it as PRESENT and skips
    Tombstoned --> Active: restoreConfig(), or a newer live version by sync
    Active --> Tombstoned: a newer tombstone by sync
    Active --> Deleted: hardDeleteConfig() — prompt or skill, provider cascade, orphaned model
    Active --> Deleted: a newer deletion by sync
    Deleted --> Deleted: backfill reads the stamp as PRESENT and skips
    Deleted --> Active: a local re-save (the undo), or a newer version by sync
    Active --> Absent: removeOrphanedDefaultSeeds() forgets row and stamp
    note right of Tombstoned
      The row IS the tombstone, so
      "deleted" is distinguishable from
      "never seeded" in the same database
      and replicates on the existing
      sync path.
    end note
    note right of Deleted
      Only the version stamp is left
      (ai_config_versions), none of the
      content.
    end note
```

Because `SyncMessage.aiConfig` already carries the whole config, the deletion
replicates on the existing sync path and converges across devices with no separate
ledger and no new message type — mirroring how the journal domain deletes synced
entities.

Reads split by intent:

| Caller | Behaviour |
|--------|-----------|
| `getConfigById` / `getConfigsByType` | Hide soft-deleted rows by default, so no picker, settings tab or resolver surfaces them |
| Seeding passes | Call with `includeDeleted: true`, because they need a deleted row to read as **present** so they skip recreating it; the model backfill also skips an id with a held version stamp |
| `watchConfigsByType` (backs the UI) | Always filters them out |

Three paths must **not** keep the row and use `hardDeleteConfig`:

- **`removeOrphanedDefaultSeeds()`** sheds bundled profiles whose gate type has
  no usable provider and deliberately re-seeds them when that provider returns. A
  soft delete there would make the removal permanent — the opposite of what the
  pass means. It sends nothing (`fromSync: true`): usability is per device.
- **Deleting a prompt or skill** must not keep its messages, so the row goes and
  `aiConfigDelete(hardDelete: true)` tells the peers. The delete toast's undo
  writes the row back from the snapshot it deleted (`saveConfig`), stamped past
  the deletion.
- **The provider cascade** (`deleteInferenceProviderWithModels`) deletes the
  provider and every live model of it in one transaction, which also removes
  the provider's API key from the keychain. A re-added provider gets a new id,
  so its models come back under new ids. The toast's undo
  (`restoreProviderWithModels`) re-saves the provider and the models the
  cascade took, each stamped past its deletion, and every model no earlier than
  the restored provider (`AiConfigDb.saveConfig(notBefore:)`) — so each
  model's restore is newer than the provider's deletion, which the receive
  rule below relies on.

Hard delete leaves no `deletedAt`, but it does leave a *version stamp*
(`ai_config_versions`, [ADR 0094](../../../docs/adr/0094-ai-config-versions-are-stamped.md)):
the id and the deletion's stamp, none of the content. That is what stops a
copy of the config sent before the deletion from bringing it back when it
lands late on a peer, and what the model backfill reads as present. The
orphaned-seed prune stays on this device and sends nothing, so it also forgets
the stamp (`forgetConfig`), and a peer's next copy of the profile applies
again as before.

`restoreConfig` clears the `deletedAt` stamp where the user asks for a soft-deleted
row back: the delete toast's undo of a model or profile, and re-running
onboarding for a provider whose bundled profile they had deleted, which happens
before FTUE setup seeds.

# Replication across devices

Configs are not sequence-tracked: each change travels as the whole row
(`SyncMessage.aiConfig`), and "Send settings" re-sends every row a device holds,
tombstones included. So a receiver sees versions late, twice and out of order.
`AiConfigDb` orders them by the version stamp each carries (ADR 0094); the
repository adds the rules about providers and their models. The model TLC
checks this against is `specs/tla/AiConfigReplication.tla`.

- **One total order.** A greater stamp wins; on a tie a held deletion wins,
  then the payload without its credential. A local write takes the next local
  stamp, past the version it replaces, so a device whose clock is behind still
  writes a newer version. The one exception is a model created on this device
  (one it has never held a version of, as the known-model backfill writes): it
  takes its provider's stamp, since it belongs to that provider version.
- **No stale model under a deleted provider.** Whenever a provider's or a
  model's message lands, the receiver deletes, and sends the deletion of, the
  live models of a provider it holds a deletion of
  (`_deleteOrphanedModels`). That catches a model another device backfilled
  before it heard of the deletion, whatever its clock said, since the backfill
  carries the provider's stamp. Only models **not newer than the provider's
  deletion** are orphans: one stamped after it was written after the deletion,
  and the provider undo's model restores are exactly that — a peer may receive
  one while it still holds the provider's deletion. The orphan's deletion
  carries the provider deletion's stamp, not the receiver's clock, so every
  device derives the same version and a later restore always outranks it.
- **The backfill skips held deletions.** A hard delete leaves no row, so
  without that check a device that received a model's deletion before its
  provider's would recreate the model at the next backfill, stamped past the
  deletion, and it would outlive the provider.
- **The residual.** A model a user edits or restores *after* the deletion, on a
  device that has not heard of it yet, is newer than the deletion and stays
  live under the deleted provider. The receiver cannot tell it from an undo's
  restore, and deleting it would lose that write; the user deletes it.
- **An interrupted cleanup resumes.** Each orphan's deletion is sent before it
  is stored, so a send that throws leaves the model live and the message
  unprocessed. When sync delivers the same message again, the cleanup runs
  again, whether or not the message changes a row.
- **A received provider without a key keeps the receiver's key** — while it
  still points at the same endpoint. An empty key on the wire means the
  sender's keychain read came back empty, not that the user removed it. A
  revision that changes the base URL (compared without surrounding space,
  trailing slashes or scheme/host case) or the provider kind does not inherit
  the key, and a provider's deletion removes it.

```mermaid
sequenceDiagram
    participant A as Device A
    participant B as Device B
    A->>A: cascade: delete provider P and its models
    B->>B: backfill: new model M under P, stamped with P's stamp
    A-->>B: P deletion
    B->>B: delete its live models of P (M) at P's deletion stamp, send
    B-->>A: M live (sent before)
    A->>A: M's provider is deleted: delete M at the same stamp, send
    B-->>A: M deletion
    A-->>B: M deletion
    Note over A,B: both hold P and M as the same deletions
```

The undo, delivered out of order, survives the same rule:

```mermaid
sequenceDiagram
    participant A as Device A
    participant B as Device B
    A->>A: cascade: delete P and model M
    A-->>B: P and M deletions
    A->>A: undo: restore P, then M, each stamped past P's deletion
    A-->>B: M restore (arrives first)
    B->>B: P is deleted, but M is newer than P's deletion: keep M
    A-->>B: P restore
    Note over A,B: both hold P and M live
```

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
  hard-deletes its model rows, but the seeded profile kept pointing at the dead
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
  defaults (**generation 1**).
- Moves untouched generation-1 Melious seeds to GLM 5.2 thinking, Kimi K3
  high-end thinking *and* image recognition, and Whisper Large v3 transcription
  (**generation 2**). Image generation already points at Flux 2 Klein 9B.

Model *rows* have their own one-shot repair, separate from profile slots.
`ModelPrepopulationService.migrateRenamedModelIds` runs before the backfill and
rewrites a row whose provider-native id was renamed, **in place** — profile
slots and direct-model overrides store `AiConfigModel.id`, so editing
`providerModelId` on the existing row repairs every reference at once, where a
new row would leave them all pointing at the dead id. Soft-deleted rows migrate
too, since leaving one resurrects the dead id on restore. The only entry today
is Melious `deepseek-v4-flash` → `deepseek-v4-flash-0731`: the bare alias is
listed by the provider and never servable.

**Melious stores a seed generation** after each one-shot migration, so later user
model choices are never reclassified as legacy defaults, and provider-native
slots resolve only against Melious-owned rows. Foreign providers with a matching
provider model id cannot satisfy or capture the migration.

Each generation has a **frozen** constant and its own migration, and they run in
order, so a profile stranded at generation 0 chains all the way to the current
generation in a single pass. Bumping one shared constant would have retargeted
the older migration's guard and stamp along with it — which is how a one-shot
migration quietly stops being one.

The generation-2 move is **atomic**: it applies only once every target resolves
to a Melious-owned model row, and is otherwise deferred whole until a later
pass. Migrating slot-by-slot as rows appeared would leave a profile in a shape
that is neither generation 1 nor generation 2, and the next pass — which
recognises only the exact generation-1 shape — would read that as a user edit
and stamp it forward with the remaining slots never migrated.

**Each generation also waits for the previous one to actually complete.** A
deferred generation-1 pass leaves the profile unstamped but possibly
half-moved; generation 2 skips anything below generation 1 rather than
stamping over that shape, which would freeze the profile short of both
generations forever.

# A missing row is not a user's choice

The rule the three guards above share, and the one to keep in mind when adding
a generation: **the stamp is permanent, so it may only be written on complete
evidence.**

Model deletion is a tombstone. `backfillNewModels()` reads deleted rows with
`includeDeleted: true`, so it sees the row as present and never recreates it,
while `upgradeExisting()` reads without it and cannot see the row at all. The
two passes disagree *by design* — and the shape predicates match a slot by
looking its row up, so a deleted source row makes an untouched slot look
rewired. **A single deleted model row is enough** to make a profile look
user-edited when nothing was edited.

Three consequences, each enforced in code:

| Guard | Without it |
|---|---|
| Neither migration stamps "user edited" while a row its own shape check reads is missing | One deleted row freezes the profile on stale models, permanently |
| Each generation guards on *its own* sources, not the union | Deleting Whisper Turbo — an alternative no generation-1 profile binds — would stall a generation-1 → 2 migration |
| The dangling-slot repair is skipped while a Melious migration is pending | The repair heals to the *current* template, writing a generation-2 value into a generation-0 shape that the migrations then read as a user edit |

Legacy provider-native values (the old Flux 2 dev id) are matched as plain
strings and need no row, so they are deliberately absent from the source lists.

```mermaid
stateDiagram-v2
    [*] --> Gen0: seeded before the generation stamp existed
    Gen0 --> Gen1: untouched — Qwen / GLM 5.2 / Mistral / Voxtral / Flux
    Gen0 --> Gen2: user-edited — stamped forward, no slot moved
    Gen0 --> Gen0: a generation-1 target row is missing — deferred, NOT stamped
    Gen1 --> Gen2: untouched — GLM 5.2 / Kimi K3 / Kimi K3 / Whisper v3
    Gen1 --> Gen1: a generation-2 target row is missing — deferred whole
    Gen2 --> Gen2: current — never reconsidered
    note right of Gen2
      Fresh seeds are written at the
      current generation, so the
      migration never reconsiders them.
    end note
```

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
