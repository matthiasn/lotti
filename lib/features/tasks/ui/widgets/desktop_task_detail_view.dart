import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked_from.dart';
import 'package:lotti/features/journal/ui/widgets/linked_entries_with_timer.dart';
import 'package:lotti/features/tasks/ui/checklists/checklists_widget.dart';
import 'package:lotti/features/tasks/ui/cover_art_background.dart';
import 'package:lotti/features/tasks/ui/widgets/detail/desktop_action_bar.dart';
import 'package:lotti/features/tasks/ui/widgets/detail/desktop_ai_summary_card.dart';
import 'package:lotti/features/tasks/ui/widgets/detail/desktop_description_card.dart';
import 'package:lotti/features/tasks/ui/widgets/detail/desktop_task_header.dart';
import 'package:lotti/features/tasks/ui/widgets/detail/desktop_time_tracker_card.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Interactive desktop entry detail view matching the Figma design.
///
/// Composes real interactive widgets (header, AI summary, description,
/// time tracker, checklists, linked entries) into the three-column
/// desktop layout. Mobile continues to use the legacy task details page.
class DesktopTaskDetailView extends ConsumerWidget {
  const DesktopTaskDetailView({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(entryControllerProvider(id: taskId));
    final entry = entryAsync.value?.entry;

    if (entry is! Task) {
      if (entryAsync.isLoading) {
        return Center(
          child: CircularProgressIndicator(
            color: TaskShowcasePalette.accent(context),
          ),
        );
      }
      if (entryAsync.hasError) {
        log(
          'Failed to load task detail',
          name: 'DesktopTaskDetailView',
          error: entryAsync.error,
          stackTrace: entryAsync.stackTrace,
        );
      }
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: TaskShowcasePalette.page(context),
        border: Border(
          left: BorderSide(color: TaskShowcasePalette.border(context)),
        ),
      ),
      child: Stack(
        children: [
          DesignSystemScrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 140),
              child: _DesktopDetailContent(
                key: ValueKey(taskId),
                taskId: taskId,
                task: entry,
              ),
            ),
          ),
          DesktopActionBar(taskId: taskId),
        ],
      ),
    );
  }
}

class _DesktopDetailContent extends StatefulWidget {
  const _DesktopDetailContent({
    required this.taskId,
    required this.task,
    super.key,
  });

  final String taskId;
  final Task task;

  @override
  State<_DesktopDetailContent> createState() => _DesktopDetailContentState();
}

class _DesktopDetailContentState extends State<_DesktopDetailContent> {
  final GlobalKey _timerKey = GlobalKey();
  final GlobalKey _todoKey = GlobalKey();
  final GlobalKey _linkedEntriesKey = GlobalKey();
  final GlobalKey _linkedFromKey = GlobalKey();

  void _scrollToSection(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final hasCoverArt = widget.task.data.coverArtId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasCoverArt)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: CoverArtBackground(imageId: widget.task.data.coverArtId!),
          )
        else
          const TaskShowcaseHeroBanner(height: 176),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useCompactLayout = constraints.maxWidth < 720;

              final sectionPills = _buildSectionPills(context);

              final cards = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DesktopAiSummaryCard(taskId: widget.taskId),
                  SizedBox(height: tokens.spacing.step4),
                  DesktopDescriptionCard(taskId: widget.taskId),
                  SizedBox(height: tokens.spacing.step4),
                  KeyedSubtree(
                    key: _timerKey,
                    child: DesktopTimeTrackerCard(taskId: widget.taskId),
                  ),
                  SizedBox(height: tokens.spacing.step4),
                  KeyedSubtree(
                    key: _todoKey,
                    child: ChecklistsWidget(
                      entryId: widget.taskId,
                      task: widget.task,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step4),
                  KeyedSubtree(
                    key: _linkedEntriesKey,
                    child: LinkedEntriesWithTimer(
                      item: widget.task,
                      highlightedEntryId: null,
                      hideTaskEntries: true,
                    ),
                  ),
                  KeyedSubtree(
                    key: _linkedFromKey,
                    child: LinkedFromEntriesWidget(
                      widget.task,
                      hideTaskEntries: true,
                    ),
                  ),
                ],
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DesktopTaskHeader(taskId: widget.taskId),
                  SizedBox(height: useCompactLayout ? 16 : 24),
                  if (useCompactLayout) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < sectionPills.length; i++) ...[
                            sectionPills[i],
                            if (i < sectionPills.length - 1)
                              SizedBox(width: tokens.spacing.step2),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: tokens.spacing.step4),
                    cards,
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 136,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.messages.taskShowcaseJumpToSection,
                                style: tokens.typography.styles.others.caption
                                    .copyWith(
                                      color: TaskShowcasePalette.mediumText(
                                        context,
                                      ),
                                    ),
                              ),
                              SizedBox(height: tokens.spacing.step3),
                              for (var i = 0; i < sectionPills.length; i++) ...[
                                sectionPills[i],
                                if (i < sectionPills.length - 1)
                                  SizedBox(height: tokens.spacing.step2),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: tokens.spacing.step5),
                        Expanded(child: cards),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSectionPills(BuildContext context) {
    final items = [
      (
        context.messages.addActionAddTimer,
        Icons.timer_outlined,
        true,
        _timerKey,
      ),
      (
        context.messages.taskShowcaseTodo,
        Icons.check_box_outlined,
        false,
        _todoKey,
      ),
      (
        context.messages.taskShowcaseAudio,
        Icons.mic_none_rounded,
        false,
        _linkedEntriesKey,
      ),
      (
        context.messages.images,
        Icons.photo_outlined,
        false,
        _linkedEntriesKey,
      ),
      (
        context.messages.taskShowcaseLinked,
        Icons.subdirectory_arrow_right_rounded,
        false,
        _linkedFromKey,
      ),
    ];

    return items
        .map(
          (item) => TaskShowcaseSectionPill(
            icon: item.$2,
            label: item.$1,
            active: item.$3,
            onTap: () => _scrollToSection(item.$4),
          ),
        )
        .toList();
  }
}
