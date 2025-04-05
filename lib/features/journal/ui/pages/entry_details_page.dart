import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_button.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked_from.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/features/tasks/state/task_app_bar_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/linked_from_checklist_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/linked_from_task_widget.dart';
import 'package:lotti/features/tasks/ui/task_app_bar.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/pages/empty_scaffold.dart';

class EntryDetailPage extends ConsumerStatefulWidget {
  const EntryDetailPage({
    required this.itemId,
    super.key,
    this.readOnly = false,
  });

  final String itemId;
  final bool readOnly;

  @override
  ConsumerState<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends ConsumerState<EntryDetailPage> {
  final _scrollController = ScrollController();

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

  @override
  Widget build(BuildContext context) {
    final provider = entryControllerProvider(id: widget.itemId);
    final item = ref.watch(provider).value?.entry;

    if (item == null) {
      return const EmptyScaffoldWithTitle('');
    }

    return DropTarget(
      onDragDone: (data) {
        importDroppedImages(
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
                TaskSliverAppBar(entryId: widget.itemId),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: 200,
                      left: 5,
                      right: 5,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        EntryDetailsWidget(
                          itemId: widget.itemId,
                          popOnDelete: true,
                          showTaskDetails: true,
                          showAiEntry: true,
                        ),
                        LinkedEntriesWidget(item),
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
            if (item is Task)
              Align(
                alignment: Alignment.bottomCenter,
                child: AiRunningAnimationWrapperCard(
                  entryId: widget.itemId,
                  height: 50,
                  responseTypes: const {
                    taskSummary,
                    actionItemSuggestions,
                    imageAnalysis,
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
