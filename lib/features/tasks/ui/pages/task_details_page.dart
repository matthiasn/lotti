import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_button.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked_from.dart';
import 'package:lotti/features/tasks/state/task_app_bar_controller.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_title_header.dart';
import 'package:lotti/features/tasks/ui/task_app_bar.dart';
import 'package:lotti/features/tasks/ui/task_form.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/pages/empty_scaffold.dart';

class TaskDetailsPage extends ConsumerStatefulWidget {
  const TaskDetailsPage({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  ConsumerState<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends ConsumerState<TaskDetailsPage> {
  final _scrollController = ScrollController();
  final void Function() _listener = getIt<UserActivityService>().updateActivity;
  late final void Function() _updateOffsetListener;
  final Map<String, GlobalKey> _entryKeys = {};

  @override
  void initState() {
    final provider = taskAppBarControllerProvider(id: widget.taskId);
    _updateOffsetListener = () => ref.read(provider.notifier).updateOffset(
          _scrollController.offset,
        );

    _scrollController
      ..addListener(_listener)
      ..addListener(_updateOffsetListener);

    super.initState();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_listener)
      ..removeListener(_updateOffsetListener)
      ..dispose();
    super.dispose();
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
        }
      } else {
        // Entry not found or not yet rendered
        debugPrint(
          'Entry $entryId not found in widget tree, skipping scroll',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final focusProvider = taskFocusControllerProvider(id: widget.taskId);

    void handleFocus(TaskFocusIntent? intent) {
      if (intent == null) return;
      _scrollToEntry(
        intent.entryId,
        intent.alignment,
        onScrolled: () => ref.read(focusProvider.notifier).clearIntent(),
      );
    }

    ref.listen<TaskFocusIntent?>(focusProvider, (_, next) => handleFocus(next));

    // Check for pre-existing intent on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      handleFocus(ref.read(focusProvider));
    });

    final provider = entryControllerProvider(id: widget.taskId);
    final task = ref.watch(provider).value?.entry;

    if (task == null || task is! Task) {
      return const EmptyScaffoldWithTitle('');
    }

    return DropTarget(
      onDragDone: (data) {
        handleDroppedMedia(
          data: data,
          linkedId: task.meta.id,
          categoryId: task.meta.categoryId,
        );
      },
      child: Scaffold(
        floatingActionButton: FloatingAddActionButton(
          linkedFromId: task.meta.id,
          categoryId: task.meta.categoryId,
        ),
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                TaskSliverAppBar(taskId: widget.taskId),
                PinnedHeaderSliver(
                  child: TaskTitleHeader(taskId: widget.taskId),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 15,
                      right: 15,
                      top: 10,
                    ),
                    child: TaskForm(taskId: widget.taskId),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 8,
                      bottom: 200,
                      left: 10,
                      right: 10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        LinkedEntriesWidget(
                          task,
                          entryKeyBuilder: _getEntryKey,
                        ),
                        LinkedFromEntriesWidget(task),
                      ],
                    ).animate().fadeIn(
                          duration: const Duration(milliseconds: 100),
                        ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: AiRunningAnimationWrapperCard(
                entryId: widget.taskId,
                height: 50,
                isInteractive: true,
                responseTypes: const {
                  AiResponseType.taskSummary,
                  AiResponseType.checklistUpdates,
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
