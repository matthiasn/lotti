# Fix Oversized Settings Headers

## Summary

The current `SliverTitleBar` has problems:
- Too tall (120px fixed height wastes screen space)
- Text too large (25px font)
- Titles wrap and make it worse (see "Matrix Sync Maintenance" screenshot)
- Looks ridiculous on desktop

Solution: Make a simpler, more compact header and use it in the Matrix sync pages.

## Goals

- Fix the collision between tall headers and back buttons on compact devices.
- Make headers responsive to device size and text scaling (up to 200%).
- Reduce oversized header height that wastes screen space.
- Start with the settings/sync pages, leave others for later.

## Non-Goals

- No redesign of the settings card content blocks themselves (animations, icons, or segmented
  controls stay as-is).
- No overhaul of global navigation chrome outside the settings/sync stack.
- No new localization strings beyond what's required for optional supporting text.
- RTL (right-to-left) language support is out of scope as the app doesn't currently support it.


## What Success Looks Like

- Headers that don't waste screen space
- Titles that don't collide with back buttons
- Text that remains readable at all accessibility scales

## Implementation Overview

1. Create a new `CompactSliverHeader` widget with smaller text and responsive height.
2. Replace `SliverTitleBar` in the Matrix sync pages shown in screenshots.
3. Test and ship.

## Phase 1 — Build New Header

Create `SettingsPageHeader` widget with:
- Reasonable font size: responsive 28-34px on phones, up to 46px on desktop (was fixed 25px)
- Dynamic height that adapts to content and text scaling
- Support for existing back button without collision
- Handle text overflow with ellipsis for long titles
- Support for optional subtitle text
- Use the `bottom` property to pin segmented controls in the header (for Sync Outbox, Conflicts pages)
- Keep some visual polish: subtle gradient, rounded bottom corners, soft shadow

## Phase 2 — Update Pages & Pin Segmented Controls

Update these specific pages from the screenshots:
- Matrix Sync Settings page - use new header with subtitle
- Matrix Sync Maintenance page - fix the wrapping title issue
- Sync Outbox page - move segmented controls to header `bottom` property so they stay pinned
- Sync Conflicts page - move segmented controls to header `bottom` property
- Matrix Stats page - basic header update

For pages with segmented controls, extract them from the page body and pass as `bottom` widget to keep filters visible while scrolling.

## Phase 3 — Test & Ship

- Run tests
- Update changelog
- Ship it

## Technical Notes

- Use `MediaQuery.of(context).size.width` to determine if phone or tablet
- For text scaling > 1.5x, use FittedBox to prevent overflow
- Keep leadingWidth flexible instead of fixed 100px

## Risks & Mitigations

- **Risk:** Breaking other pages that use SliverTitleBar
  **Mitigation:** Only change the Matrix sync pages for now

- **Risk:** Accessibility issues with smaller text
  **Mitigation:** Test with system text scaling at 200%

## Process Notes

- Use MCP tools for testing and formatting
- Update changelog when done

## References

- `lib/widgets/app_bar/sliver_title_bar.dart`, `lib/widgets/app_bar/title_app_bar.dart`
- `lib/features/settings/ui/pages/sliver_box_adapter_page.dart`
- `lib/features/sync/ui/widgets/sync_list_scaffold.dart`
- `agents.md` — repository-wide collaboration/process guidance
- Existing implementation plans from 2025-10-23 and 2025-10-24 for structure and rigor
