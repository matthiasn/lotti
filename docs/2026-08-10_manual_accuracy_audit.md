# Manual accuracy audit — English manual vs. source

**Date:** 2026-08-10
**Scope:** all 42 English pages under `docs-site/docs/`, verified against `lib/`
at commit `00b4ca3fe`.
**Method:** every load-bearing claim (labels, counts, enumerations, thresholds,
security properties, navigation paths) was checked against the implementing
source file. Findings below carry the file and line that establishes them.

Translations were **not** audited. Every prose fix in section 1 must be applied
to the ten non-English trees under
`docs-site/i18n/<locale>/docusaurus-plugin-content-docs/current/` as well —
`make manual_check` rejects a translated tree whose page set diverges from
English, but it cannot notice that a translated sentence still states the old
fact.

---

## Summary

| Section | Count | Nature |
| --- | --- | --- |
| 1. Factual errors | 7 (§1.4 covers two) | Wrong or incomplete statements that will mislead a reader |
| 2. Verified correct | 19 | Claims checked and confirmed — recorded so the audit is falsifiable |
| 3. Gaps and weak explanations | 8 | Accurate but unhelpful, or missing entirely |
| 4. Notable strengths | 2 | Worth preserving as the house style |

The error rate is concentrated in **labels, lists and navigation paths**, not in
mechanics. Where the manual explains how something *works*, it is reliably
right; where it names a thing or enumerates options, it has drifted.

---

## 1. Factual errors

### 1.1 The transcription language list is wrong

**Page:** `docs-site/docs/plan-and-capture/recordings.mdx`

> "The language selector currently offers **Auto**, **English**, and **Deutsch**."

**Reality:** the dropdown renders `auto` plus **every** `SupportedLanguage`
value — 42 languages, Arabic through Yoruba.

- `lib/features/speech/ui/widgets/speech_modal/language_dropdown.dart:43-54`
  — `DropdownButton` items are the literal `auto` entry followed by
  `...SupportedLanguage.values.map(...)`.
- `lib/classes/supported_language.dart:5-46` — 42 enum values.

**Impact:** highest in the manual. A Portuguese, Japanese or Swedish speaker
reads this and concludes Lotti cannot transcribe their speech.

**Fix:** state that the selector offers automatic detection plus the full
supported-language list, and do not enumerate it in prose (it will drift again).

---

### 1.2 The Language setting is under-described and under-counted

**Page:** `docs-site/docs/reference/advanced-settings.mdx`, "Choose the Manual
language"

> "Open **Language** to decide which published Manual the app opens. **Follow
> system** is the default and chooses the English, German, French, Italian,
> Spanish, Czech, Romanian, or Portuguese Manual from your device language."

Two errors:

**(a) It lists 8 languages; the app offers 11.** Dutch, Danish and Swedish are
missing.

- `lib/features/settings/state/manual_language_controller.dart:20-32` — the
  `ManualLanguage` enum: `english, german, french, italian, spanish, czech,
  dutch, romanian, portuguese, danish, swedish`.
- `lib/features/settings/ui/pages/advanced/manual_language_settings_page.dart:43-125`
  — the page renders "Follow system" plus all eleven.

**(b) The setting changes Lotti's own UI language, not only the manual link.**
The manual never says this.

- `lib/beamer/beamer_app.dart:1298`, `:1318`, `:1340` — the stored override is
  read and passed as `locale:` to the app's localized widget tree.
- `lib/features/settings/state/manual_language_controller.dart:10-14` — "The
  stored key intentionally retains its original name so existing user
  preferences keep working after the setting began controlling Lotti's UI."
- `lib/l10n/app_en.arb:5037` — the in-app subtitle already says it: "Use your
  device language **in Lotti and** the Manual when it is supported."

**Impact:** a user looking for "how do I change the app's language" will never
find this page, because the manual describes it as a documentation-link setting.

**Fix:** retitle the section (it is "Language", not "Manual language"), lead with
the app-language effect, and replace the enumeration with a pointer to the
in-app list.

---

### 1.3 Two pages contradict each other on theming

- `docs-site/docs/reference/settings.mdx` — "**Appearance** for light, dark, and
  automatic display modes **plus independent theme palettes**."
- `docs-site/docs/reference/appearance.mdx` — "Lotti ships a single carefully
  tuned theme with a light and a dark rendition, so the only choice to make is
  which of the two the app should use."

The code agrees with `appearance.mdx`:

- `lib/features/theming/README.md` — "There is exactly one theme — the design
  system's — built for each brightness."

**Fix:** delete "plus independent theme palettes" from `settings.mdx`.

---

### 1.4 Settings paths that do not exist as written

Two distinct problems live here: pages that name the destination wrongly, and
pages that send the reader to a leaf that is switched off by default.

**(a) Wrong or incomplete names.** Categories, Labels, Habits, Dashboards and
Measurables all hang off **Settings → Definitions** rather than off the Settings
root — though only three of the five are always present, see (b):

- `lib/features/settings_v2/domain/settings_tree_data.dart:206-242` — the
  `definitions` branch and its five declared leaves.
- `lib/features/settings_v2/domain/settings_tree_index.dart:36-61` — leaf ids
  are namespaced `definitions/…` while their deep-link URLs stay flat.

| Page | Says | Actual |
| --- | --- | --- |
| `organize-and-reflect/dashboards.mdx` | "Settings → **Dashboard management**" | No such string exists. Leaf is "Dashboards" (`app_en.arb:4889`) |
| `organize-and-reflect/habits-and-measurables.mdx` | "Settings → **Measurable data types**" | Leaf is "Measurables" (`app_en.arb:5097`) |
| `categories.mdx`, `labels.mdx`, `habits-and-measurables.mdx`, `daily-os.mdx` | "Settings → Categories / Labels / Habits" | Correct destination, but omits the Definitions branch |
| `models-and-profiles.mdx`, `surveys.mdx` | "Settings → Definitions → …" | Correct — and inconsistent with the four pages above |
| `sync.mdx`, `conflicts.mdx`, `maintenance.mdx` | "Settings → **Sync**" | Section is "**Sync Settings**" (`app_en.arb:5071`); `add-device.mdx` gets this right |
| `events.mdx` | "Settings → **Advanced → Flags**" | "**Advanced Settings → Config Flags**" (`app_en.arb:4742`, `:4895`); `advanced-settings.mdx` gets this right |

**(b) Two of those leaves do not exist on a default install.** The Habits and
Dashboards leaves are config-gated, and both flags ship **off**:

- `lib/features/settings_v2/domain/settings_tree_data.dart:226`, `:232` —
  `if (enableHabits)` and `if (enableDashboards)` wrap the two leaves.
- `lib/features/settings_v2/ui/settings_tree_builder.dart:22-25` — both are fed
  from `configFlagProvider(enableHabitsPageFlag)` /
  `configFlagProvider(enableDashboardsPageFlag)`.
- `lib/database/journal_db/config_flags.dart:75-85` — both are seeded
  `status: false`.

Neither `dashboards.mdx` nor `habits-and-measurables.mdx` mentions the flag
anywhere. A reader on a fresh install follows the path and finds nothing —
which the naming sweep alone would not fix, since it would merely replace one
unreachable path with another.

`events.mdx` is the model to copy. It is listed above only for its path
wording; its handling of the precondition is exactly right:

> "Events are currently an optional feature. Open **Settings → Advanced →
> Flags** and turn on **Enable Events**. The **Events** destination then
> appears in the desktop sidebar and under **More** on mobile."

**Impact:** higher than the naming drift. A wrong label still lands the reader
in Settings; a path to a disabled leaf leaves them concluding the feature does
not exist.

**Fix:** two passes, not one.

1. One naming sweep, using the exact parent path for each destination rather
   than a single form applied everywhere — the three branches differ:

   | Parent path | Pages to correct |
   | --- | --- |
   | `Settings → Definitions → <leaf>` | `categories.mdx`, `labels.mdx`, `habits-and-measurables.mdx`, `daily-os.mdx`, `dashboards.mdx` (5) |
   | `Settings → Sync Settings → <leaf>` | `sync.mdx`, `conflicts.mdx`, `maintenance.mdx` (3) |
   | `Settings → Advanced Settings → Config Flags` | `events.mdx` (1) |

   `sync.mdx` needs care: it already uses the correct form twice (`:27`, `:45`)
   and the wrong one once (`:15`), so this is not a blind find-and-replace.
2. Give `dashboards.mdx` and `habits-and-measurables.mdx` the `events.mdx`
   treatment — state the flag and how to turn it on before giving the path.
   This is content work, not a find-and-replace.

---

### 1.5 The manual says "Journal"; the app says "Logbook"

The whole of `docs-site/docs/organize-and-reflect/journal.mdx` — a page titled
"Keep a useful journal" — plus the index page and the keyboard-shortcuts table
call the destination the **Journal**. The app calls it the **Logbook**:

- `lib/l10n/app_en.arb:4142` — `"navTabTitleJournal": "Logbook"`.
- Used at `lib/beamer/beamer_app.dart:1041` (sidebar destination),
  `lib/features/journal/ui/pages/infinite_journal_page.dart:236` (page title),
  and `lib/features/keyboard/domain/app_command_text.dart:33` (the ⌘6 command
  reads "Go to Logbook").
- Renamed in commit `aa71e3ec6` (2023-05-15, "Journal tab renamed to Logbook").
  The manual was authored in 2026 and never picked it up.

Related naming drift in the same family:

- The Daily OS tab label is `"DailyOS"` (`app_en.arb:4138`); the manual writes
  "Daily OS" throughout.
- `keyboard-shortcuts.mdx` says "Open **Dashboards**, Journal, Events, or
  Settings"; the destination is labelled **Insights** (`app_en.arb:4141`).
  `dashboards.mdx` gets this right ("Open **Insights**").

**Fix — documentation side, no decision required.** Wherever the manual names
the *destination* or the *keyboard command*, it must say **Logbook**, because
that is the shipped label: `journal.mdx`, `index.mdx` and the
`keyboard-shortcuts.mdx` ⌘6 row. Likewise **Insights** for ⌘5 and **DailyOS**
for the tab. Do this regardless of how the question below is settled.

The generic noun stays untouched: "journal entries", "your journal" and the
page title "Keep a useful journal" describe the data and the practice, not the
tab, and the app uses "journal" that way too — `JournalEntity`
(`lib/classes/journal_entities.dart:115`) and `JournalDb`
(`lib/database/database.dart:109`).

**Open question — needs a product owner, not an audit.** Whether the tab should
revert to "Journal" is a naming decision this document cannot make. Note that
the app is itself undecided: the ARB key is `navTabTitleJournal` while its
value is "Logbook" (`app_en.arb:4142`). Until someone rules, the manual follows
the shipped label per the paragraph above.

---

### 1.6 `sync.mdx` names a page that has been renamed

**Page:** `docs-site/docs/sync-and-data/sync.mdx`

> "**Sync node profile** identifies the current device to the rest of the sync
> group."

The page is titled **"This device"**, subtitled "Device name and capabilities":

- `lib/l10n/app_en.arb:5150` — `"settingsSyncNodeProfileTitle": "This device"`.
- `lib/l10n/app_en.arb:5149` — `"settingsSyncNodeProfileSubtitle": "Device name
  and capabilities"`.

---

### 1.7 The agent auto-apply exception is wider in code than in the manual

**Pages:** `docs-site/docs/index.mdx:101`,
`docs-site/docs/getting-started/mental-model.mdx:69`

> "The only narrow exceptions are an initial title or language for an
> **otherwise empty task**."

**Reality:** the guard is per *field*, not per *task*. Nothing tests whether
the rest of the task is empty:

- `lib/features/agents/workflow/task_agent_change_handlers.dart:506-524` —
  `_shouldAutoApplyInitialField(read)` resolves a `TaskMetadataSnapshot`, then
  returns `current == null || current.isEmpty` for the single field `read`
  selects.
- `lib/features/agents/workflow/task_agent_strategy.dart:345-348` — the two
  call sites pass `(s) => s.title` and `(s) => s.languageCode`.
- The implementation comment says so plainly: "when the task has no title
  yet", and "the very first `set_task_language` on a task with no language
  yet" (`task_agent_strategy.dart:330-341`).

So a task with a description, checklists and logged time — but no language set
— will have an agent's first `set_task_language` applied **without
confirmation**. The same holds for a populated task whose title is blank.

**Impact:** this is the manual's central trust claim, and it is the one place
where being wrong costs the most. The promise as written is narrower than the
code, which is the dangerous direction: a reader who believes "otherwise empty
task" will not expect a silent change to a task they have been working on.

**Fix:** state the actual condition — the *field being set* is empty, and it is
the agent's first use of that tool on the task (`canUseInitialAutoApply`,
`task_agent_strategy.dart:342`). Do not describe it in terms of the task being
empty.

**Note:** this row was originally certified under §2 and was wrong; it was
moved here after review.

---

## 2. Verified correct

Recorded so this audit is falsifiable and so a future reader does not re-check
the same ground.

The list is not infallible: the agent auto-apply row was originally certified
here and turned out to be wrong under review. It now sits at §1.7. Treat a row
as a pointer to the evidence, not as a substitute for it.

| Claim | Page | Evidence |
| --- | --- | --- |
| ⌘1–8 destinations, ⌘K palette, ⌘N text, ⌘T task, F1 / ⌘? help | `keyboard-shortcuts.mdx` | `lib/features/keyboard/domain/app_command_catalog.dart:7-187` |
| Four priorities P0–P3, unset behaves as P2 | `tasks.mdx` | `lib/classes/task.dart` (`TaskPriority`, `fallback: TaskPriority.p2Medium`) |
| Automatic updates bundle changes "for about two minutes" | `task-agents.mdx` | `lib/features/agents/wake/wake_orchestrator.dart:323` — `throttleWindow = Duration(seconds: 120)` |
| Daily OS drag/resize snaps to 15 minutes | `daily-os.mdx` | `lib/features/daily_os_next/ui/widgets/day_timeline_block.dart:60` |
| Dashboard ranges 30 / 90 / 180 / 365 days | `dashboards.mdx` | `lib/widgets/misc/timespan_segmented_control.dart:15` |
| Habit outcomes Success / Missed / Skip | `habits-and-measurables.mdx` | `lib/classes/entity_definitions.dart:46`; labels at `app_en.arb:1867-1869` |
| Five aggregations incl. hourly sum | `habits-and-measurables.mdx` | `lib/classes/entity_definitions.dart:44` |
| PANAS: 20 affect words, five-point scale, separate positive/negative totals | `surveys.mdx` | `lib/features/surveys/definitions/panas_survey.dart:8-95` |
| Celebration styles Sparks/Fireworks/Confetti/Embers/Bubbles + Random + Combine two | `completion-celebrations.mdx` | `celebration_variant.dart:11-29`; `celebration_selection.dart:36-41` |
| Six health-import families, mobile only | `health-import.mdx` | `lib/features/settings/ui/pages/health_import_page.dart:27-28`, `:348-385` |
| Supertonic 3; ten voices F1–F5 / M1–M5; speed 0.5×–2× | `speech.mdx` | `tts_model_option.dart:52-62`; `tts_voice.dart:41-56`; `tts_settings.dart:12-26` |
| Onboarding providers: Melious / Mistral / Gemini / Qwen first, OpenAI + Ollama under More options | `onboarding.mdx` | `lib/features/onboarding/ui/widgets/onboarding_connect_panel.dart:13-24` |
| Pairing check code derives from account, room and homeserver only — not the password — and is a recognition aid, not a security control | `add-device.mdx` | `lib/features/sync/models/pairing_check_code.dart:18-29` |
| Closing the Add-device sheet does not revoke the code | `add-device.mdx` | `provisioning_controller.dart:301-317` — `regenerateHandover` re-encodes the current password; no rotation |
| A fresh provisioning bundle rotates the account password; handover bundles do not | `first-device.mdx` | `provisioning_controller.dart:134-142`, `:209-224` |
| Time Analysis merges overlaps per (day, category), splits at local midnight, surfaces Uncategorized | `time-analysis.mdx` | `lib/features/insights/logic/time_bucketing.dart:46-140` |
| Period units Day/Week/Month/Quarter/Year | `time-analysis.mdx` | `lib/features/insights/model/insights_models.dart:131` |
| Knowledge graph is desktop-only | `tasks.mdx` | `lib/features/tasks/ui/task_expandable_app_bar.dart:37-40` |
| Theme mode syncs across devices | `appearance.mdx` | `lib/features/theming/state/theming_controller.dart` (enqueues `SyncMessage.themingSelection`); `features/theming/README.md` |

---

## 3. Gaps and weak explanations

### 3.1 Demo mode is effectively undocumented

`lib/features/demo/` is a substantial user-facing feature: a separate sandbox
world with its own databases, three entry points (onboarding welcome, tasks
empty state, Settings → Onboarding), a persistent banner, and an exit sheet that
**copies demo-created tasks, entries and AI setup into the real journal**. Reset
and Delete are separate settings actions.

- `lib/features/demo/README.md:1-33` documents all of the above.

The manual mentions it only inside a `:::note` aside about penguins on
`index.mdx`, plus one line in `onboarding.mdx`.

It is almost entirely absent from `docs-site/metadata/surface-inventory.json`,
whose stated scope is *"every major workflow that creates or materially changes
user data or cross-cutting configuration."* Exactly one demo-adjacent row
exists — `settings-sync-unavailable`, "Sync unavailable (demo world)". The
entry points, banner, exit sheet and copy-over flow have no rows at all.

That single row is also the inventory's only unverified one. Of 103 surfaces,
102 are `verified` and it is `documented`, and
`validate-manual.mjs:172-174` errors on any surface that is not `verified`
under `--require-complete`. So the gate does **not** currently pass:

```console
$ npm --prefix docs-site run coverage:complete   # exit 1
Manual validation failed with 1 error(s):
- settings-sync-unavailable is documented; complete coverage requires verified.
```

The blind spot is therefore not that the gate is green while demo mode is
undocumented — it is that the gate can only ever fail on a row someone
remembered to add. **The release gate measures the inventory, not the app**, so
the entire demo feature stays outside the count no matter what the command
reports.

**Recommendation:** a page under "Start here" covering enter / explore / exit /
copy-over / reset / delete, plus inventory entries for the three entry points,
the demo banner, the exit sheet and the real-AI setup sheet.

---

### 3.2 `skills.mdx` is vague where it should be concrete

> "tasks can offer text and task-context actions; audio entries can offer
> transcription and audio-aware actions; …"

This tells a stuck user nothing. The live skill set is exactly five:

- `lib/features/ai/state/consts.dart:113-119` — `enum SkillType { transcription,
  imageAnalysis, imageGeneration, promptGeneration, imagePromptGeneration }`.
- `lib/features/ai/state/skill_trigger_providers.dart:60-64` — the five types
  the trigger provider offers.
- `taskSummary` and `checklistUpdates` are legacy and hard-blocked from
  executing: `consts.dart` `isLegacyType`, enforced at
  `lib/features/ai/repository/unified_ai_inference_repository.dart:111-118`.

Naming the five would let a reader distinguish "my profile is misconfigured"
from "that action does not exist".

---

### 3.3 The human-approval promise needs one stated condition

`onboarding.mdx`:

> "When structuring produces checklist suggestions, they arrive on the task as
> proposals for you to confirm instead of changing the task silently."

True only when the chosen category has a default agent template.
`_assignCategoryAgent` returns early when `category.defaultTemplateId == null`,
and the structured checklist is then dropped — not applied, not proposed:

- `lib/features/onboarding/services/onboarding_capture_to_task_service.dart:283-284`
  — `final templateId = category?.defaultTemplateId; if (category == null ||
  templateId == null) return;`, guarding the call to `_seedChecklistProposals`.

**The onboarding flow itself is not the way to reach this**, contrary to an
earlier draft of this section. Every category onboarding touches gets Laura
bound as its default template whenever a profile was seeded, including
"Add your own" ones — `_addOwn` merely appends to `_custom`
(`onboarding_welcome_modal.dart:541-547`), which `_options` folds into the same
list (`:511`) that `_continue` processes through one code path:

- `onboarding_welcome_modal.dart:615` — new categories are created with
  `defaultTemplateId: profileId != null ? lauraTemplateId : null`.
- `:589-596` — reused categories get Laura too, when they have no template yet.

And when no profile was seeded, `automaticInferenceEnabled` is left null
(`:624`) so nothing structures in the first place — there is no suggestion to
drop.

**The reachable case is a category created outside onboarding.**
`createCategory` leaves `defaultTemplateId` null unless a caller sets it
(`lib/features/categories/repository/categories_repository.dart:113-119`), and
the Settings form does not require one. A task in such a category, structured
by an agent, drops its checklist silently — no proposal, no error.

So the condition is worth stating, but as "the task's category needs a default
agent template", not as an onboarding caveat.

---

### 3.4 `first-device.mdx` buries its prerequisite

The page opens with the `matrix_provisioner` CLI and `--admin-user`. The
sentence a normal reader needs — *if you do not run a Matrix homeserver, this
path is not available to you* — arrives in paragraph three as "ask the person
who operates the server". State the prerequisite in the first paragraph.

---

### 3.5 The manual never says what actually syncs

`sync.mdx` says "supported data" and stops. Verifiable facts that belong in a
short table:

The synced set is the `SyncMessage` union in
`lib/features/sync/model/sync_message.dart`. Enumerating it is the only way to
get this right, and it is considerably wider than "entries and definitions":

| Syncs | Stays on the device |
| --- | --- |
| Journal entries and tasks (`journalEntity:73`), entry links (`entryLink:116`), definitions — categories, labels, habits, dashboards, measurables (`entityDefinition:111`), AI configs and their deletions (`aiConfig:131`, `aiConfigDelete:158`), saved task filters and their deletions (`savedTaskFilter:168`, `savedTaskFilterDelete:174`), config flags (`configFlag:178`), theme mode (`themingSelection:185`), sync node profiles (`syncNodeProfile:141`), Daily OS user name (`dailyOsUserName:199`), notifications and their read state (`notification:205`, `notificationStateUpdate:214`), task agents and their links (`agentEntity:352`, `agentLink:370`), AI consumption events — tokens, cost, energy (`consumptionEvent:389`) | TTS voice and speed, pane widths, AI concurrency, agent throttle deadlines, day-planning exclusions |

Two caveats a writer needs. First, the remaining variants — `backfillRequest`,
`mediaRequest`, `outboxBundle`, the `onboardingSnapshot*` family — are
transport machinery, not user data, and should not appear in a user-facing
table. Second, not everything that syncs is journal data: `syncNodeProfile` and
`dailyOsUserName` are explicitly "device-preference value, not journal data"
and skip gap detection (`:137-140`, `:195-198`), and derived task counts are
never sent even though the filter that produces them is (`:167`).

- Theme: `lib/features/theming/state/theming_controller.dart` (enqueues a sync
  message); `features/theming/README.md` — "Device-local preferences … do **not**
  sync; the theme does."
- Throttle state: `lib/features/agents/wake/wake_throttle_coordinator.dart:82`
  — "throttle state is per-device and should NOT be synced to other devices."
- TTS: `lib/features/tts/model/tts_settings.dart` (SettingsDb keys, no sync
  message) — `speech.mdx` already says the voice is device-local, which is
  correct.

This is likely the single most useful addition available to the sync section.

---

### 3.6 Melious.ai is recommended without the disclosure the manual itself demands

`index.mdx` sets the bar:

> "choose a provider only after checking its retention, training, jurisdiction,
> and account settings."

`onboarding.mdx` then names **Melious.ai** "the recommended EU-hosted default
with dynamic model routing" and supplies none of those four facts.

In code Melious is an ordinary third-party provider with its own base URL and
API key (`lib/features/ai/repository/melious_inference_repository.dart`); the
in-app tagline is "EU-hosted · dynamic catalog · eco routing"
(`app_en.arb:1395`). Nothing is wrong with the integration. The problem is
editorial: a page that sets a due-diligence bar and then clears it for nobody
reads as an endorsement without evidence.

**Recommendation:** one sentence on who operates Melious, its retention policy,
and Lotti's relationship to it — or drop the word "recommended".

---

### 3.7 The roadmap describes unshipped features in the present tense

`roadmap.mdx`:

> "Relationship data gets the strictest treatment Lotti has: it **is** stored
> locally on your devices, never on a Lotti server."

The page header disclaims the whole page, but a paragraph read in isolation —
or quoted — is a shipped privacy guarantee about a feature that does not exist.
Use future tense consistently ("will be stored").

---

### 3.8 `manual-maintenance.mdx` is contributor documentation in a user sidebar

`make manual_check`, R2 buckets, `screenshot-cases.json`, the release-gate
command. All accurate; wrong audience for the final entry under "Reference".
Consider moving it to `docs-site/README.md` or `CONTRIBUTING.md` and linking it
from the manual footer.

---

## 4. Notable strengths — preserve these as house style

**`sync-and-data/add-device.mdx`** is unusually good security writing. It
separates the check code (recognition) from emoji verification
(authentication), states plainly that the check code says nothing about *who*
is on the other end, and warns that closing the sheet hides but does not revoke
the code. All three match the source exactly
(`pairing_check_code.dart:18-21`, `provisioning_controller.dart:301-317`).

**`sync-and-data/health-import.mdx`** explains *why* a permission prompt cannot
be re-raised — Apple deliberately does not tell an app whether it may read a
type — instead of saying "check settings". That is the difference between
documentation and a FAQ.

---

## Suggested fix order

1. **§1.7 first**, then **§1.1, §1.2 and §1.4(b)**. §1.7 is the human-approval
   promise and the only finding where the manual under-states what the app
   will do without asking; the other three mislead about what the product can
   do or where it can be reached.
2. **§1.3, §1.4(a), §1.5, §1.6** — one naming and navigation sweep across the
   English tree, then the ten translated trees.
3. **§3.1** — demo mode page plus surface-inventory entries. Note that this
   does not "make the gate pass": the gate already fails on
   `settings-sync-unavailable`, and adding demo rows adds work rather than
   removing it. The point is coverage, not a green command.
4. **§3.5, §3.2, §3.3** — content additions where the manual is accurate but
   unhelpful.
5. **§3.4, §3.6, §3.7, §3.8** — editorial.

Items 1 and 2 require the same edit in
`docs-site/i18n/<locale>/docusaurus-plugin-content-docs/current/` for all ten
non-English locales. Run `make manual_check` afterward; note that it validates
page-path parity and rejects untranslated copies, but cannot detect a
translated sentence that still asserts the old fact.
