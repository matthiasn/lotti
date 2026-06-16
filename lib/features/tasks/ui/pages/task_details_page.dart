import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/mixins/highlight_scroll_mixin.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked_from.dart';
import 'package:lotti/features/journal/ui/widgets/linked_entries_with_timer.dart';
import 'package:lotti/features/tasks/state/task_app_bar_controller.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/features/tasks/ui/task_app_bar.dart';
import 'package:lotti/features/tasks/ui/task_form.dart';
import 'package:lotti/features/tasks/ui/widgets/task_action_bar.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/media_import.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/dev_logger.dart';

/// Full-screen detail view for a single task identified by [taskId].
///
/// Renders a [CustomScrollView] with a sliver app bar, the [TaskForm]
/// (header, AI summary, linked tasks, checklists), and the task's linked
/// entries below. A sticky [TaskActionBar] sits in the `bottomNavigationBar`
/// slot; `extendBody` lets its glass blur read the scrolling body and a
/// trailing [SliverPadding] reserves the bar's height so the last entry can
/// scroll clear of it. Listens to the task focus controller to auto-scroll
/// to a target entry or the AI suggestions, and accepts dropped media via
/// [DropTarget] to link and (optionally) analyze it.
class TaskDetailsPage extends ConsumerStatefulWidget {
  const TaskDetailsPage({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  ConsumerState<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends ConsumerState<TaskDetailsPage>
    with HighlightScrollMixin {
  final _scrollController = ScrollController();
  final void Function() _listener = getIt<UserActivityService>().updateActivity;
  late final void Function() _updateOffsetListener;
  final Map<String, GlobalKey> _entryKeys = {};
  final GlobalKey<State<StatefulWidget>> _suggestionsKey = GlobalKey(
    debugLabel: 'task_suggestions',
  );
  Timer? _suggestionsRetryTimer;

  @override
  void initState() {
    final provider = taskAppBarControllerProvider(id: widget.taskId);
    _updateOffsetListener = () => ref
        .read(provider.notifier)
        .updateOffset(
          _scrollController.offset,
        );

    _scrollController
      ..addListener(_listener)
      ..addListener(_updateOffsetListener);

    super.initState();
  }

  @override
  void dispose() {
    disposeHighlight();
    _suggestionsRetryTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final focusProvider = taskFocusControllerProvider(id: widget.taskId);

    void handleFocus(TaskFocusIntent? intent, {bool isInitialLoad = false}) {
      if (intent == null) return;
      switch (intent.target) {
        case TaskFocusTarget.entry:
          final entryId = intent.entryId;
          if (entryId == null) {
            ref.read(focusProvider.notifier).clearIntent();
            return;
          }
          scrollToEntry(
            entryId,
            intent.alignment,
            getEntryKey: _getEntryKey,
            onScrolled: () => ref.read(focusProvider.notifier).clearIntent(),
            isInitialLoad: isInitialLoad,
          );
        case TaskFocusTarget.suggestions:
          _scrollToSuggestions(
            intent.alignment,
            onScrolled: () => ref.read(focusProvider.notifier).clearIntent(),
            isInitialLoad: isInitialLoad,
          );
      }
    }

    ref.listen<TaskFocusIntent?>(
      focusProvider,
      (previous, next) => handleFocus(next, isInitialLoad: previous == null),
    );

    final provider = entryControllerProvider(id: widget.taskId);
    final asyncTask = ref.watch(provider);
    final task = asyncTask.value?.entry;

    // Only attempt to scroll after task data is loaded
    if (asyncTask.hasValue && task != null && task is Task) {
      // Check for pre-existing intent after task is loaded (navigation from calendar)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final intent = ref.read(focusProvider);
        if (intent != null) {
          handleFocus(intent, isInitialLoad: true);
        }
      });
    }

    if (task == null || task is! Task) {
      return const EmptyScaffoldWithTitle('');
    }

    final scaffold = Scaffold(
      backgroundColor: context.designTokens.colors.background.level01,
      // extendBody so the BackdropFilter inside [TaskActionBar]'s
      // glass strip has body content underneath to actually blur. The
      // body's bottom inset is reserved automatically for the
      // bottomNavigationBar slot, so we don't need a magic-number
      // bottom padding on the slivers.
      extendBody: true,
      // The mobile shell hides its bottom nav bar whenever the
      // current beamer route is `/tasks/<uuid>` (see
      // _AppScreenState._isTaskDetailRoute), so the action bar
      // sits flush with the home indicator. TaskActionBar handles its
      // own bottom safe-inset padding.
      bottomNavigationBar: TaskActionBar(
        task: task,
        topSlot: AiRunningDecoderBars(
          entryId: widget.taskId,
          isInteractive: true,
          responseTypes: const {
            AiResponseType.imageAnalysis,
            AiResponseType.audioTranscription,
            AiResponseType.promptGeneration,
            AiResponseType.imageGeneration,
          },
        ),
      ),
      // Builder so MediaQuery.paddingOf reads the Scaffold-modified
      // value: with extendBody: true, Scaffold adds the
      // bottomNavigationBar slot height (action bar + inline AI activity
      // slot when running) to padding.bottom on the body's MediaQuery. The
      // trailing SliverPadding consumes that inset so the last entry
      // can scroll fully above the bar instead of being hidden behind.
      body: Builder(
        builder: (context) => CustomScrollView(
          controller: _scrollController,
          slivers: [
            TaskSliverAppBar(taskId: widget.taskId),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 15,
                  right: 15,
                  top: 10,
                ),
                child: TaskForm(
                  taskId: widget.taskId,
                  suggestionsFocusKey: _suggestionsKey,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 8,
                  left: 10,
                  right: 10,
                ),
                child:
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        LinkedEntriesWithTimer(
                          item: task,
                          entryKeyBuilder: _getEntryKey,
                          highlightedEntryId: highlightedEntryId,
                          hideTaskEntries: true,
                        ),
                        LinkedFromEntriesWidget(
                          task,
                          hideTaskEntries: true,
                        ),
                      ],
                    ).animate().fadeIn(
                      duration: const Duration(milliseconds: 100),
                    ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );

    // Scope toasts triggered from inside the task details subtree to a
    // nested ScaffoldMessenger so SnackBars float above the sticky
    // [TaskActionBar] (the Scaffold's bottomNavigationBar) instead of the
    // screen / window bottom edge — on mobile the bar would otherwise
    // cover the toast, on desktop it would sit visually detached at the
    // app window's bottom edge.
    final body = ScaffoldMessenger(child: scaffold);

    return DropTarget(
      onDragDone: (data) {
        handleDroppedMedia(
          data: data,
          linkedId: task.meta.id,
          categoryId: task.meta.categoryId,
          analysisTrigger: ref.read(automaticImageAnalysisTriggerProvider),
        );
      },
      child: body,
    );
  }

  void _scrollToSuggestions(
    double alignment, {
    required VoidCallback onScrolled,
    required bool isInitialLoad,
  }) {
    final delay = isInitialLoad
        ? initialScrollDelay
        : const Duration(milliseconds: 100);

    _suggestionsRetryTimer?.cancel();
    _suggestionsRetryTimer = Timer(delay, () {
      _scrollToSuggestionsWithRetry(
        alignment,
        attempt: 0,
        onScrolled: onScrolled,
      );
    });
  }

  void _scrollToSuggestionsWithRetry(
    double alignment, {
    required int attempt,
    required VoidCallback onScrolled,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final context = _suggestionsKey.currentContext;
      if (context != null) {
        try {
          await Scrollable.ensureVisible(
            context,
            alignment: alignment,
            duration: scrollDuration,
            curve: Curves.easeInOut,
          );
        } catch (error) {
          DevLogger.warning(
            name: 'TaskDetailsPage',
            message: 'Failed to scroll to task suggestions: $error',
          );
        } finally {
          _suggestionsRetryTimer?.cancel();
          if (mounted) {
            onScrolled();
          }
        }
        return;
      }

      if (attempt < maxScrollRetries - 1) {
        _suggestionsRetryTimer?.cancel();
        _suggestionsRetryTimer = Timer(scrollRetryDelay, () {
          _scrollToSuggestionsWithRetry(
            alignment,
            attempt: attempt + 1,
            onScrolled: onScrolled,
          );
        });
        return;
      }

      DevLogger.warning(
        name: 'TaskDetailsPage',
        message:
            'Failed to scroll to task suggestions after $maxScrollRetries attempts',
      );
      _suggestionsRetryTimer?.cancel();
      if (mounted) {
        onScrolled();
      }
    });
  }
}
