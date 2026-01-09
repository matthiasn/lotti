# What's New Feature Implementation Plan

> **Note:** This is the original implementation plan. The feature has been implemented with enhancements beyond this plan. See `lib/features/whats_new/README.md` for current documentation including:
> - Multi-release support (not just latest)
> - Auto-show on version change or first launch
> - Smart seen tracking per release
> - Glassmorphism UI with animated indicator dots
> - Specific exception handling with logging

## Overview

This document describes the implementation plan for a "What's New" feature that displays release notes in an engaging, swipable modal. The feature fetches remotely-hosted content (Markdown with images) and tracks which releases users have seen using local storage.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DATA FLOW                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Remote Content (GitHub Raw)                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ https://raw.githubusercontent.com/matthiasn/Lotti-resources/     │       │
│  │   └── whats-new/                                                  │       │
│  │       ├── index.json            ◄─── List of releases             │       │
│  │       ├── 0.9.980/                                                │       │
│  │       │   ├── content.md        ◄─── Markdown with sections       │       │
│  │       │   └── banner.png        ◄─── Banner image                 │       │
│  │       └── 0.9.970/                                                │       │
│  │           ├── content.md                                          │       │
│  │           └── banner.png                                          │       │
│  └──────────────────────────────────────────────────────────────────┘       │
│                           │                                                  │
│                           ▼                                                  │
│  WhatsNewService ───────────────────────────────────────────────────        │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ • Fetches index.json                                              │       │
│  │ • Fetches release content.md                                      │       │
│  │ • Parses Markdown into sections (split by ---)                    │       │
│  │ • Constructs image URLs                                           │       │
│  └──────────────────────────────────────────────────────────────────┘       │
│                           │                                                  │
│                           ▼                                                  │
│  WhatsNewController (Riverpod) ─────────────────────────────────────        │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ • Tracks seen/unseen status via SharedPreferences                 │       │
│  │ • Provides hasUnseenRelease for indicator                         │       │
│  │ • Provides parsed sections for modal                              │       │
│  │ • Marks release as seen when modal dismissed                      │       │
│  └──────────────────────────────────────────────────────────────────┘       │
│                           │                                                  │
│                           ▼                                                  │
│  UI Components ─────────────────────────────────────────────────────        │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ WhatsNewIndicator: Pulsing dot when unseen content exists         │       │
│  │ WhatsNewModal: Swipable PageView with banner + sections           │       │
│  └──────────────────────────────────────────────────────────────────┘       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Data Structures

### Remote Data: index.json

```json
{
  "releases": [
    {
      "version": "0.9.980",
      "date": "2026-01-07",
      "title": "January Update",
      "folder": "0.9.980"
    },
    {
      "version": "0.9.970",
      "date": "2025-12-15",
      "title": "December Update",
      "folder": "0.9.970"
    }
  ]
}
```

### Remote Data: content.md

```markdown
# January Update
*Released: January 7, 2026*

---

## New Feature: Timeline View

Visualize your tasks over time with our new timeline component.

![Timeline Screenshot](timeline.png)

---

## Improved Checklist Experience

Checklists now support drag-and-drop reordering and completion animations.

---

## Bug Fixes

- Fixed calendar view not updating
- Improved sync reliability
```

### Dart Models

```dart
@freezed
abstract class WhatsNewRelease with _$WhatsNewRelease {
  const factory WhatsNewRelease({
    required String version,
    required DateTime date,
    required String title,
    required String folder,
  }) = _WhatsNewRelease;

  factory WhatsNewRelease.fromJson(Map<String, dynamic> json) =>
      _$WhatsNewReleaseFromJson(json);
}

@freezed
abstract class WhatsNewIndex with _$WhatsNewIndex {
  const factory WhatsNewIndex({
    required List<WhatsNewRelease> releases,
  }) = _WhatsNewIndex;

  factory WhatsNewIndex.fromJson(Map<String, dynamic> json) =>
      _$WhatsNewIndexFromJson(json);
}

@freezed
abstract class WhatsNewContent with _$WhatsNewContent {
  const factory WhatsNewContent({
    required WhatsNewRelease release,
    required String headerMarkdown,
    required List<String> sections,
    required String? bannerImageUrl,
  }) = _WhatsNewContent;
}

@freezed
abstract class WhatsNewState with _$WhatsNewState {
  const factory WhatsNewState({
    @Default(false) bool isLoading,
    @Default(false) bool hasUnseenRelease,
    WhatsNewContent? latestContent,
    String? errorMessage,
  }) = _WhatsNewState;
}
```

## Markdown Parsing Strategy

The content.md file uses horizontal rules (`---`) to separate pages:

1. **Header Section**: Everything before the first `---` (title, date)
2. **Content Sections**: Each section between `---` markers becomes a swipable page
3. **Image URLs**: Relative image references (e.g., `![Alt](image.png)`) are resolved to absolute URLs

```dart
class WhatsNewMarkdownParser {
  static const String sectionDivider = '\n---\n';

  static WhatsNewContent parse({
    required String markdown,
    required WhatsNewRelease release,
    required String baseUrl,
  }) {
    final parts = markdown.split(sectionDivider);

    // First part is the header
    final headerMarkdown = parts.isNotEmpty ? parts.first.trim() : '';

    // Remaining parts are sections
    final sections = parts.skip(1).map((s) => s.trim()).toList();

    // Resolve relative image URLs
    final resolvedSections = sections.map((section) {
      return _resolveImageUrls(section, baseUrl, release.folder);
    }).toList();

    final bannerImageUrl = '$baseUrl/${release.folder}/banner.png';

    return WhatsNewContent(
      release: release,
      headerMarkdown: _resolveImageUrls(headerMarkdown, baseUrl, release.folder),
      sections: resolvedSections,
      bannerImageUrl: bannerImageUrl,
    );
  }

  static String _resolveImageUrls(String markdown, String baseUrl, String folder) {
    // Replace ![alt](relative.png) with ![alt](absolute-url)
    return markdown.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\((?!http)([^)]+)\)'),
      (match) {
        final alt = match.group(1);
        final path = match.group(2);
        return '![$alt]($baseUrl/$folder/$path)';
      },
    );
  }
}
```

## Service Layer

```dart
class WhatsNewService {
  static const String baseUrl =
      'https://raw.githubusercontent.com/matthiasn/Lotti-resources/main/whats-new';
  static const Duration timeout = Duration(seconds: 10);

  final http.Client _client;

  WhatsNewService({http.Client? client}) : _client = client ?? http.Client();

  Future<WhatsNewIndex?> fetchIndex() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/index.json'))
          .timeout(timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return WhatsNewIndex.fromJson(json);
      }
    } catch (e) {
      // Log error, return null to indicate failure
    }
    return null;
  }

  Future<WhatsNewContent?> fetchContent(WhatsNewRelease release) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/${release.folder}/content.md'))
          .timeout(timeout);

      if (response.statusCode == 200) {
        return WhatsNewMarkdownParser.parse(
          markdown: response.body,
          release: release,
          baseUrl: baseUrl,
        );
      }
    } catch (e) {
      // Log error, return null to indicate failure
    }
    return null;
  }
}
```

## State Management (Riverpod)

```dart
@riverpod
WhatsNewService whatsNewService(Ref ref) {
  return WhatsNewService();
}

@riverpod
class WhatsNewController extends _$WhatsNewController {
  static const String _seenKeyPrefix = 'whats_new_seen_';

  @override
  Future<WhatsNewState> build() async {
    final service = ref.watch(whatsNewServiceProvider);
    final index = await service.fetchIndex();

    if (index == null || index.releases.isEmpty) {
      return const WhatsNewState();
    }

    // Sort by date descending, get latest
    final sortedReleases = [...index.releases]
      ..sort((a, b) => b.date.compareTo(a.date));
    final latestRelease = sortedReleases.first;

    // Check if seen
    final hasSeenLatest = await _hasSeenRelease(latestRelease.version);

    if (hasSeenLatest) {
      return const WhatsNewState(hasUnseenRelease: false);
    }

    // Fetch content for latest unseen release
    final content = await service.fetchContent(latestRelease);

    return WhatsNewState(
      hasUnseenRelease: true,
      latestContent: content,
    );
  }

  Future<bool> _hasSeenRelease(String version) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_seenKeyPrefix$version') ?? false;
  }

  Future<void> markAsSeen() async {
    final content = state.value?.latestContent;
    if (content == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_seenKeyPrefix${content.release.version}', true);

    // Update state
    state = AsyncData(
      state.value!.copyWith(hasUnseenRelease: false),
    );
  }
}
```

## UI Components

### Unseen Indicator

A subtle pulsing indicator shown on a settings/about button when new content is available:

```dart
class WhatsNewIndicator extends ConsumerWidget {
  const WhatsNewIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final whatsNewAsync = ref.watch(whatsNewControllerProvider);

    return whatsNewAsync.when(
      data: (state) {
        if (!state.hasUnseenRelease) return const SizedBox.shrink();

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colorScheme.primary.withOpacity(value),
              ),
            );
          },
          onEnd: () {
            // Reverse animation (creates pulsing effect)
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
```

### Swipable Modal

```dart
class WhatsNewModal extends ConsumerStatefulWidget {
  const WhatsNewModal({super.key});

  static Future<void> show(BuildContext context) async {
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: "What's New",
      hasTopBarLayer: true,
      padding: EdgeInsets.zero,
      builder: (modalContext) => const WhatsNewModal(),
    );
  }

  @override
  ConsumerState<WhatsNewModal> createState() => _WhatsNewModalState();
}

class _WhatsNewModalState extends ConsumerState<WhatsNewModal> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Mark as seen when modal is dismissed
    ref.read(whatsNewControllerProvider.notifier).markAsSeen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final whatsNewAsync = ref.watch(whatsNewControllerProvider);

    return whatsNewAsync.when(
      data: (state) {
        final content = state.latestContent;
        if (content == null) {
          return const Center(child: Text('No content available'));
        }

        final allPages = [content.headerMarkdown, ...content.sections];
        final totalPages = allPages.length;

        return Column(
          children: [
            // Banner image (persistent across pages)
            if (content.bannerImageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  content.bannerImageUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(height: 150),
                ),
              ),

            const SizedBox(height: 16),

            // Page content (swipable)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: totalPages,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SelectionArea(
                      child: GptMarkdown(allPages[index]),
                    ),
                  );
                },
              ),
            ),

            // Page indicator
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalPages, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _currentPage ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: index == _currentPage
                          ? context.colorScheme.primary
                          : context.colorScheme.outline.withOpacity(0.3),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
```

## File Structure

```
lib/features/whats_new/
├── model/
│   ├── whats_new_index.dart          # WhatsNewIndex, WhatsNewRelease
│   ├── whats_new_content.dart        # WhatsNewContent
│   └── whats_new_state.dart          # WhatsNewState
├── repository/
│   └── whats_new_service.dart        # HTTP fetching
├── state/
│   ├── whats_new_controller.dart     # Riverpod controller
│   └── whats_new_controller.g.dart   # Generated
├── util/
│   └── whats_new_markdown_parser.dart
└── ui/
    ├── whats_new_indicator.dart      # Pulsing dot widget
    └── whats_new_modal.dart          # Swipable modal

test/features/whats_new/
├── repository/
│   └── whats_new_service_test.dart
├── state/
│   └── whats_new_controller_test.dart
├── util/
│   └── whats_new_markdown_parser_test.dart
└── ui/
    ├── whats_new_indicator_test.dart
    └── whats_new_modal_test.dart
```

## Implementation Phases

### Phase 1: Data Layer
1. Create model classes with freezed
2. Implement `WhatsNewMarkdownParser`
3. Implement `WhatsNewService` for HTTP fetching
4. Write unit tests for parser and service

### Phase 2: State Management
1. Create `WhatsNewController` Riverpod provider
2. Implement seen/unseen tracking with SharedPreferences
3. Write tests for controller logic

### Phase 3: UI Components
1. Create `WhatsNewIndicator` widget
2. Build `WhatsNewModal` with PageView
3. Integrate with existing settings/about page
4. Widget tests

### Phase 4: Integration
1. Add indicator to appropriate location (e.g., settings page header)
2. Add "What's New" menu item to settings
3. Optionally show modal on first app launch after update
4. End-to-end testing

## Mock Data for Development

For development and testing, create local mock files:

**index.json:**
```json
{
  "releases": [
    {
      "version": "0.9.980",
      "date": "2026-01-07",
      "title": "January Update",
      "folder": "0.9.980"
    }
  ]
}
```

**content.md:**
```markdown
# January Update
*Released: January 7, 2026*

---

## Timeline Visualization

A new video-editor-style timeline helps you navigate your task backlog.

- Histogram shows task density over time
- Drag to select a date range
- Filter tasks by creation date or due date

---

## Improved Entry Actions

The entry action buttons have been redesigned for better accessibility and visual consistency.

---

## Bug Fixes & Improvements

- Fixed calendar view not updating after Riverpod 3 migration
- Improved performance of checklist rendering
- Various sync reliability improvements
```

## Dependencies

- `package:http` - HTTP client (already in pubspec, ^1.2.0)
- `package:gpt_markdown` - Markdown rendering (already in pubspec, ^1.0.20)
- `package:shared_preferences` - Local storage (already in pubspec, ^2.3.2)
- `package:freezed` - Model classes (already in pubspec)
- `package:riverpod` - State management (already in pubspec)

## Success Criteria

1. **Functional**
   - Fetches and displays release notes from remote URL
   - Correctly parses Markdown sections for swipable pages
   - Tracks seen status in local storage
   - Shows indicator only for unseen releases

2. **Performance**
   - Content loads within 3 seconds on typical connection
   - Modal opens smoothly without frame drops
   - Page swiping is fluid at 60fps

3. **Quality**
   - All unit tests pass
   - Widget tests cover key interactions
   - Handles network errors gracefully
   - Works offline (shows cached or no content)

## Future Enhancements

1. **Caching**: Cache fetched content locally to support offline viewing
2. **Push Notifications**: Notify users of new releases via push
3. **Analytics**: Track which sections users view
4. **Rich Media**: Support video embeds and 3D visualizations
5. **Backend Sync**: Sync seen status across devices (requires backend changes)
