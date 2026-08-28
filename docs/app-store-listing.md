# App Store listing — first submission draft

Copy and answers for App Store Connect, written to pass review first and be
tuned later. Character limits are Apple's; every field below is within them.
The screenshots come from `make store_screenshots_ios` (see
[knowledge/conventions/screenshots.md](../knowledge/conventions/screenshots.md)).

## App information

| Field | Value |
|-------|-------|
| Name (30) | `Lotti` |
| Subtitle (30) | `Private logbook, tasks & time` |
| Primary category | Productivity |
| Secondary category | Lifestyle |
| Bundle ID | `com.matthiasn.lotti` |
| Age rating | 4+ — no objectionable content, no user-generated content shared with others, no gambling, no unrestricted web access |
| Privacy policy URL | https://github.com/matthiasn/lotti/blob/main/PRIVACY.md |
| Support URL | https://github.com/matthiasn/lotti/issues |
| Marketing URL | https://github.com/matthiasn/lotti |
| Copyright | `© 2016–2026 Matthias Nehlsen` |
| License note for the description | GPL-3.0, source on GitHub |

## Promotional text (170 — 167 characters)

```text
Tasks, habits, tracked time, voice notes and journal, kept on your own devices. No account, no Lotti server. AI and encrypted sync are optional and yours to configure.
```

## Description (4000)

```text
Lotti is a private logbook for the work you actually did.

It records what you meant to do and what actually happened, and keeps them as separate facts: tasks with checklists and planned time, the hours you really tracked against them, voice notes and photos from the day, journal entries, habits, and health data. Everything lives in a local database on your own devices.

WHAT IT DOES

• Tasks — plan work with checklists, due dates, priorities and estimates, and see what is blocked by what.
• Time tracking — start a timer on the task you are on; every tracked session stays attached to it.
• Voice notes — record, transcribe, and let the app turn a note into checklist items and task updates you approve one by one.
• Habits — daily and weekly routines with a completion history that is honest about the imperfect weeks.
• Journal — notes, photos and audio in one dated stream, linked to the tasks they belong to.
• Insights — where your tracked hours went, by category and over time.
• Health — import steps, sleep and workouts from Apple Health to see them next to your own records.

AI ASSISTANTS, ON YOUR TERMS

Lotti can hand each task or area to a persistent assistant that reads what you record, keeps the mess summarised, and proposes the next step. Proposed changes wait for your approval — nothing is written to your journal until you confirm it. AI is optional: you connect a provider under your own key, and the route Lotti recommends is European infrastructure running open-weight models. No Lotti account is needed, and there is no Lotti server.

PRIVATE BY CONSTRUCTION

• No telemetry, no analytics, no crash reporting.
• Local-only by default. Your data is in SQLite databases and files on your device, exportable at any time.
• Optional sync between your own devices is end-to-end encrypted via Matrix; the relay holds ciphertext only.
• Optional AI is routed per category to the provider you choose, under your own key.

Lotti is free and open source (GPL-3.0), in development since 2016, and also available for macOS, Linux, Windows and Android.
```

## Keywords (100, comma-separated, no spaces — 88 characters)

```text
task,time tracking,habit,journal,logbook,privacy,offline,encrypted,notes,voice,checklist
```

"Productivity" is the primary category and is searched as such; it would only
have pushed the string past the limit.

## What's New (first release)

```text
First App Store release.
```

## Screenshots

Upload the dark set first (it is the default theme), then the light set as
additional frames if wanted. Files come from `build/store_screenshots/ios/`:

| Slot in App Store Connect | Device folder | Size |
|---------------------------|---------------|------|
| iPhone 6.9" Display | `iphone_17_pro_max/` | 1320 × 2868 |
| iPhone 6.5" Display (only if the record insists on it) | `iphone_14_plus/` | 1284 × 2778 |
| iPad 13" Display | `ipad_pro_13_inch_m5/` | 2064 × 2752 |

App Store Connect keeps one tab per display size; a file dropped on the wrong
tab is rejected with that tab's sizes ("1242 × 2688 … 1284 × 2778" is the
6.5" tab). The very same message also means "this PNG has an alpha channel" —
the script flattens its captures, but a screenshot taken any other way must be
run through `tool/store_screenshots/strip_alpha.py` first. The 6.9" set is the one Apple scales down for every smaller
iPhone, so the 6.5" set is a fallback, captured with
`LOTTI_IOS_DEVICES="iPhone 14 Plus"` on a simulator created from that device
type (`xcrun simctl create "iPhone 14 Plus"
com.apple.CoreSimulator.SimDeviceType.iPhone-14-Plus <runtime>`).

Order within a slot, as captured (`store_en_dark_01_tasks.png` …):

1. Tasks — what you meant to do
2. Task detail — checklist, cover art and logged time attached to the intent
3. Habits — four imperfect weeks
4. Time analysis — where the tracked hours went
5. Journal — notes, photos and time records in one stream

## App Privacy questionnaire

Two facts are not in question: the developer operates no server and ships no
analytics, advertising or crash-reporting SDK (`pubspec.yaml` has none; see
`PRIVACY.md`), and optional Matrix sync moves end-to-end encrypted data between
the user's own devices through a homeserver the user chooses — the developer
never receives it, and a homeserver holds only ciphertext.

The one judgement call is **optional AI**. When the user connects a provider
under their own key, journal content is sent to that provider in readable form,
and `PRIVACY.md` says plainly that a cloud provider may log or retain requests.
Apple counts data as *collected* when it leaves the device and is retained
beyond servicing the request, whoever does the retaining. Apple's optional
disclosure exemption for user-directed transfers requires, among other things,
that the user affirmatively chooses each transfer — true for a manual "Update
now", not for an agent's automatic wakes once the user has switched those on.

**Recommended answer: declare the optional AI path rather than rely on the
exemption.** Under-declaring is what gets a listing pulled; over-declaring
costs nothing.

| Question | Answer |
|----------|--------|
| Do you or your third-party partners collect data from this app? | Yes |
| Data types | User Content → *Other User Content* (journal text, voice-note transcripts, task titles and checklists the user chooses to send to their AI provider) |
| Purposes | App Functionality |
| Linked to the user's identity? | Yes — the provider receives it under the user's own account and API key, which identifies them to that provider; the absence of a Lotti account does not make it unlinked |
| Used for tracking? | No |

Keep "Data Not Collected" only if the account holder decides the exemption
holds for every supported provider; that decision is theirs, not the code's.

## Permissions the reviewer will see

Every permission the app actually uses maps to a visible feature:

| Permission | Where it is used |
|------------|------------------|
| Microphone | Voice notes (record button on a task or the journal) |
| Camera | Scanning the QR code when pairing a second device for sync |
| Photo library (read / add) | Attaching photos to entries; saving an image back to the library |
| Health (read / update) | Settings → Health import: steps, sleep, workouts |
| Location (when in use) | Optional location on journal entries |
| Contacts | Picking people for the relationships feature; only the chosen contact is read |

Calendars and Apple Music appear in the plist only because the permission
library requires the strings; they are marked as unused there.

## Export compliance

`ios/Runner/Info.plist` declares `ITSAppUsesNonExemptEncryption = false`, so
App Store Connect will not ask the encryption questions on upload. The app does
use encryption beyond HTTPS — Matrix end-to-end encryption via vodozemac (Olm /
Megolm: Curve25519, AES-256, HMAC-SHA-256), all standard algorithms. That is the
"uses standard encryption, exempt from a CCATS" category, which is what the
declaration expresses, but it is a legal classification the account holder
should confirm once, not something the code decides.

## Review notes (App Review Information)

```text
No account or sign-in exists, and Lotti operates no server; optional AI and
Matrix sync talk only to services the user configures. To see the app populated,
choose "Explore with sample data" on the first-run welcome screen (or later via
Settings → Onboarding). That opens a sandboxed demo world with tasks, habits,
tracked time, notes and photos, clearly marked by a banner, and does not touch
real data.

AI features require the user to connect their own provider and key (Settings →
AI). Without one, everything else works fully offline. Health import reads
Apple Health only after the user grants access in Settings → Health.
```

Contact: the account holder's name, phone and email go in the review contact
fields; demo credentials are not needed.
