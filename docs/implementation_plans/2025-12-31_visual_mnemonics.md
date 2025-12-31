# Visual Mnemonics Feature Implementation Plan

## Overview
Add cover art support to tasks, allowing users to designate any linked image as the task's visual mnemonic. This creates more personal, memorable task representations.

## Design Decisions
- Toggle scope: Task list only (detail SliverAppBar always shows cover art if set)
- No cover art behavior: Use minimal app bar (current compact style)
- Menu context: Only show "Assign as cover art" for images linked from a task

## UX Refinements (2025-12-31)
1. **Improved Discoverability**: Add subtle "Set cover" chip in image entry header (not just buried in menu)
2. **Cinematic Cover Art Display**: SliverAppBar expanded height = screen width / 2 (2:1 ultra-wide ratio)
3. **Easy Removal**: Add "Remove cover" chip in task header meta card when cover art is set
4. **Smart Image Composition**: Update image prompt generation to include composition guidance for multi-aspect-ratio cropping (center-weighted "safe zone" for square thumbnails, horizontal margins for cinematic atmosphere)

## Implementation Notes
- **Smart cropping**: Only apply horizontal cropping for wide images (aspect ratio > 1.1). Square or near-square images should be displayed without cropping.
- **Crop calculation**: For wide images, use `coverArtCropX` to determine the horizontal position of the square crop window.

## Future Improvements
- **Custom crop offset UI**: The data model includes `coverArtCropX` (normalized 0.0-1.0, defaulting to 0.5/center). A future UI could allow users to slide the square crop window left/right along the 2:1 image for better framing.

---

## Phase 1: Data Model Updates

### 1.1 Add `coverArtId` to TaskData
**File:** `lib/classes/task.dart`

Add optional fields to TaskData:
```dart
@freezed
abstract class TaskData with _$TaskData {
  const factory TaskData({
    // ... existing fields ...
    String? coverArtId,  // ID of linked JournalImage to use as cover art
    @Default(0.5) double coverArtCropX,  // Horizontal crop offset (0.0=left, 0.5=center, 1.0=right)
  }) = _TaskData;
}
```

**Action:** Run `dart run build_runner build` to regenerate freezed files.

### 1.2 Add persistence method to EntryController
**File:** `lib/features/journal/state/entry_controller.dart`

Add method to update task cover art:
```dart
Future<void> setCoverArt(String? imageId) async {
  final entry = state.value?.entry;
  if (entry is! Task) return;

  final updated = entry.copyWith(
    data: entry.data.copyWith(coverArtId: imageId),
  );
  await _persistenceLogic.updateJournalEntity(updated);
  // Trigger refresh
}
```

---

## Phase 2: Cover Art Assignment UI

### 2.1 Create SetCoverArtChip widget for image entry header
**File:** `lib/features/tasks/ui/set_cover_art_chip.dart` (NEW)

Subtle chip shown in image entry header when image is linked from a task:
```dart
class SetCoverArtChip extends ConsumerWidget {
  const SetCoverArtChip({
    required this.imageId,
    required this.linkedFromId,
    super.key,
  });

  final String imageId;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (linkedFromId == null) return const SizedBox.shrink();

    final parentProvider = entryControllerProvider(id: linkedFromId!);
    final parentEntry = ref.watch(parentProvider).value?.entry;
    if (parentEntry is! Task) return const SizedBox.shrink();

    final isCurrentCover = parentEntry.data.coverArtId == imageId;

    return ActionChip(
      avatar: Icon(
        isCurrentCover ? Icons.image : Icons.image_outlined,
        size: 16,
        color: isCurrentCover ? starredGold : null,
      ),
      label: Text(isCurrentCover ? 'Cover' : 'Set cover'),
      onPressed: () async {
        final notifier = ref.read(parentProvider.notifier);
        await notifier.setCoverArt(isCurrentCover ? null : imageId);
      },
    );
  }
}
```

### 2.2 Add chip to EntryDetailHeader
**File:** `lib/features/journal/ui/widgets/entry_details/header/entry_detail_header.dart`

Add SetCoverArtChip for JournalImage entries with linkedFromId.

### 2.3 Create RemoveCoverArtChip for task header
**File:** `lib/features/tasks/ui/remove_cover_art_chip.dart` (NEW)

Chip shown in TaskHeaderMetaCard when cover art is set:
```dart
class RemoveCoverArtChip extends ConsumerWidget {
  const RemoveCoverArtChip({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: taskId);
    final entry = ref.watch(provider).value?.entry;
    if (entry is! Task || entry.data.coverArtId == null) {
      return const SizedBox.shrink();
    }

    return ActionChip(
      avatar: const Icon(Icons.image, size: 16),
      label: const Text('Cover'),
      onPressed: () async {
        final notifier = ref.read(provider.notifier);
        await notifier.setCoverArt(null);
      },
    );
  }
}
```

### 2.4 Add chip to TaskHeaderMetaCard
**File:** `lib/features/tasks/ui/header/task_header_meta_card.dart`

Add RemoveCoverArtChip to the Wrap in _TaskMetadataRow.

### 2.5 Create ModernAssignCoverArtItem widget (menu fallback)
**File:** `lib/features/journal/ui/widgets/entry_details/header/modern_action_items.dart`

Add new action item following the pattern of `ModernCopyImageItem`:
```dart
class ModernAssignCoverArtItem extends ConsumerWidget {
  const ModernAssignCoverArtItem({
    required this.entryId,
    required this.linkedFromId,
    super.key,
  });

  final String entryId;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show for JournalImage entries when linkedFromId is a Task
    final provider = entryControllerProvider(id: entryId);
    final entry = ref.watch(provider).value?.entry;

    if (entry is! JournalImage || linkedFromId == null) {
      return const SizedBox.shrink();
    }

    // Verify linkedFromId is a Task
    final parentProvider = entryControllerProvider(id: linkedFromId);
    final parentEntry = ref.watch(parentProvider).value?.entry;
    if (parentEntry is! Task) return const SizedBox.shrink();

    final isCurrentCover = parentEntry.data.coverArtId == entryId;

    return ModernModalActionItem(
      icon: isCurrentCover ? Icons.image : Icons.image_outlined,
      iconColor: isCurrentCover ? starredGold : null,
      title: isCurrentCover
          ? context.messages.coverArtRemove
          : context.messages.coverArtAssign,
      onTap: () async {
        final notifier = ref.read(parentProvider.notifier);
        await notifier.setCoverArt(isCurrentCover ? null : entryId);
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }
}
```

### 2.2 Add menu item to InitialModalPageContent
**File:** `lib/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart`

Add after `ModernCopyImageItem`:
```dart
ModernAssignCoverArtItem(
  entryId: entryId,
  linkedFromId: linkedFromId,
),
```

### 2.3 Add localization strings
**File:** `lib/l10n/app_en.arb`

Add:
```json
"coverArtAssign": "Set as cover art",
"coverArtRemove": "Remove as cover art",
"tasksShowCoverArt": "Show cover art on cards"
```

---

## Phase 3: Task List Display with Cover Art

### 3.1 Update ModernTaskCard with thumbnail
**File:** `lib/features/journal/ui/widgets/list_cards/modern_task_card.dart`

Modify to accept `showCoverArt` parameter and display thumbnail:
```dart
class ModernTaskCard extends StatelessWidget {
  const ModernTaskCard({
    required this.task,
    this.showCreationDate = false,
    this.showDueDate = true,
    this.showCoverArt = true,  // NEW
    super.key,
  });

  final Task task;
  final bool showCreationDate;
  final bool showDueDate;
  final bool showCoverArt;  // NEW
```

In build method, wrap content with Row when cover art is available:
```dart
@override
Widget build(BuildContext context) {
  final coverArtId = task.data.coverArtId;
  final hasCoverArt = showCoverArt && coverArtId != null;

  return ModernBaseCard(
    // ...
    child: hasCoverArt
        ? _buildWithCoverArt(context, coverArtId)
        : _buildStandardContent(context),
  );
}

Widget _buildWithCoverArt(BuildContext context, String coverArtId) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 80x80 thumbnail
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 80,
          height: 80,
          child: CoverArtThumbnail(imageId: coverArtId),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _buildStandardContent(context),
      ),
    ],
  );
}
```

### 3.2 Create CoverArtThumbnail widget
**File:** `lib/features/tasks/ui/cover_art_thumbnail.dart` (NEW)

```dart
class CoverArtThumbnail extends ConsumerWidget {
  const CoverArtThumbnail({
    required this.imageId,
    this.size = 80,
    super.key,
  });

  final String imageId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: imageId);
    final entry = ref.watch(provider).value?.entry;

    if (entry is! JournalImage) {
      return SizedBox(width: size, height: size);
    }

    return CardImageWidget(
      journalImage: entry,
      height: size,
      width: size,
      fit: BoxFit.cover,
    );
  }
}
```

### 3.3 Update task list to pass showCoverArt
**File:** `lib/features/journal/ui/widgets/list_cards/card_wrapper_widget.dart`

Pass `showCoverArt` from controller state to ModernTaskCard.

---

## Phase 4: SliverAppBar with Cover Art

### 4.1 Modify TaskSliverAppBar for collapsing behavior
**File:** `lib/features/tasks/ui/task_app_bar.dart`

Replace simple SliverAppBar with expandable version when cover art exists:
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final provider = entryControllerProvider(id: taskId);
  final item = ref.watch(provider).value?.entry;

  if (item == null || item is! Task) {
    return JournalSliverAppBar(entryId: taskId);
  }

  final coverArtId = item.data.coverArtId;

  // If no cover art, use current compact app bar
  if (coverArtId == null) {
    return _buildCompactAppBar(context, item);
  }

  // Expandable app bar with cover art
  return _buildExpandableAppBar(context, ref, item, coverArtId);
}

Widget _buildExpandableAppBar(
  BuildContext context,
  WidgetRef ref,
  Task task,
  String coverArtId,
) {
  // 2:1 cinematic ultra-wide ratio
  final expandedHeight = MediaQuery.of(context).size.width / 2;

  return SliverAppBar(
    expandedHeight: expandedHeight,
    pinned: true,
    leadingWidth: 100,
    titleSpacing: 0,
    toolbarHeight: 45,
    scrolledUnderElevation: 0,
    elevation: 10,
    leading: const BackWidget(),
    actions: [
      UnifiedAiPopUpMenu(journalEntity: task, linkedFromId: null),
      IconButton(
        icon: Icon(Icons.more_horiz, color: context.colorScheme.outline),
        onPressed: () => ExtendedHeaderModal.show(...),
      ),
      const SizedBox(width: 10),
    ],
    flexibleSpace: FlexibleSpaceBar(
      background: CoverArtBackground(imageId: coverArtId),
      collapseMode: CollapseMode.parallax,
    ),
    automaticallyImplyLeading: false,
  );
}
```

### 4.2 Create CoverArtBackground widget
**File:** `lib/features/tasks/ui/cover_art_background.dart` (NEW)

Full-bleed image with gradient overlay for readability:
```dart
class CoverArtBackground extends ConsumerWidget {
  const CoverArtBackground({
    required this.imageId,
    super.key,
  });

  final String imageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: imageId);
    final entry = ref.watch(provider).value?.entry;

    if (entry is! JournalImage) {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CardImageWidget(
          journalImage: entry,
          fit: BoxFit.cover,
        ),
        // Gradient overlay for toolbar readability
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                Colors.black.withValues(alpha: 0.6),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

---

## Phase 5: Filter Toggle

### 5.1 Add showCoverArt to state
**File:** `lib/features/journal/state/journal_page_state.dart`

Add to JournalPageState:
```dart
@Default(true) bool showCoverArt,
```

Add to TasksFilter:
```dart
@Default(true) bool showCoverArt,
```

### 5.2 Add controller method
**File:** `lib/features/journal/state/journal_page_controller.dart`

Add field and method:
```dart
bool _showCoverArt = true;

void setShowCoverArt({required bool show}) {
  _showCoverArt = show;
  state = state.copyWith(showCoverArt: show);
  _persistTasksFilterWithoutRefresh();
}
```

### 5.3 Create TaskCoverArtDisplayToggle widget
**File:** `lib/features/tasks/ui/filtering/task_cover_art_display_toggle.dart` (NEW)

Follow the pattern of TaskDueDateDisplayToggle:
```dart
class TaskCoverArtDisplayToggle extends ConsumerWidget {
  const TaskCoverArtDisplayToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller = ref.read(journalPageControllerProvider(showTasks).notifier);

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          context.messages.tasksShowCoverArt,
          style: context.textTheme.bodySmall,
        ),
        value: state.showCoverArt,
        onChanged: (value) {
          controller.setShowCoverArt(show: value);
          HapticFeedback.selectionClick();
        },
      ),
    );
  }
}
```

### 5.4 Add toggle to filter content
**File:** `lib/features/tasks/ui/filtering/task_filter_content.dart`

Add after `TaskDueDateDisplayToggle`:
```dart
const TaskCoverArtDisplayToggle(),
```

---

## Phase 6: Image Prompt Composition Guidance

### 6.1 Update imagePromptGenerationPrompt
**File:** `lib/features/ai/util/preconfigured_prompts.dart`

Add to IMPORTANT GUIDELINES section (around line 631):
```
COMPOSITION FOR MULTI-ASPECT-RATIO CROPPING:
- Compose in wide cinematic format (2:1 or 16:9 aspect ratio)
- Center the primary subject within the middle square region of the frame
- This "safe zone" ensures the key visual remains visible when cropped to a square thumbnail
- Use the horizontal margins for atmospheric context, environmental detail, and cinematic framing
- Think of it like broadcast "title safe" zones: critical content in the center, expandable atmosphere on the sides
```

Add to PROMPT STRUCTURE GUIDELINES after "Technical" (around line 606):
```
7. **Composition**: Primary subject centered in a square "safe zone" for thumbnail cropping, with horizontal margins for cinematic atmosphere
```

---

## Phase 7: Testing

### 6.1 Unit tests for TaskData coverArtId
- Test serialization/deserialization with coverArtId
- Test copyWith behavior

### 6.2 Widget tests for ModernTaskCard
- Test card renders without cover art
- Test card renders with cover art thumbnail
- Test showCoverArt=false hides thumbnail

### 6.3 Widget tests for cover art menu item
- Test menu item appears only for images linked from tasks
- Test setting/unsetting cover art

### 6.4 Widget tests for SliverAppBar
- Test compact app bar when no cover art
- Test expandable app bar when cover art set
- Test collapse behavior

---

## Files to Create
1. `lib/features/tasks/ui/cover_art_thumbnail.dart` - Reusable thumbnail widget
2. `lib/features/tasks/ui/cover_art_background.dart` - SliverAppBar background
3. `lib/features/tasks/ui/set_cover_art_chip.dart` - Chip for image entry header
4. `lib/features/tasks/ui/remove_cover_art_chip.dart` - Chip for task header meta card
5. `lib/features/tasks/ui/filtering/task_cover_art_display_toggle.dart` - Filter toggle

## Files to Modify
1. `lib/classes/task.dart` - Add coverArtId field
2. `lib/features/journal/state/entry_controller.dart` - Add setCoverArt method
3. `lib/features/journal/ui/widgets/entry_details/header/entry_detail_header.dart` - Add SetCoverArtChip
4. `lib/features/tasks/ui/header/task_header_meta_card.dart` - Add RemoveCoverArtChip
5. `lib/features/journal/ui/widgets/entry_details/header/modern_action_items.dart` - Add ModernAssignCoverArtItem
6. `lib/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart` - Add menu item
7. `lib/features/journal/ui/widgets/list_cards/modern_task_card.dart` - Add thumbnail display
8. `lib/features/journal/ui/widgets/list_cards/card_wrapper_widget.dart` - Pass showCoverArt
9. `lib/features/tasks/ui/task_app_bar.dart` - Add expandable SliverAppBar (2:1 ratio)
10. `lib/features/journal/state/journal_page_state.dart` - Add showCoverArt field
11. `lib/features/journal/state/journal_page_controller.dart` - Add setShowCoverArt method
12. `lib/features/tasks/ui/filtering/task_filter_content.dart` - Add toggle
13. `lib/features/ai/util/preconfigured_prompts.dart` - Add composition guidance
14. `lib/l10n/app_en.arb` - Add localization strings

## Execution Order
1. Phase 1 (Data Model) - Foundation, must come first
2. Run `fvm dart run build_runner build`
3. Phase 2 (Cover Art UI) - Chips for set/remove cover art
4. Phase 3 (Task List Display) - Shows thumbnails
5. Phase 4 (SliverAppBar) - Detail view enhancement (2:1 cinematic ratio)
6. Phase 5 (Filter Toggle) - User control
7. Phase 6 (Image Prompt) - Composition guidance for generated images
8. Phase 7 (Testing) - Verify all works
9. Run analyzer, format, and tests before completion
