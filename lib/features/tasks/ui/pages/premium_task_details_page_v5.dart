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

class PremiumTaskDetailsPageV5 extends ConsumerStatefulWidget {
  const PremiumTaskDetailsPageV5({
    required this.taskId,
    super.key,
    this.readOnly = false,
  });

  final String taskId;
  final bool readOnly;

  @override
  ConsumerState<PremiumTaskDetailsPageV5> createState() =>
      _PremiumTaskDetailsPageV5State();
}

class _PremiumTaskDetailsPageV5State
    extends ConsumerState<PremiumTaskDetailsPageV5> {
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

              // Task Header - Sticky with clean collapsed view
              SliverPersistentHeader(
                pinned: true,
                delegate: _CleanStickyDelegate(
                  minHeight: 72,
                  maxHeight: 72,
                  child: _CollapsedTaskHeader(task: task),
                ),
              ),

              // Expanded Task Header Content with edit functionality
              SliverToBoxAdapter(
                child: _ExpandedTaskHeader(task: task),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),

              // AI Summary - Sticky
              SliverPersistentHeader(
                pinned: true,
                delegate: _CleanStickyDelegate(
                  minHeight: 56,
                  maxHeight: 56,
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

              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),

              // Checklists - Sticky
              SliverPersistentHeader(
                pinned: true,
                delegate: _CleanStickyDelegate(
                  minHeight: 56,
                  maxHeight: 56,
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

              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
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
                          Icon(
                            MdiIcons.link,
                            size: 20,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
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

// Clean sticky delegate with proper elevation and styling
class _CleanStickyDelegate extends SliverPersistentHeaderDelegate {
  _CleanStickyDelegate({
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
      elevation: overlapsContent ? 4 : 0,
      shadowColor: Colors.black26,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _CleanStickyDelegate oldDelegate) {
    return minHeight != oldDelegate.minHeight ||
        maxHeight != oldDelegate.maxHeight ||
        child != oldDelegate.child;
  }
}

// Clean collapsed task header with just title, status, and progress
class _CollapsedTaskHeader extends ConsumerWidget {
  const _CollapsedTaskHeader({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _getStatusColor();
    final progressState = ref
        .watch(
          taskProgressControllerProvider(id: task.meta.id),
        )
        .value;
    final progressValue = progressState != null &&
            progressState.estimate.inMinutes > 0
        ? (progressState.progress.inMinutes / progressState.estimate.inMinutes)
            .clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Title
          Expanded(
            child: Text(
              task.data.title,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _getStatusText(),
              style: context.textTheme.labelMedium?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Progress indicator
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progressValue,
                  backgroundColor: context.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressValue >= 1.0 ? Colors.green : statusColor,
                  ),
                  strokeWidth: 3,
                ),
                Text(
                  '${(progressValue * 100).toInt()}%',
                  style: context.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
        done: (_) => 'Done',
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

// Expanded task header with editable fields
class _ExpandedTaskHeader extends ConsumerStatefulWidget {
  const _ExpandedTaskHeader({required this.task});

  final Task task;

  @override
  ConsumerState<_ExpandedTaskHeader> createState() =>
      _ExpandedTaskHeaderState();
}

class _ExpandedTaskHeaderState extends ConsumerState<_ExpandedTaskHeader> {
  late TextEditingController _titleController;
  late TextEditingController _estimateController;
  bool _isEditingTitle = false;
  bool _isEditingEstimate = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.data.title);
    _estimateController = TextEditingController(
      text: widget.task.data.estimate?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _estimateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progressState = ref
        .watch(
          taskProgressControllerProvider(id: widget.task.meta.id),
        )
        .value;
    final progressValue = progressState != null &&
            progressState.estimate.inMinutes > 0
        ? (progressState.progress.inMinutes / progressState.estimate.inMinutes)
            .clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Editable Title
          if (_isEditingTitle)
            TextField(
              controller: _titleController,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () {
                        // TODO: Save title
                        setState(() => _isEditingTitle = false);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        _titleController.text = widget.task.data.title;
                        setState(() => _isEditingTitle = false);
                      },
                    ),
                  ],
                ),
              ),
            )
          else
            InkWell(
              onTap: () => setState(() => _isEditingTitle = true),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.task.data.title,
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.edit,
                      size: 20,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Task details grid
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              // Status selector
              _buildEditableChip(
                icon: Icons.circle,
                label: _getStatusText(),
                color: _getStatusColor(),
                onTap: () {
                  // TODO: Show status selector
                },
              ),

              // Estimate editor
              if (_isEditingEstimate)
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _estimateController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      suffixText: 'min',
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, size: 18),
                            onPressed: () {
                              // TODO: Save estimate
                              setState(() => _isEditingEstimate = false);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                _buildEditableChip(
                  icon: MdiIcons.clockOutline,
                  label: widget.task.data.estimate != null
                      ? '${widget.task.data.estimate} min'
                      : 'Add estimate',
                  onTap: () => setState(() => _isEditingEstimate = true),
                ),

              // Category
              _buildEditableChip(
                icon: MdiIcons.folderOutline,
                label: 'Work', // TODO: Get actual category
                onTap: () {
                  // TODO: Show category selector
                },
              ),

              // Date range
              _buildEditableChip(
                icon: MdiIcons.calendarRange,
                label:
                    '${_formatDate(widget.task.data.dateFrom)} - ${_formatDate(widget.task.data.dateTo)}',
                onTap: () {
                  // TODO: Show date range picker
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Progress section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    context.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(progressValue * 100).toInt()}%',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _getProgressColor(progressValue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 12,
                    backgroundColor:
                        context.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getProgressColor(progressValue),
                    ),
                  ),
                ),
                if (progressState != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Time tracked: ${_formatDuration(progressState.progress)}',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'Estimate: ${_formatDuration(progressState.estimate)}',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: (color ?? context.colorScheme.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                (color ?? context.colorScheme.primary).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: color ?? context.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: context.textTheme.labelLarge?.copyWith(
                color: color ?? context.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: color ?? context.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Color _getProgressColor(double progress) {
    if (progress >= 1.0) return Colors.green;
    if (progress >= 0.7) return Colors.orange;
    return _getStatusColor();
  }

  String _getStatusText() => widget.task.data.status.map(
        open: (_) => 'Open',
        inProgress: (_) => 'In Progress',
        groomed: (_) => 'Groomed',
        blocked: (_) => 'Blocked',
        onHold: (_) => 'On Hold',
        done: (_) => 'Done',
        rejected: (_) => 'Rejected',
      );

  Color _getStatusColor() => widget.task.data.status.map(
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: context.colorScheme.primary,
          ),
          const SizedBox(width: 12),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: context.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
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
