import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/ai/ui/unified_ai_popup_menu.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_button.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked_from.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/extended_header_modal.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/features/tasks/state/task_app_bar_controller.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/state/task_scroll_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklists_widget.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class PremiumTaskDetailsPage extends ConsumerStatefulWidget {
  const PremiumTaskDetailsPage({
    required this.taskId,
    super.key,
    this.readOnly = false,
    this.scrollToEntryId,
  });

  final String taskId;
  final bool readOnly;
  final String? scrollToEntryId;

  @override
  ConsumerState<PremiumTaskDetailsPage> createState() =>
      _PremiumTaskDetailsPageState();
}

// Section indices for navigation
class _SectionIndices {
  static const int taskHeader = 0;
  static const int aiSummary = 1;
  static const int checklists = 2;
  static const int linkedEntriesHeader = 3;
  // Dynamic indices for individual linked entries start at 4
}

class _PremiumTaskDetailsPageState
    extends ConsumerState<PremiumTaskDetailsPage> {
  final void Function() _listener = getIt<UserActivityService>().updateActivity;
  late final void Function() _updateOffsetListener;
  late ScrollController _scrollController;
  late ListController _listController;

  // Track visibility states
  bool _isTaskHeaderCollapsed = false;
  bool _isAiSummaryCollapsed = false;
  bool _isChecklistsCollapsed = false;

  // Track sticky header heights
  static const double _taskHeaderHeight = 60;
  static const double _sectionHeaderHeight = 48;

  // Track linked entry indices for navigation
  final Map<String, int> _linkedEntryIndices = {};

  // Time service for tracking current recording
  late final TimeService _timeService;

  @override
  void initState() {
    super.initState();

    // Get controllers from provider
    final scrollControllerState =
        ref.read(taskScrollControllerProvider(widget.taskId));
    _scrollController = scrollControllerState!.scrollController;
    _listController = scrollControllerState.listController;

    final provider = taskAppBarControllerProvider(id: widget.taskId);
    _updateOffsetListener = () {
      ref.read(provider.notifier).updateOffset(_scrollController.offset);
      _updateCollapseStates();
    };

    _scrollController
      ..addListener(_listener)
      ..addListener(_updateOffsetListener);

    // Initialize time service
    _timeService = getIt<TimeService>();

    // Schedule scroll to entry if provided
    if (widget.scrollToEntryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _scrollToEntryById(widget.scrollToEntryId!);
        });
      });
    }
  }

  @override
  void didUpdateWidget(PremiumTaskDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handle scrolling when widget updates with new scrollToEntryId
    if (widget.scrollToEntryId != null &&
        widget.scrollToEntryId != oldWidget.scrollToEntryId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollToEntryById(widget.scrollToEntryId!);
        });
      });
    }
  }

  void _updateCollapseStates() {
    if (!mounted) return;

    // Use scroll offset for detection
    final offset = _scrollController.offset;

    // Check if controller still has clients
    final hasClients = _scrollController.hasClients;
    final position =
        _scrollController.hasClients ? _scrollController.position : null;
    final maxScroll = position?.maxScrollExtent ?? 0;
    final minScroll = position?.minScrollExtent ?? 0;

    // Headers should show when scrolled past their content, and hide when scrolled back
    // Using lower thresholds for better UX
    final newTaskCollapsed =
        offset > 80; // Show after task header starts scrolling out
    final newAiCollapsed =
        offset > 300; // Show after AI summary starts scrolling out
    final newChecklistCollapsed =
        offset > 600; // Show after checklists start scrolling out

    // Enhanced debug logging
    debugPrint(
        'Scroll: offset=$offset, max=$maxScroll, min=$minScroll, hasClients=$hasClients, mounted=$mounted');
    debugPrint(
        'States: Task: $_isTaskHeaderCollapsed->$newTaskCollapsed, AI: $_isAiSummaryCollapsed->$newAiCollapsed, Checklist: $_isChecklistsCollapsed->$newChecklistCollapsed');

    // Force update regardless of change detection to debug the issue
    setState(() {
      _isTaskHeaderCollapsed = newTaskCollapsed;
      _isAiSummaryCollapsed = newAiCollapsed;
      _isChecklistsCollapsed = newChecklistCollapsed;
    });
  }

  void _scrollToSection(int sectionIndex) {
    ref
        .read(taskScrollControllerProvider(widget.taskId).notifier)
        .scrollToSection(sectionIndex);
  }

  void _scrollToTimeRecordingEntry() {
    final currentRecording = _timeService.getCurrent();
    if (currentRecording != null) {
      final entryId = currentRecording.meta.id;
      _scrollToEntryById(entryId);
    }
  }

  void _scrollToEntryById(String entryId) {
    ref
        .read(taskScrollControllerProvider(widget.taskId).notifier)
        .scrollToEntry(entryId);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_listener)
      ..removeListener(_updateOffsetListener);
    // Don't dispose the controllers - they're managed by the provider
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

    // Force rebuild on scroll state changes
    // ignore: unused_local_variable
    final taskCollapsed = _isTaskHeaderCollapsed;
    // ignore: unused_local_variable
    final aiCollapsed = _isAiSummaryCollapsed;
    // ignore: unused_local_variable
    final checklistCollapsed = _isChecklistsCollapsed;

    // Get linked entries to build indices
    final linkedEntriesProvider =
        linkedEntriesControllerProvider(id: task.meta.id);
    final entryLinks = ref.watch(linkedEntriesProvider).valueOrNull ?? [];

    // Build linked entry widgets and populate indices
    final linkedEntries = <Widget>[];
    _linkedEntryIndices.clear();

    for (var i = 0; i < entryLinks.length; i++) {
      final link = entryLinks[i];
      final entryIndex = _SectionIndices.linkedEntriesHeader + 1 + i;
      _linkedEntryIndices[link.toId] = entryIndex;
    }

    // Update indices in the scroll controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(taskScrollControllerProvider(widget.taskId).notifier)
          .updateIndices(_linkedEntryIndices);
    });

    for (var i = 0; i < entryLinks.length; i++) {
      final link = entryLinks[i];

      linkedEntries.add(
        EntryDetailsWidget(
          key: Key('${task.meta.id}-${link.toId}'),
          itemId: link.toId,
          popOnDelete: false,
          parentTags: task.meta.tagIds?.toSet(),
          linkedFrom: task,
          link: link,
          showAiEntry: true,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 100,
        titleSpacing: 0,
        toolbarHeight: 45,
        scrolledUnderElevation: 0,
        elevation: 10,
        title: const SizedBox.shrink(),
        leading: const BackWidget(),
        actions: [
          UnifiedAiPopUpMenu(journalEntity: task, linkedFromId: null),
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              color: context.colorScheme.outline,
            ),
            onPressed: () => ExtendedHeaderModal.show(
              context: context,
              entryId: widget.taskId,
              linkedFromId: null,
              link: null,
              inLinkedEntries: false,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingAddActionButton(
        linkedFromId: task.meta.id,
        categoryId: task.meta.categoryId,
      ),
      body: Stack(
        children: [
          // Main scrollable content
          SafeArea(
            child: SuperListView.builder(
              controller: _scrollController,
              listController: _listController,
              itemBuilder: (context, index) {
                switch (index) {
                  case _SectionIndices.taskHeader:
                    return Container(
                      color: context.colorScheme.surface,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _ExpandedTaskContent(task: task),
                    );

                  case _SectionIndices.aiSummary:
                    return Container(
                      color: context.colorScheme.surface,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                MdiIcons.robotOutline,
                                size: 20,
                                color: context.colorScheme.outline,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'AI Task Summary',
                                style: context.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: context.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _AiSummaryContent(taskId: widget.taskId),
                        ],
                      ),
                    );

                  case _SectionIndices.checklists:
                    return Container(
                      color: context.colorScheme.surface,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                MdiIcons.checkboxMultipleOutline,
                                size: 20,
                                color: context.colorScheme.outline,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Checklists',
                                style: context.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: context.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _ChecklistsContent(task: task),
                        ],
                      ),
                    );

                  case _SectionIndices.linkedEntriesHeader:
                    return Container(
                      color: context.colorScheme.surface,
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
                          // Linked entries are handled individually now
                          if (linkedEntries.isEmpty)
                            Text(
                              'No linked entries yet',
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          LinkedFromEntriesWidget(task),
                        ],
                      ),
                    );

                  default:
                    // Handle individual linked entries
                    final entryIndex =
                        index - _SectionIndices.linkedEntriesHeader - 1;
                    if (entryIndex >= 0 && entryIndex < linkedEntries.length) {
                      return linkedEntries[entryIndex];
                    }
                    // Bottom padding
                    return const SizedBox(height: 200);
                }
              },
              itemCount: _SectionIndices.linkedEntriesHeader +
                  1 +
                  linkedEntries.length +
                  1, // +1 for bottom padding
            ),
          ),

          // Sticky headers overlay - wrapped in builder to ensure proper rebuilds
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: Listenable.merge([_scrollController]),
              builder: (context, child) {
                // Recalculate states in builder to ensure fresh values
                final offset =
                    _scrollController.hasClients ? _scrollController.offset : 0;
                final showTask = offset > 80;
                final showAi = offset > 300;
                final showChecklist = offset > 600;

                if (!showTask && !showAi && !showChecklist) {
                  return const SizedBox.shrink();
                }

                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Task Header - Sticky when collapsed
                      if (showTask)
                        GestureDetector(
                          onTap: () =>
                              _scrollToSection(_SectionIndices.taskHeader),
                          child: Container(
                            height: _taskHeaderHeight,
                            decoration: BoxDecoration(
                              color: context.colorScheme.surface,
                              border: Border(
                                bottom: BorderSide(
                                  color: context.colorScheme.outlineVariant,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: _TaskHeaderBuilder(
                              task: task,
                              isSticky: true,
                              onTimeRecordingTap: _scrollToTimeRecordingEntry,
                            ),
                          ),
                        ),

                      // AI Summary Header - Sticky when collapsed
                      if (showAi)
                        GestureDetector(
                          onTap: () =>
                              _scrollToSection(_SectionIndices.aiSummary),
                          child: Container(
                            height: _sectionHeaderHeight,
                            decoration: BoxDecoration(
                              color: context.colorScheme.surface,
                              border: Border(
                                bottom: BorderSide(
                                  color: context.colorScheme.outlineVariant,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: _SectionHeaderBuilder(
                              icon: MdiIcons.robotOutline,
                              title: 'AI Task Summary',
                              isSticky: true,
                            ),
                          ),
                        ),

                      // Checklists Header - Sticky when collapsed
                      if (showChecklist)
                        GestureDetector(
                          onTap: () =>
                              _scrollToSection(_SectionIndices.checklists),
                          child: Container(
                            height: _sectionHeaderHeight,
                            decoration: BoxDecoration(
                              color: context.colorScheme.surface,
                              border: Border(
                                bottom: BorderSide(
                                  color: context.colorScheme.outlineVariant,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: _ChecklistsHeaderBuilder(
                              task: task,
                              isSticky: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
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

// Task Header Builder
class _TaskHeaderBuilder extends ConsumerWidget {
  const _TaskHeaderBuilder({
    required this.task,
    required this.isSticky,
    this.onTimeRecordingTap,
  });

  final Task task;
  final bool isSticky;
  final VoidCallback? onTimeRecordingTap;

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
        : 0.0;

    final timeService = getIt<TimeService>();
    final currentRecording = ref
        .watch(
          StreamProvider<JournalEntity?>((ref) => timeService.getStream()),
        )
        .valueOrNull;

    final isRecording = currentRecording != null &&
        timeService.linkedFrom?.meta.id == task.meta.id;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        boxShadow: isSticky
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
              ]
            : [],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            // Back button - matching BackWidget style
            IconButton(
              onPressed: () => getIt<NavService>().beamBack(),
              icon: Icon(
                Icons.chevron_left,
                size: 30,
                weight: 500,
                color: context.colorScheme.outline,
                semanticLabel: 'Navigate back',
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
            ),
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
            // Time recording indicator
            if (isRecording && onTimeRecordingTap != null)
              GestureDetector(
                onTap: onTimeRecordingTap,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.colorScheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        size: 12,
                        color: context.colorScheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Recording',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(width: 8),
            // Progress indicator
            SizedBox(
              width: 32,
              height: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progressValue.clamp(0.0, 1.0),
                    backgroundColor:
                        context.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressValue > 1.0
                          ? Colors.red
                          : progressValue >= 1.0
                              ? Colors.green
                              : statusColor,
                    ),
                    strokeWidth: 2.5,
                  ),
                  Text(
                    '${(progressValue * 100).toInt()}%',
                    style: context.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: progressValue > 1.0 ? Colors.red : null,
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

// Generic Section Header Builder
class _SectionHeaderBuilder extends StatelessWidget {
  const _SectionHeaderBuilder({
    required this.icon,
    required this.title,
    required this.isSticky,
  });

  final IconData icon;
  final String title;
  final bool isSticky;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        boxShadow: isSticky
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, 1),
                  blurRadius: 1,
                ),
              ]
            : [],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: context.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Checklists Header Builder
class _ChecklistsHeaderBuilder extends StatelessWidget {
  const _ChecklistsHeaderBuilder({
    required this.task,
    required this.isSticky,
  });

  final Task task;
  final bool isSticky;

  @override
  Widget build(BuildContext context) {
    final totalItems = task.data.checklistIds?.length ?? 0;
    // TODO: Calculate actual completed items from checklists
    const completedItems = 0;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        boxShadow: isSticky
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, 1),
                  blurRadius: 1,
                ),
              ]
            : [],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              MdiIcons.checkboxMultipleOutline,
              size: 20,
              color: context.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Checklists',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
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
          ],
        ),
      ),
    );
  }
}

// Expanded task content
class _ExpandedTaskContent extends ConsumerStatefulWidget {
  const _ExpandedTaskContent({required this.task});

  final Task task;

  @override
  ConsumerState<_ExpandedTaskContent> createState() =>
      _ExpandedTaskContentState();
}

class _ExpandedTaskContentState extends ConsumerState<_ExpandedTaskContent> {
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
        : 0.0;

    return ModernBaseCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

          // Task details chips
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
          ModernBaseCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(12),
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
                        color: progressValue > 1.0
                            ? Colors.red
                            : _getProgressColor(progressValue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressValue.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor:
                        context.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressValue > 1.0
                          ? Colors.red
                          : _getProgressColor(progressValue),
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
    if (progress >= 0.7 && progress < 1.0) return Colors.orange;
    if (progress < 0.7) return _getStatusColor();
    return Colors.green;
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

// AI Summary Content Widget
class _AiSummaryContent extends ConsumerWidget {
  const _AiSummaryContent({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestSummaryAsync = ref.watch(
      latestSummaryControllerProvider(
        id: taskId,
        aiResponseType: AiResponseType.taskSummary,
      ),
    );

    final inferenceStatus = ref.watch(
      inferenceStatusControllerProvider(
        id: taskId,
        aiResponseType: AiResponseType.taskSummary,
      ),
    );

    final isRunning = inferenceStatus == InferenceStatus.running;

    return latestSummaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (aiResponse) {
        if (aiResponse == null) {
          return const SizedBox.shrink();
        }

        return ModernBaseCard(
          margin: EdgeInsets.zero,
          child: Stack(
            children: [
              AiResponseSummary(
                aiResponse,
                linkedFromId: taskId,
                fadeOut: false,
              ),
              if (isRunning)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Checklists Content Widget
class _ChecklistsContent extends ConsumerWidget {
  const _ChecklistsContent({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklistIds = task.data.checklistIds ?? [];

    if (checklistIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return ModernBaseCard(
      margin: EdgeInsets.zero,
      child: ChecklistsWidget(
        entryId: task.id,
        task: task,
      ),
    );
  }
}
