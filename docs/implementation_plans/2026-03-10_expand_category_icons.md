# Expand Category Icons — Meaningful New Icons (2026-03-10)

## Summary

Add **35 new meaningful icons** to the `CategoryIcon` enum, growing the palette from 65 to
100 icons. The new icons fill real-world gaps that users commonly need for life-tracking
categories: pets, cycling, hiking, cooking, coffee, movies, podcasts, gardening, coding,
spirituality, volunteering, and more.

No existing icons are removed or renamed — the change is purely additive, so serialization
is fully backwards-compatible.

## Motivation

The current 65 icons cover health, work, personal development, and basic utilities well,
but users frequently create categories for which no fitting icon exists:

- **Outdoor activities**: cycling, hiking, camping — none available today.
- **Pets & animals**: one of the most common life categories, completely absent.
- **Cooking vs. dining**: "dining" exists (restaurant icon) but not cooking/kitchen.
- **Beverages**: coffee/tea — extremely common daily habit tracking.
- **Entertainment**: movies/TV, podcasts, theater — only gaming and music exist.
- **Communication**: email, chat, video calls — no dedicated icons.
- **Creative & skilled trades**: coding, crafts, dance — only art/photography exist.
- **Household**: gardening, laundry, repairs — only cleaning/chores exist.
- **Financial**: banking, investments, receipts — wallet/money/savings are not enough.
- **Spiritual / gratitude**: completely absent.
- **Events & celebrations**: birthdays, gifts, parties — missing.
- **Science & languages**: absent from education group.

## New Icons (35)

### Nature & Outdoors (5)
| Enum value | Display name | IconData | Keyword mappings |
|---|---|---|---|
| `cycling` | Cycling | `Icons.directions_bike` | bike, cycle, bicycle |
| `hiking` | Hiking | `Icons.hiking` | hike, trail, trek |
| `camping` | Camping | `MdiIcons.tent` | camp, tent, outdoor |
| `pets` | Pets | `Icons.pets` | pet, dog, cat, animal |
| `garden` | Gardening | `MdiIcons.flower` | garden, plant, flower |

### Food & Drink (2)
| Enum value | Display name | IconData | Keyword mappings |
|---|---|---|---|
| `cooking` | Cooking | `MdiIcons.chefHat` | cook, kitchen, recipe, bake |
| `coffee` | Coffee | `Icons.coffee` | coffee, tea, cafe, caffeine |

### Communication (3)
| Enum value | Display name | IconData | Keyword mappings |
|---|---|---|---|
| `email` | Email | `Icons.email` | email, mail |
| `chat` | Chat | `Icons.chat` | chat, message, text |
| `videoCall` | Video Call | `Icons.videocam` | video, call, zoom, facetime |

### Entertainment (3)
| Enum value | Display name | IconData | Keyword mappings |
|---|---|---|---|
| `movie` | Movies | `Icons.movie` | movie, film, cinema, tv, television |
| `podcast` | Podcast | `Icons.podcasts` | podcast, audio, radio |
| `theater` | Theater | `Icons.theater_comedy` | theater, theatre, drama, comedy |

### Creative & Skills (3)
| Enum value | Display name | IconData | Keyword mappings |
|---|---|---|---|
| `coding` | Coding | `Icons.code` | code, programming, developer, software |
| `crafts` | Crafts | `Icons.handyman` | craft, diy, maker, sewing, knitting |
| `dance` | Dance | `MdiIcons.danceBallroom` | dance, dancing, ballet |

### Household & Maintenance (2)
| Enum value | Display name | IconData | Keyword mappings |
|---|---|---|---|
| `laundry` | Laundry | `MdiIcons.washingMachine` | laundry, wash, clothes |
| `repair` | Repair | `Icons.build` | repair, fix, tools, maintenance |

### Finance & Career (3)
| Enum value | Display name | IconData | Keyword mappings |
|---|---|---|---|
| `banking` | Banking | `Icons.account_balance` | bank, banking |
| `investment` | Investment | `Icons.trending_up` | invest, stocks, portfolio, trading |
| `receipt` | Receipt | `Icons.receipt_long` | receipt, expense, invoice, bill |

### Events & Celebrations (3)
| Enum value | Display name | IconData | Keyword mappings |
|---|---|---|---|
| `celebration` | Celebration | `Icons.celebration` | party, celebrate, birthday |
| `gift` | Gift | `Icons.card_giftcard` | gift, present |
| `cake` | Birthday | `Icons.cake` | cake, anniversary, birthday party |

### Education & Knowledge (3)
| Enum value | Display name | IconData | Keyword mappings |
|---|---|---|---|
| `language` | Language | `Icons.translate` | language, translate, foreign |
| `science` | Science | `Icons.science` | science, experiment, lab, chemistry |
| `presentation` | Presentation | `MdiIcons.presentationPlay` | presentation, slides, talk, lecture, conference |

### Spiritual & Well-being (2)
| Enum value | Display name | IconData | Keyword mappings |
|---|---|---|---|
| `prayer` | Prayer | `MdiIcons.handsPray` | prayer, pray, church, worship, spiritual, faith |
| `gratitude` | Gratitude | `MdiIcons.handHeart` | gratitude, thankful, grateful, blessing |

### Self-care & Wellness (2)
| Enum value | Display name | IconData | Keyword mappings |
|---|---|---|---|
| `spa` | Self-Care | `Icons.spa` | spa, self-care, relax, pamper, skincare, beauty |
| `stretching` | Stretching | `MdiIcons.humanHandsup` | stretch, warmup, cool down, flexibility |

### Weather & Nature (2)
| Enum value | Display name | IconData | Keyword mappings |
|---|---|---|---|
| `weather` | Weather | `Icons.wb_sunny` | weather, sun, sunny, rain |
| `nature` | Nature | `Icons.park` | nature, park, forest, tree, outdoors |

### Volunteering (2)
| Enum value | Display name | IconData | Keyword mappings |
|---|---|---|---|
| `volunteer` | Volunteering | `Icons.volunteer_activism` | volunteer, charity, donate, help, community |
| `recycling` | Recycling | `Icons.recycling` | recycle, eco, green, environment, sustainability |

## Files to Modify

### 1. `lib/features/categories/domain/category_icon.dart`
**The main file. All changes concentrate here.**

- **Enum values** (lines 137–202): Add 35 new values organized in new groups after the
  existing "Utility & Tracking" section, maintaining the established comment-group style.
- **`iconData` getter** (lines 212–336): Add 35 new `case` entries mapping each new enum
  value to its `IconData`.
- **`displayName` getter** (lines 339–456): Add 35 new `case` entries with human-readable
  names.
- **`suggestFromName` keyword mappings** (lines 510–572): Add ~60 new keyword entries for
  the new icons.

### 2. `test/features/categories/domain/category_icon_test.dart`
**Update existing tests, add new ones.**

- The `'should return correct IconData for all enum values'` test already iterates all
  values — it will automatically cover the new icons.
- The `'should have unique display names'` test already validates uniqueness — it will
  catch duplicates automatically.
- **Add**: Spot-check tests for a sampling of new icons' `iconData` and `displayName`.
- **Add**: `suggestFromName` tests for new keyword mappings (coffee → coffee, pet → pets,
  hike → hiking, etc.).
- **Add**: JSON roundtrip still passes for all values (existing test already iterates all
  values).

### 3. `test/features/categories/ui/widgets/category_icon_picker_test.dart`
**Minor update.**

- Existing "displays all icons" test likely asserts on count — update expected count from
  65 to 100.

### 4. `CHANGELOG.md`
- Add entry under `[0.9.913]` (or the next version if bumped):
  `### Added` → "35 new category icons covering outdoor activities, pets, cooking, movies,
  communication, spiritual, and more."

### 5. `flatpak/com.matthiasn.lotti.metainfo.xml`
- Mirror the CHANGELOG entry.

### 6. Feature README (if one exists for categories)
- Update any mention of "65 icons" to "100 icons" and add the new groups to the
  documentation.

## Files NOT Modified

- **No model/serialization changes**: `CategoryIcon` serializes via `name` — new enum values
  are automatically serialized.
- **No UI widget changes**: `CategoryIconDisplay`, `CategoryIconCompact`, `CategoryIconPicker`
  all iterate `CategoryIcon.values` — new icons appear automatically.
- **No database migration**: Icons are stored as strings, not integers. New enum values
  deserialize automatically; old databases with no icon set return `null` (fallback to
  first-letter display).
- **No generated code**: `CategoryIcon` is a plain Dart enum, not Freezed-generated.

## Implementation Order

1. Add enum values + `iconData` + `displayName` + keyword mappings to
   `category_icon.dart`.
2. Run `dart-mcp.analyze_files` to verify no analyzer complaints.
3. Run `dart-mcp.dart_format` to normalize formatting.
4. Update tests: spot-checks + keyword mapping tests.
5. Run targeted tests: `dart-mcp.run_tests` on
   `test/features/categories/domain/category_icon_test.dart` and
   `test/features/categories/ui/widgets/category_icon_picker_test.dart`.
6. Update CHANGELOG.md and metainfo.xml.
7. Update the categories feature README if it mentions icon count.
8. Final: run analyzer + formatter one last time.

## Backward Compatibility

- **Fully backward-compatible.** Existing serialized `CategoryIcon` names are unchanged.
- Old clients that don't know about new enum values will get `null` from `fromJson()` and
  gracefully fall back to the first-letter display — this is the existing behavior.
- No sync protocol changes required.

## Design Decisions

- **100 total icons** (not unlimited): A curated set keeps the picker UI manageable. At 4
  columns, 100 icons = 25 rows — still scrollable but not overwhelming.
- **Group organization**: New icons are placed in new semantic groups rather than shoved
  into existing ones, keeping the code organized.
- **Material Icons preferred over MdiIcons** where both offer equivalents, since Material
  Icons are bundled with Flutter (zero extra weight). MdiIcons used only when Material
  Icons lack a good equivalent.
- **No picker UI changes**: The existing 4-column grid and search-by-name suggestion work
  automatically for new icons. If the grid feels crowded at 100, a follow-up PR could add
  search/filtering to the picker, but that's out of scope here.
