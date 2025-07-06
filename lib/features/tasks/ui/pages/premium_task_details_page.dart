import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_button.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked_from.dart';
import 'package:lotti/features/tasks/state/task_app_bar_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_title_header.dart';
import 'package:lotti/features/tasks/ui/task_app_bar.dart';
import 'package:lotti/features/tasks/ui/task_form.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_ai_summary_section.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_checklists_section.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_linked_entries_section.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/empty_scaffold.dart';

class PremiumTaskDetailsPage extends ConsumerStatefulWidget {
  const PremiumTaskDetailsPage({
    required this.taskId,
    super.key,
    this.readOnly = false,
  });

  final String taskId;
  final bool readOnly;

  @override
  ConsumerState<PremiumTaskDetailsPage> createState() =>
      _PremiumTaskDetailsPageState();
}

class _PremiumTaskDetailsPageState
    extends ConsumerState<PremiumTaskDetailsPage> {
  final _scrollController = ScrollController();
  final void Function() _listener = getIt<UserActivityService>().updateActivity;
  late final void Function() _updateOffsetListener;

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

  @override
  Widget build(BuildContext context) {
    final provider = entryControllerProvider(id: widget.taskId);
    final item = ref.watch(provider).value?.entry;

    final task = item is Task ? item : null;

    if (task == null) {
      return EmptyScaffoldWithTitle(widget.taskId);
    }

    return Scaffold(
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
              SliverList(
                delegate: SliverChildListDelegate([
                  // Main Task Form (status, dates, etc.)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TaskForm(taskId: widget.taskId),
                  ),
                  // AI Summary Section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: CollapsibleAiSummarySection(
                      taskId: widget.taskId,
                      scrollController: _scrollController,
                    ),
                  ),
                  // Checklists Section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: CollapsibleChecklistsSection(
                      task: task,
                      scrollController: _scrollController,
                    ),
                  ),
                  // Linked Entries Section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: CollapsibleLinkedEntriesSection(
                      task: task,
                      scrollController: _scrollController,
                    ),
                  ),
                  // Linked From Entries (tasks/entries that link to this task)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: LinkedFromEntriesWidget(task),
                  ),
                  // Bottom padding for floating action button
                  const SizedBox(height: 200),
                ]),
              ),
            ],
          ),
          // AI Running Animation at the bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: AiRunningAnimationWrapperCard(
              entryId: widget.taskId,
              height: 50,
              responseTypes: const {
                AiResponseType.taskSummary,
                AiResponseType.actionItemSuggestions,
                AiResponseType.imageAnalysis,
                AiResponseType.audioTranscription,
              },
            ),
          ),
        ],
      ),
    );
  }
}
