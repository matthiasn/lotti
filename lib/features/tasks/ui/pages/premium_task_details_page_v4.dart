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
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/task_app_bar.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_ai_summary_section.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_checklists_section.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class PremiumTaskDetailsPageV4 extends ConsumerStatefulWidget {
  const PremiumTaskDetailsPageV4({
    required this.taskId,
    super.key,
    this.readOnly = false,
  });

  final String taskId;
  final bool readOnly;

  @override
  ConsumerState<PremiumTaskDetailsPageV4> createState() =>
      _PremiumTaskDetailsPageV4State();
}

class _PremiumTaskDetailsPageV4State
    extends ConsumerState<PremiumTaskDetailsPageV4> {
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

              // Task Header - Sticky
              SliverPersistentHeader(
                pinned: true,
                delegate: _SimpleStickyDelegate(
                  minHeight: 60,
                  maxHeight: 60,
                  child: _CollapsedTaskHeader(task: task),
                ),
              ),

              // Expanded Task Header Content
              SliverToBoxAdapter(
                child: _ExpandedTaskHeader(task: task),
              ),

              // AI Summary - Sticky
              SliverPersistentHeader(
                pinned: true,
                delegate: _SimpleStickyDelegate(
                  minHeight: 60,
                  maxHeight: 60,
                  child: _CollapsedSection(
                    icon: MdiIcons.robotOutline,
                    title: 'AI Task Summary',
                  ),
                ),
              ),

              // Expanded AI Summary Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CollapsibleAiSummarySection(
                    taskId: widget.taskId,
                    scrollController: ScrollController(),
                  ),
                ),
              ),

              // Checklists - Sticky
              SliverPersistentHeader(
                pinned: true,
                delegate: _SimpleStickyDelegate(
                  minHeight: 60,
                  maxHeight: 60,
                  child: _CollapsedChecklistsHeader(task: task),
                ),
              ),

              // Expanded Checklists Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CollapsibleChecklistsSection(
                    task: task,
                    scrollController: ScrollController(),
                  ),
                ),
              ),

              // Linked entries (not sticky)
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
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
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

// Simple sticky delegate that just shows a fixed height widget
class _SimpleStickyDelegate extends SliverPersistentHeaderDelegate {
  _SimpleStickyDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

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
    return Material(
      color: context.colorScheme.surface,
      elevation: overlapsContent ? 2 : 0,
      child: Container(
        height: maxHeight,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SimpleStickyDelegate oldDelegate) {
    return minHeight != oldDelegate.minHeight ||
        maxHeight != oldDelegate.maxHeight ||
        child != oldDelegate.child;
  }
}

// Collapsed task header widget
class _CollapsedTaskHeader extends StatelessWidget {
  const _CollapsedTaskHeader({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
}

// Expanded task header content
class _ExpandedTaskHeader extends StatelessWidget {
  const _ExpandedTaskHeader({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status, estimate, category
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
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
                  label:
                      'Work', // TODO: Get actual category name from CategoryController
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Date range
          Row(
            children: [
              Icon(
                MdiIcons.calendarRange,
                size: 16,
                color: context.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${_formatDate(task.data.dateFrom)} - ${_formatDate(task.data.dateTo)}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                  Consumer(
                    builder: (context, ref, _) {
                      final progressState = ref
                          .watch(
                            taskProgressControllerProvider(id: task.meta.id),
                          )
                          .value;
                      final progressPercent = progressState != null &&
                              progressState.estimate.inMinutes > 0
                          ? (progressState.progress.inMinutes /
                                  progressState.estimate.inMinutes *
                                  100)
                              .clamp(0, 100)
                              .toInt()
                          : 0;
                      return Text(
                        '$progressPercent%',
                        style: context.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, _) {
                  final progressState = ref
                      .watch(
                        taskProgressControllerProvider(id: task.meta.id),
                      )
                      .value;
                  final progressValue = progressState != null &&
                          progressState.estimate.inMinutes > 0
                      ? (progressState.progress.inMinutes /
                              progressState.estimate.inMinutes)
                          .clamp(0.0, 1.0)
                      : 0.0;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 8,
                      backgroundColor:
                          context.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progressValue >= 1.0 ? Colors.green : _getStatusColor(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor() => task.data.status.map(
        open: (_) => Colors.blue,
        inProgress: (_) => Colors.blue,
        groomed: (_) => Colors.orange,
        blocked: (_) => Colors.red,
        onHold: (_) => Colors.amber,
        done: (_) => Colors.green,
        rejected: (_) => Colors.red.shade900,
      );
}

// Generic collapsed section header
class _CollapsedSection extends StatelessWidget {
  const _CollapsedSection({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: context.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// Collapsed checklists header
class _CollapsedChecklistsHeader extends StatelessWidget {
  const _CollapsedChecklistsHeader({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final totalItems = task.data.checklistIds?.length ?? 0;
    // TODO: Calculate actual completed items from checklists
    const completedItems = 0;

    return _CollapsedSection(
      icon: MdiIcons.checkboxMultipleOutline,
      title: 'Checklists',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }
}
