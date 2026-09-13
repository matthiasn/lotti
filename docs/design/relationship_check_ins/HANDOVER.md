# Relationship check-ins — design handover

Prepared 2026-09-13 from the Flutter implementation at base commit
`d5893d8c85`, with the revised screenshots reflecting the fixes in this change. The accompanying screenshot bundle uses the existing People
inventory harness and synthetic penguin-world fixtures. These are rendered
production widgets at phone/desktop sizes, not captures from the affected phone.

## Design brief

Keep the People overview and its photographs. Focus this iteration on recording
reliability, photo framing, and making a short check-in easy to record and review.
The narrative should be the first thing a user sees when reviewing an interaction.
Audio is an explicit entry choice; words remain editable before Save. Sentiment
is optional and belongs to the user, never to transcription or an agent.

## Implemented iteration

New capture offers Write or Record audio; the existing microphone shortcut
still opens audio directly. The review/edit form starts with the narrative,
followed by interaction type/time/duration and More for sentiment and notes.
Preparation, processing and transcript readiness are announced; failures offer
recovery. Existing populated optional details remain expanded when editing.

The seeded Melious profile already targets cloud Whisper Large v3. The corrected
direct fallback also prefers Melious Whisper over other Melious audio models,
and never discovers a large native model automatically. The exact identity of
“Mirius” still needs confirmation before a device routing claim is possible.

## Surface inventory

Paths below are relative to `lib/features/relationships/` unless qualified.
The complete screenshot contact sheet accompanies this document as `index.html`.

| Surface | Code | Baseline screenshot |
|---|---|---|
| People, recency bands, empty state | `ui/pages/relationships_page.dart`, `ui/widgets/people_list_row.dart` | `people_list_mobile_dark.png`, `people_list_empty_mobile_dark.png` |
| Person, hero and section cards | `ui/pages/relationship_details_page.dart`, `ui/widgets/person_header.dart` | `person_page_mobile_dark.png` |
| Check-in creation | `ui/widgets/check_in_capture_sheet.dart` | `check_in_capture_mobile_dark.png` |
| Check-in review/edit | `showCheckInEditSheet` in the same file | `check_in_edit_mobile_dark.png` |
| Recording | `lib/features/speech/ui/widgets/recording/audio_recording_modal.dart` | See recording state captures in the revised bundle |
| Person create/edit | `ui/widgets/relationship_form_modal.dart` | `person_form_add_mobile_dark.png`, `person_form_edit_mobile_dark.png` |
| Photo actions and crop | `ui/widgets/person_avatar_sheet.dart`, `ui/widgets/avatar_crop_sheet.dart` | `person_photo_sheet_mobile_dark.png`, `avatar_crop_mobile_dark.png` |
| Contact import/select/review | `ui/pages/contact_import_page.dart` | `contact_import_select_mobile_dark.png`, `contact_import_review_mobile_dark.png` |
| Person chat | `ui/pages/relationship_chat_page.dart`, `ui/widgets/relationship_chat_pane.dart` | `person_chat_mobile_dark.png` |
| Briefing states and proposals | `ui/widgets/relationship_briefing_card.dart` | `agent_card_*_mobile_dark.png` |

The screenshot inventory includes desktop counterparts and light-theme overview
states, plus missing/syncing photo, unconfigured agent, and post-call variants.
Annotations are captions beside the originals so the source captures stay intact.

## Navigation and check-in flow

The route definitions are in `lib/beamer/locations/relationships_location.dart`:
`/people` → `/people/:relationshipId` → `/people/:relationshipId/chat`. Phones
push pages; desktop selects the person or chat within the list/detail split.
Check-in capture and edit are modal surfaces, not additional routes.

Before this change, Log check-in opened the full form and the separate microphone
shortcut opened that form followed by the shared recorder. Tapping a historical
check-in opened the same form prefilled. Returning from a contact action can offer
a check-in with the interaction type, start and elapsed duration prefilled.

Audio is a separate `JournalAudio` linked to the person. The recorder persists it
before transcription. The transcript is appended to the editable narrative;
only Save creates/updates the `CheckInEntry`. Discarding the form after recording
does not delete that saved audio. There is no direct audio-id field on
`CheckInData`; a future per-check-in playback design needs an explicit association
decision, not an assumption that the current schema already supports it.

The runtime contract and lifecycle diagrams are maintained in
[Relationships](../../../knowledge/features/relationships.md); transcription
resolution is documented in
[AI execution paths](../../../knowledge/features/ai/execution-paths.md) and
[embedded speech](../../../knowledge/features/ai/embedded-speech.md).

## Data available to design

| Model/source | Information available |
|---|---|
| `lib/classes/relationship_data.dart` | Display name, nickname, status/history, importance, cadence, birthday, profile/language, avatar/crop, banner/framing, contact channels and OS contact references |
| `lib/classes/check_in_data.dart` | Person reference, interaction type, optional sentiment, topics, next-time guidance, avoid guidance |
| `lib/classes/journal_entities.dart` | Shared entry narrative and metadata; start/end encode interaction duration |
| `ui/widgets/check_ins_card.dart` | Historical row projection: timestamp, interaction, duration, sentiment, narrative and topics |

Do not introduce a check-in title, AI-assigned sentiment, or per-check-in audio
playback as if those were existing stored fields. Contact channels and OS contact
references are excluded from agent context. People/check-ins have category and
privacy inheritance; they are intentionally absent from the main journal list.

## Findings and verification limits

| Finding | Evidence / disposition |
|---|---|
| Large native model selected ahead of configured cloud | Reproduced in `profile_automation_service_test.dart`: original fallback chooses `large-v3` over cloud and tiny. Corrected discovery prefers cloud and restricts native fallback to installed Whisper tiny/base. Explicit profile assignments remain deliberate choices. |
| Recording tap appears inert | Permission denial and failed start were logged but not shown. Corrected recorder returns a typed failure and recording UI displays localized recovery guidance. |
| Repeated taps overlap initialization | Reproduced while permission is pending. Start is now serialized so a second tap cannot replace the intended person. |
| Unhandled transcript database error | Reproduced in `check_in_transcription_service_test.dart`. Read/notification failures now end the wait safely. |
| Fast cloud failure missed | The error is keyed by the new audio entry, but the listener ignored its initial value. It now observes an error that arrived while the recorder modal was closing. |
| Vertical photo pan lost to sheet scrolling | Reproduced with the crop inside a scroll view. The crop now owns gestures beginning inside its viewport and preserves geometric clamping. |
| Exact phone crash and actual server | Not verified: no phone crash report, runtime connection or provider configuration was supplied. “Mirius” is not a provider name in source; Melious and generic Whisper servers are separate supported routes. Do not label screenshots or release notes as proof of Mirius reachability. |

Cloud HTTP failures do not trigger a retry through a local model in this check-in
path. Native fallback describes model discovery when a configured profile does
not own transcription, not failover after a cloud request fails. A native OS
memory kill cannot be caught by Dart exception handling; avoiding accidental
large-model selection reduces that risk but does not establish the reported
crash's cause.

## Review priorities

1. Keep the narrative visible first and reduce the initial number of controls.
2. Make recording, processing, failure, and editable transcript states distinct.
3. Keep Save reachable and prevent it while capture/transcription is pending.
4. Make optional sentiment and detailed notes discoverable without requiring them.
5. Check short phones, large text, keyboard visibility, and translated labels.
6. Validate physical microphone permission, interrupt/background/resume, network
   outage and low-memory behavior on the affected phone before declaring the
   reported device crash resolved.

Use the existing [design system](../../../knowledge/features/design_system/index.md).
New colors, spacing, typography or other visual tokens require a separate design
agreement. Existing overview imagery should carry through this iteration.
