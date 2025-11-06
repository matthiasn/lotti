import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/journal_focus_controller.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_button.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked_from.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/features/journal/ui/widgets/journal_app_bar.dart';
import 'package:lotti/features/tasks/state/task_app_bar_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/linked_from_checklist_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/linked_from_task_widget.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/pages/empty_scaffold.dart';

class EntryDetailsPage extends ConsumerStatefulWidget {
  const EntryDetailsPage({
    required this.itemId,
    super.key,
  });

  final String itemId;

  @override
  ConsumerState<EntryDetailsPage> createState() => _EntryDetailsPageState();
}

class _EntryDetailsPageState extends ConsumerState<EntryDetailsPage> {
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _entryKeys = {};

  @override
  void initState() {
    final listener = getIt<UserActivityService>().updateActivity;
    final provider = taskAppBarControllerProvider(id: widget.itemId);

    _scrollController
      ..addListener(listener)
      ..addListener(
        () => ref.read(provider.notifier).updateOffset(
              _scrollController.offset,
            ),
      );

    super.initState();
  }

  GlobalKey _getEntryKey(String entryId) {
    return _entryKeys.putIfAbsent(
      entryId,
      () => GlobalKey<State>(debugLabel: 'entry_$entryId'),
    );
  }

  void _scrollToEntry(
    String entryId,
    double alignment, {
    VoidCallback? onScrolled,
  }) {
    // Schedule scroll after frame is built
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      final key = _getEntryKey(entryId);
      final context = key.currentContext;

      if (context != null) {
        try {
          await Scrollable.ensureVisible(
            context,
            alignment: alignment,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          onScrolled?.call();
        } catch (e) {
          // Log error if scrolling fails
          debugPrint('Failed to scroll to entry $entryId: $e');
          onScrolled?.call();
        }
      } else {
        // Entry not found or not yet rendered
        debugPrint(
          'Entry $entryId not found in widget tree, skipping scroll',
        );
        onScrolled?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final focusProvider = journalFocusControllerProvider(id: widget.itemId);

    void handleFocus(JournalFocusIntent? intent) {
      if (intent == null) return;
      _scrollToEntry(
        intent.entryId,
        intent.alignment,
        onScrolled: () => ref.read(focusProvider.notifier).clearIntent(),
      );
    }

    ref.listen<JournalFocusIntent?>(
        focusProvider, (_, next) => handleFocus(next));

    // Check for pre-existing intent on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      handleFocus(ref.read(focusProvider));
    });

    final provider = entryControllerProvider(id: widget.itemId);
    final item = ref.watch(provider).value?.entry;

    if (item == null) {
      return const EmptyScaffoldWithTitle('');
    }

    return DropTarget(
      onDragDone: (data) {
        handleDroppedMedia(
          data: data,
          linkedId: item.meta.id,
          categoryId: item.meta.categoryId,
        );
      },
      child: Scaffold(
        floatingActionButton: FloatingAddActionButton(
          linkedFromId: item.meta.id,
          categoryId: item.meta.categoryId,
        ),
        body: Stack(
          children: [
            CustomScrollView(
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        EntryDetailsWidget(
                          itemId: widget.itemId,
                          showTaskDetails: true,
                          showAiEntry: true,
                        ),
                        LinkedEntriesWidget(
                          item,
                          entryKeyBuilder: _getEntryKey,
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
                  AiResponseType.taskSummary,
                  AiResponseType.imageAnalysis,
                  AiResponseType.audioTranscription,
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
