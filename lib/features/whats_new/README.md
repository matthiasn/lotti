# What's New Feature

The What's New feature displays release notes to users in an editorial magazine-style modal. It shows unseen releases when the user opens the modal from Settings, tracking which releases have been viewed.

## Architecture

```
lib/features/whats_new/
├── model/
│   ├── whats_new_content.dart      # Content model (release + markdown + banner URL)
│   ├── whats_new_release.dart      # Release metadata (version, date, title, folder)
│   └── whats_new_state.dart        # State model (list of unseen content)
├── repository/
│   └── whats_new_service.dart      # Fetches index.json and content.md from remote
├── state/
│   └── whats_new_controller.dart   # Riverpod controller managing state & seen tracking
├── ui/
│   ├── whats_new_indicator.dart    # Badge showing unseen count (for Settings page)
│   └── whats_new_modal.dart        # The main modal UI
└── util/
    └── whats_new_markdown_parser.dart  # Parses markdown, resolves relative image URLs
```

## Content Source

Release content is hosted in the `lotti-docs` repository at:
```
https://raw.githubusercontent.com/matthiasn/lotti-docs/main/whats-new/
```

### Content Structure

```
lotti-docs/whats-new/
├── index.json           # List of all releases
├── 0.9.805/
│   ├── content.md       # Markdown content for this release
│   └── banner.jpg       # 21:9 hero banner image
├── 0.9.804/
│   ├── content.md
│   └── banner.jpg
└── ...
```

### index.json Format

```json
{
  "releases": [
    {
      "version": "0.9.805",
      "date": "2026-01-09T00:00:00.000Z",
      "title": "What's New Modal",
      "folder": "0.9.805"
    }
  ]
}
```

Releases are ordered by date descending (newest first).

### content.md Format

```markdown
# Release Title

Brief introduction paragraph.

---

## Feature Section

Description with optional images.

![screenshot](./screenshot.png)
```

- First section (before `---`) becomes the header
- Subsequent sections separated by `---` become the body
- Relative image paths (`./image.png`) are resolved to full URLs automatically

## Key Behaviors

### Version Filtering

Only releases with versions <= the installed app version are shown. This prevents users from seeing notes for features they don't have yet.

```dart
// In whats_new_controller.dart
if (_isNewerVersion(release.version, currentVersion)) {
  continue; // Skip releases newer than installed version
}
```

### Auto-Show on Version Update

The modal automatically displays on app launch when the version changes or on first launch.

```dart
// In whats_new_controller.dart
@riverpod
Future<bool> shouldAutoShowWhatsNew(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  final currentVersion = packageInfo.version;
  final lastLaunchedVersion = prefs.getString('whats_new_last_launched_version');

  // Same version as last launch - don't show
  if (lastLaunchedVersion == currentVersion) return false;

  // First launch OR version changed - check for unseen releases
  final state = await ref.read(whatsNewControllerProvider.future);
  final shouldShow = state.hasUnseenRelease;

  // Only persist after successful read
  await prefs.setString('whats_new_last_launched_version', currentVersion);
  return shouldShow;
}
```

- Uses SharedPreferences key `whats_new_last_launched_version` to track last launched version
- On first launch (`lastLaunchedVersion` is null), shows modal if `state.hasUnseenRelease` is true
- On subsequent launches, only shows when `currentVersion` differs from `lastLaunchedVersion`
- Version is persisted only after `whatsNewControllerProvider` succeeds (graceful degradation)
- Triggered in `AppScreen` via `ref.listen(shouldAutoShowWhatsNewProvider, ...)` on startup

### Seen Tracking

- Uses SharedPreferences with keys like `whats_new_seen_0.9.805`
- Only marks releases as "seen" that the user actually navigated to
- Swiping through pages tracks the max viewed index
- "Skip" button marks ALL releases as seen
- Dismissing by tap/swipe outside only marks viewed releases

### Image Precaching

All banner images and images in markdown content are precached before the modal opens for smooth page transitions:

```dart
for (final release in releases) {
  precacheImage(NetworkImage(release.bannerImageUrl), context);
  // Also precache images extracted from markdown
}
```

## Adding a New Release

1. Create folder in `lotti-docs/whats-new/{version}/`
2. Add `content.md` with markdown content
3. Add `banner.jpg` (21:9 aspect ratio, e.g., 2100x900 or 1050x450)
4. Update `index.json` with the new release entry (add to top of array)
5. Update `CHANGELOG.md` and metadata in the main lotti repo

## UI Components

### WhatsNewModal

The main modal uses WoltModalSheet with:
- `heroImage`: 21:9 banner with gradient overlay and version badge
- `child`: Scrollable markdown content
- `stickyActionBar`: Navigation footer with Skip, arrows, and indicator dots

### WhatsNewIndicator

A badge widget for the Settings page showing the count of unseen releases. Returns empty when no unseen releases.

## Testing

Tests use a mock PackageInfo to simulate a high app version (99.99.99) so all test releases are included.

```dart
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(
  const MethodChannel('dev.fluttercommunity.plus/package_info'),
  (methodCall) async => {'version': '99.99.99', ...},
);
```
