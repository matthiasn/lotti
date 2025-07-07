import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

class PremiumTaskDetailsPageV7 extends ConsumerStatefulWidget {
  const PremiumTaskDetailsPageV7({
    required this.taskId,
    super.key,
    this.readOnly = false,
  });

  final String taskId;
  final bool readOnly;

  @override
  ConsumerState<PremiumTaskDetailsPageV7> createState() =>
      _PremiumTaskDetailsPageV7State();
}

class _PremiumTaskDetailsPageV7State
    extends ConsumerState<PremiumTaskDetailsPageV7> {
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

              // Task Header - Collapsible Sticky Sliver
              SliverPersistentHeader(
                pinned: true,
                delegate: _MeasuredSliverDelegate(
                  collapsedHeight: 72,
                  collapsedBuilder: (context, progress) => _CollapsedTaskHeader(
                    task: task,
                    opacity: progress,
                  ),
                  expandedBuilder: (context, progress) => _ExpandedTaskHeader(
                    task: task,
                    opacity: 1.0 - progress,
                  ),
                ),
              ),

              // AI Summary - Collapsible Sticky Sliver
              SliverPersistentHeader(
                pinned: true,
                delegate: _MeasuredSliverDelegate(
                  collapsedHeight: 56,
                  collapsedBuilder: (context, progress) => _CollapsedSection(
                    icon: MdiIcons.robotOutline,
                    title: 'AI Task Summary',
                    opacity: progress,
                  ),
                  expandedBuilder: (context, progress) => Opacity(
                    opacity: 1.0 - progress,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CollapsibleAiSummarySection(
                        taskId: widget.taskId,
                        scrollController: ScrollController(),
                      ),
                    ),
                  ),
                ),
              ),

              // Checklists - Collapsible Sticky Sliver
              SliverPersistentHeader(
                pinned: true,
                delegate: _MeasuredSliverDelegate(
                  collapsedHeight: 56,
                  collapsedBuilder: (context, progress) =>
                      _CollapsedChecklistsHeader(
                    task: task,
                    opacity: progress,
                  ),
                  expandedBuilder: (context, progress) => Opacity(
                    opacity: 1.0 - progress,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CollapsibleChecklistsSection(
                        task: task,
                        scrollController: ScrollController(),
                      ),
                    ),
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

// Measured sliver delegate that dynamically calculates expanded height
class _MeasuredSliverDelegate extends SliverPersistentHeaderDelegate {
  _MeasuredSliverDelegate({
    required this.collapsedHeight,
    required this.collapsedBuilder,
    required this.expandedBuilder,
  });

  final double collapsedHeight;
  final Widget Function(BuildContext context, double progress) collapsedBuilder;
  final Widget Function(BuildContext context, double progress) expandedBuilder;

  double? _expandedHeight;
  final GlobalKey _expandedKey = GlobalKey();

  @override
  double get minExtent => collapsedHeight;

  @override
  double get maxExtent => _expandedHeight ?? 300; // Default until measured

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    return Material(
      color: context.colorScheme.surface,
      elevation: overlapsContent ? 4 : 0,
      shadowColor: Colors.black26,
      child: SizedBox(
        height: maxExtent - shrinkOffset,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Expanded content with measurement
            if (progress < 1.0)
              _MeasureSize(
                key: _expandedKey,
                onChange: (size) {
                  if (_expandedHeight != size.height && size.height > 0) {
                    _expandedHeight = size.height;
                    // Force rebuild with new height
                    (context as Element).markNeedsBuild();
                  }
                },
                child: expandedBuilder(context, progress),
              ),
            // Collapsed content
            if (progress > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: collapsedHeight,
                child: collapsedBuilder(context, progress),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MeasuredSliverDelegate oldDelegate) {
    return collapsedHeight != oldDelegate.collapsedHeight ||
        _expandedHeight != oldDelegate._expandedHeight;
  }
}

// Widget to measure size
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({
    required Key key,
    required this.onChange,
    required Widget child,
  }) : super(key: key, child: child);

  final void Function(Size size) onChange;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMeasureSize(onChange: onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize({required this.onChange});

  void Function(Size size) onChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = child!.size;
    if (_oldSize != newSize) {
      _oldSize = newSize;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onChange(newSize);
      });
    }
  }
}

// Collapsed task header
class _CollapsedTaskHeader extends ConsumerWidget {
  const _CollapsedTaskHeader({
    required this.task,
    required this.opacity,
  });

  final Task task;
  final double opacity;

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

    return Opacity(
      opacity: opacity,
      child: Container(
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
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _getStatusText(),
                style: context.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Progress indicator
            SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progressValue,
                    backgroundColor:
                        context.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressValue >= 1.0 ? Colors.green : statusColor,
                    ),
                    strokeWidth: 3,
                  ),
                  Text(
                    '${(progressValue * 100).toInt()}%',
                    style: context.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

// Expanded task header
class _ExpandedTaskHeader extends ConsumerStatefulWidget {
  const _ExpandedTaskHeader({
    required this.task,
    required this.opacity,
  });

  final Task task;
  final double opacity;

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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Editable Title
          if (_isEditingTitle)
            TextField(
              controller: _titleController,
              style: context.textTheme.titleLarge?.copyWith(
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
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.task.data.title,
                        style: context.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.edit,
                      size: 18,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Task details grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // Status selector
              _buildChip(
                context,
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
                  width: 120,
                  child: TextField(
                    controller: _estimateController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      suffixText: 'min',
                    ),
                    onSubmitted: (_) {
                      // TODO: Save estimate
                      setState(() => _isEditingEstimate = false);
                    },
                  ),
                )
              else
                _buildChip(
                  context,
                  icon: MdiIcons.clockOutline,
                  label: widget.task.data.estimate != null
                      ? '${widget.task.data.estimate} min'
                      : 'Set estimate',
                  onTap: () => setState(() => _isEditingEstimate = true),
                ),

              // Category
              _buildChip(
                context,
                icon: MdiIcons.folderOutline,
                label: 'Work', // TODO: Get actual category
                onTap: () {
                  // TODO: Show category selector
                },
              ),

              // Date range
              _buildChip(
                context,
                icon: MdiIcons.calendarRange,
                label:
                    '${_formatDate(widget.task.data.dateFrom)} - ${_formatDate(widget.task.data.dateTo)}',
                onTap: () {
                  // TODO: Show date range picker
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
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
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(progressValue * 100).toInt()}%',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _getProgressColor(progressValue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 8,
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
                        'Tracked: ${_formatDuration(progressState.progress)}',
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

  Widget _buildChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              size: 16,
              color: color ?? context.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: context.textTheme.labelMedium?.copyWith(
                color: color ?? context.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
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
    required this.opacity,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final double opacity;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
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
      ),
    );
  }
}

// Collapsed checklists header
class _CollapsedChecklistsHeader extends StatelessWidget {
  const _CollapsedChecklistsHeader({
    required this.task,
    required this.opacity,
  });

  final Task task;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final totalItems = task.data.checklistIds?.length ?? 0;
    // TODO: Calculate actual completed items from checklists
    const completedItems = 0;

    return _CollapsedSection(
      icon: MdiIcons.checkboxMultipleOutline,
      title: 'Checklists',
      opacity: opacity,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
