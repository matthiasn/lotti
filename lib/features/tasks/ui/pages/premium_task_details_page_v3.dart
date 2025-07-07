import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_button.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked_from.dart';
import 'package:lotti/features/tasks/state/task_app_bar_controller.dart';
import 'package:lotti/features/tasks/ui/task_app_bar.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_ai_summary_section.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_checklists_section.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class PremiumTaskDetailsPageV3 extends ConsumerStatefulWidget {
  const PremiumTaskDetailsPageV3({
    required this.taskId,
    super.key,
    this.readOnly = false,
  });

  final String taskId;
  final bool readOnly;

  @override
  ConsumerState<PremiumTaskDetailsPageV3> createState() =>
      _PremiumTaskDetailsPageV3State();
}

class _PremiumTaskDetailsPageV3State
    extends ConsumerState<PremiumTaskDetailsPageV3> {
  final _scrollController = ScrollController();
  final void Function() _listener = getIt<UserActivityService>().updateActivity;
  late final void Function() _updateOffsetListener;

  @override
  void initState() {
    final provider = taskAppBarControllerProvider(id: widget.taskId);
    _updateOffsetListener = () {
      ref.read(provider.notifier).updateOffset(_scrollController.offset);
    };

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

              // Task Header - Pinned when scrolling
              SliverPersistentHeader(
                pinned: true,
                delegate: _TaskHeaderDelegate(
                  task: task,
                  minHeight: 60,
                  maxHeight: 200,
                ),
              ),

              // AI Summary - Pinned when scrolling
              SliverPersistentHeader(
                pinned: true,
                delegate: _AiSummaryDelegate(
                  taskId: widget.taskId,
                  minHeight: 60,
                  maxHeight: 300,
                ),
              ),

              // Checklists - Pinned when scrolling
              SliverPersistentHeader(
                pinned: true,
                delegate: _ChecklistsDelegate(
                  task: task,
                  minHeight: 60,
                  maxHeight: 400,
                ),
              ),

              // Linked entries (not pinned, scrolls normally)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(MdiIcons.link, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Linked Entries',
                            style: context.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinkedEntriesWidget(task),
                      LinkedFromEntriesWidget(task),
                    ],
                  ),
                ),
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 200),
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

// Task Header Delegate
class _TaskHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TaskHeaderDelegate({
    required this.task,
    required this.minHeight,
    required this.maxHeight,
  });

  final Task task;
  final double minHeight;
  final double maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final shrinkRatio = shrinkOffset / (maxExtent - minExtent);
    final isCollapsed = shrinkRatio > 0.5;

    return Material(
      color: context.colorScheme.surface,
      elevation: overlapsContent ? 2 : 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isCollapsed
              ? _buildCollapsedHeader(context)
              : _buildExpandedHeader(context, shrinkRatio),
        ),
      ),
    );
  }

  Widget _buildCollapsedHeader(BuildContext context) {
    final statusColor = _getStatusColor();

    return SizedBox(
      height: minExtent - 32, // Account for padding
      child: Row(
        children: [
          Expanded(
            child: Text(
              task.data.title,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getStatusText(),
              style: context.textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedHeader(BuildContext context, double shrinkRatio) {
    return Opacity(
      opacity: 1 - shrinkRatio,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.data.title,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          // Status, estimate, category
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildChip(
                context,
                icon: MdiIcons.circle,
                label: _getStatusText(),
                color: _getStatusColor(),
              ),
              if (task.data.estimate != null)
                _buildChip(
                  context,
                  icon: MdiIcons.clockOutline,
                  label: '${task.data.estimate} min',
                ),
              if (task.meta.categoryId != null)
                _buildChip(
                  context,
                  icon: MdiIcons.folderOutline,
                  label: 'Work', // TODO: Get actual category
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: context.textTheme.labelMedium,
                  ),
                  Text(
                    '0%', // TODO: Get from TaskProgressController
                    style: context.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0, // TODO: Get from TaskProgressController
                  minHeight: 8,
                  backgroundColor: context.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? context.colorScheme.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (color ?? context.colorScheme.primary).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color ?? context.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              color: color ?? context.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText() => task.data.status.map(
        open: (_) => 'Open',
        inProgress: (_) => 'In Progress',
        groomed: (_) => 'Groomed',
        blocked: (_) => 'Blocked',
        onHold: (_) => 'On Hold',
        done: (_) => 'Complete',
        rejected: (_) => 'Rejected',
      );

  Color _getStatusColor() => task.data.status.map(
        open: (_) => Colors.blue,
        inProgress: (_) => Colors.blue,
        groomed: (_) => Colors.orange,
        blocked: (_) => Colors.red,
        onHold: (_) => Colors.amber,
        done: (_) => Colors.green,
        rejected: (_) => Colors.red.shade900,
      );

  @override
  bool shouldRebuild(covariant _TaskHeaderDelegate oldDelegate) {
    return task != oldDelegate.task;
  }
}

// AI Summary Delegate
class _AiSummaryDelegate extends SliverPersistentHeaderDelegate {
  _AiSummaryDelegate({
    required this.taskId,
    required this.minHeight,
    required this.maxHeight,
  });

  final String taskId;
  final double minHeight;
  final double maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final shrinkRatio = shrinkOffset / (maxExtent - minExtent);
    final isCollapsed = shrinkRatio > 0.5;

    return Material(
      color: context.colorScheme.surface,
      elevation: overlapsContent ? 2 : 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    MdiIcons.robotOutline,
                    size: 20,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI Task Summary',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (!isCollapsed) ...[
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: CollapsibleAiSummarySection(
                      taskId: taskId,
                      scrollController: ScrollController(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _AiSummaryDelegate oldDelegate) {
    return taskId != oldDelegate.taskId;
  }
}

// Checklists Delegate
class _ChecklistsDelegate extends SliverPersistentHeaderDelegate {
  _ChecklistsDelegate({
    required this.task,
    required this.minHeight,
    required this.maxHeight,
  });

  final Task task;
  final double minHeight;
  final double maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final shrinkRatio = shrinkOffset / (maxExtent - minExtent);
    final isCollapsed = shrinkRatio > 0.5;
    final totalItems = task.data.checklistIds?.length ?? 0;
    const completedItems = 0; // TODO: Calculate actual completed items

    return Material(
      color: context.colorScheme.surface,
      elevation: overlapsContent ? 2 : 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    MdiIcons.checkboxMultipleOutline,
                    size: 20,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Checklists',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$completedItems/$totalItems',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (!isCollapsed) ...[
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: CollapsibleChecklistsSection(
                      task: task,
                      scrollController: ScrollController(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ChecklistsDelegate oldDelegate) {
    return task != oldDelegate.task;
  }
}
