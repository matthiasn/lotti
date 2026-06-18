import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/journal_focus_controller.dart';
import 'package:lotti/features/journal/ui/mixins/highlight_scroll_mixin.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_button.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked_from.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/features/journal/ui/widgets/journal_app_bar.dart';
import 'package:lotti/features/journal/ui/widgets/linked_entries_with_timer.dart';
import 'package:lotti/features/tasks/state/task_app_bar_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/linked_from_checklist_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/linked_from_task_widget.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/media_import.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/widgets/media/media_drop_target.dart';

/// Full-screen detail view for a single journal entry, keyed by `itemId`.
///
/// Composes the scrollable detail stack: the primary [EntryDetailsWidget],
/// the entry's outgoing links via [LinkedEntriesWithTimer], incoming links via
/// [LinkedFromEntriesWidget], and checklist/task back-references. Acts as a
/// [MediaDropTarget] so dropped media is imported and linked to this entry.
///
/// Uses [HighlightScrollMixin] to scroll-to and briefly highlight a target
/// entry: it listens to [journalFocusControllerProvider] for focus intents
/// (e.g. navigation from the calendar or a freshly created timer) and resolves
/// each linked entry's [GlobalKey] through `_getEntryKey`. Scroll offset is
/// also forwarded to the task app bar controller and the user-activity service.
class EntryDetailsPage extends ConsumerStatefulWidget {
  const EntryDetailsPage({
    required this.itemId,
    super.key,
  });

  final String itemId;

  @override
  ConsumerState<EntryDetailsPage> createState() => _EntryDetailsPageState();
}

class _EntryDetailsPageState extends ConsumerState<EntryDetailsPage>
    with HighlightScrollMixin {
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _entryKeys = {};

  @override
  void initState() {
    final listener = getIt<UserActivityService>().updateActivity;
    final provider = taskAppBarControllerProvider(id: widget.itemId);

    _scrollController
      ..addListener(listener)
      ..addListener(
        () => ref
            .read(provider.notifier)
            .updateOffset(
              _scrollController.offset,
            ),
      );

    super.initState();
  }

  @override
  void dispose() {
    disposeHighlight();
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _getEntryKey(String entryId) {
    return _entryKeys.putIfAbsent(
      entryId,
      () => GlobalKey<State>(debugLabel: 'entry_$entryId'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final focusProvider = journalFocusControllerProvider(id: widget.itemId);

    void handleFocus(JournalFocusIntent? intent, {bool isInitialLoad = false}) {
      if (intent == null) return;
      scrollToEntry(
        intent.entryId,
        intent.alignment,
        getEntryKey: _getEntryKey,
        onScrolled: () => ref.read(focusProvider.notifier).clearIntent(),
        isInitialLoad: isInitialLoad,
      );
    }

    ref.listen<JournalFocusIntent?>(
      focusProvider,
      (_, next) => handleFocus(next),
    );

    final provider = entryControllerProvider(id: widget.itemId);
    final asyncItem = ref.watch(provider);
    final item = asyncItem.value?.entry;

    // Only attempt to scroll after entry data is loaded
    if (asyncItem.hasValue && item != null) {
      // Check for pre-existing intent after data is loaded (navigation from calendar)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final intent = ref.read(focusProvider);
        if (intent != null) {
          handleFocus(intent, isInitialLoad: true);
        }
      });
    }

    if (item == null) {
      return const EmptyScaffoldWithTitle('');
    }

    return MediaDropTarget(
      onFiles: (files) => handleDroppedMediaFiles(
        files,
        linkedId: item.meta.id,
        categoryId: item.meta.categoryId,
        analysisTrigger: ref.read(automaticImageAnalysisTriggerProvider),
      ),
      child: Scaffold(
        floatingActionButton: FloatingAddActionButton(
          linkedFromId: item.meta.id,
          categoryId: item.meta.categoryId,
        ),
        body: Stack(
          children: [
            CustomScrollView(
              scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
              controller: _scrollController,
              slivers: [
                JournalSliverAppBar(entryId: widget.itemId),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 8,
                      bottom: 200,
                      left: 5,
                      right: 5,
                    ),
                    child:
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            EntryDetailsWidget(
                              itemId: widget.itemId,
                              showTaskDetails: true,
                              showAiEntry: true,
                            ),
                            LinkedEntriesWithTimer(
                              item: item,
                              entryKeyBuilder: _getEntryKey,
                              highlightedEntryId: highlightedEntryId,
                            ),
                            LinkedFromEntriesWidget(item),
                            if (item is ChecklistItem)
                              LinkedFromChecklistWidget(item),
                            if (item is Checklist) LinkedFromTaskWidget(item),
                          ],
                        ).animate().fadeIn(
                          duration: const Duration(
                            milliseconds: 100,
                          ),
                        ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: AiRunningAnimationWrapperCard(
                entryId: widget.itemId,
                height: 50,
                isInteractive: true,
                responseTypes: const {
                  AiResponseType.imageAnalysis,
                  AiResponseType.audioTranscription,
                  AiResponseType.promptGeneration,
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
