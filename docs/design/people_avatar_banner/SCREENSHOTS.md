# The People inventory bundle — 38 screenshots

Produced by
[`test/features/relationships/ui/pages/people_inventory_screenshots_test.dart`](../../../test/features/relationships/ui/pages/people_inventory_screenshots_test.dart),
which renders the production widgets inside the production app shell with the
production theme, real bundled fonts and the real monospace face. Nothing is a
mockup.

```sh
make people_inventory_screenshots          # → build/people_inventory/
```

Every capture is under a clock fixed to **Thursday 13 August 2026, 14:05**, so
every relative timestamp, cadence pill and "days over" count is stable across
runs. Fixtures are the fictional penguin crew; no real person's data is used.

Viewports are the harness's own: `mobile` = 402 × 874 @3×, `desktop` =
1440 × 900 @2×.

## People list

| File | Surface |
|---|---|
| `people_list_mobile_dark.png` · `_light` | Three bands, summary card, five people, six persona accents |
| `people_list_desktop_dark.png` · `_light` | The list/detail split with nothing selected |
| `people_list_empty_mobile_dark.png` · `_light` | Empty state and its inline CTA |
| `people_list_empty_desktop_dark.png` · `_light` | Same, split layout |
| `people_list_rows_mobile_dark.png` | The five rows alone — every cadence pill kind side by side |

## Person page

| File | Surface |
|---|---|
| `person_page_mobile_dark.png` · `_light` | Enrolled, lapsed, current briefing — the default reading |
| `person_page_desktop_dark.png` · `_light` | The same page in the desktop detail pane |
| `person_page_no_briefing_mobile_dark.png` | Enrolled, never briefed |
| `person_page_not_enrolled_mobile_dark.png` | A person the agent does not watch |
| `person_page_reach_tasks_mobile_dark.png` | Scrolled to the Reach and Tasks cards |
| `person_page_post_call_mobile_dark.png` | The post-call offer above the check-in log |

The hero wash and the 80 px persona avatar overlapping its fold are the two
surfaces this handover is about; they are clearest in the first two rows.

## Relationship agent card

All six faces of `relationshipAgentCardStateOf`, plus the proposals band. Five
of these never appear on a page in any other capture.

| File | State |
|---|---|
| `agent_card_not_enrolled_mobile_dark.png` | No agent — the consent switch, no AI chrome |
| `agent_card_no_briefing_mobile_dark.png` | Enrolled, nothing written yet |
| `agent_card_running_mobile_dark.png` | A wake in flight |
| `agent_card_failed_mobile_dark.png` | Last wake failed, nothing newer succeeded |
| `agent_card_current_mobile_dark.png` | Fresh briefing, health band, cost |
| `agent_card_out_of_date_mobile_dark.png` | Evidence arrived after the briefing |
| `agent_card_proposals_mobile_dark.png` | Tasks proposed from check-in commitments |

## Capture and forms

| File | Surface |
|---|---|
| `check_in_capture_mobile_dark.png` · `_desktop` | The check-in sheet, empty, *More* folded |
| `check_in_edit_mobile_dark.png` · `_desktop` | Editing — prefilled, *More* unfolded, Delete pinned |
| `person_form_add_mobile_dark.png` · `_desktop` | Add person: Who · Important · How to reach them |
| `person_form_edit_mobile_dark.png` · `_desktop` | The same form prefilled — **note there is no image field** |

## Import and chat

| File | Surface |
|---|---|
| `contact_import_select_mobile_dark.png` | Bulk pick from the address book |
| `contact_import_review_mobile_dark.png` | The review step — importance and cadence per person |
| `person_chat_mobile_dark.png` | The agent conversation as a phone route |
| `person_chat_desktop_dark.png` | The same, replacing the desktop detail pane |

Compare the avatars in `contact_import_review_mobile_dark.png` with the same
two people in `people_list_mobile_dark.png`: the accents differ, because the
review derives them from the OS contact id. See INVENTORY §5.5.

## The identity primitives

| File | Surface |
|---|---|
| `persona_avatar_palette_mobile_dark.png` · `_light` | All six palette accents, then the avatar at 40 / 48 / 80 px — the three sizes the feature draws |

This is the surface a photograph replaces, and the fallback it has to keep
working beside.
