import 'package:flutter/material.dart';
import 'package:flutter_rating/flutter_rating.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/habits/ui/widgets/habit_completion_color_icon.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/habit_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/health_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/measurement_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/survey_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/workout_summary.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tags_view_widget.dart';
import 'package:lotti/features/journal/ui/widgets/text_viewer_widget_non_scrollable.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/ui/linked_duration.dart';
import 'package:lotti/features/tasks/ui/task_status.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/events/event_status.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// A modern journal card with gradient styling matching the task and settings design
class ModernJournalCard extends StatelessWidget {
  const ModernJournalCard({
    required this.item,
    this.maxHeight = 120,
    this.showLinkedDuration = false,
    this.isCompact = false,
    this.removeHorizontalMargin = false,
    super.key,
  });
  // Widget height constants
  static const double linkedDurationHeight = 40;

  final JournalEntity item;
  final double maxHeight;
  final bool showLinkedDuration;
  final bool isCompact;
  final bool removeHorizontalMargin;

  @override
  Widget build(BuildContext context) {
    if (item.meta.deletedAt != null) {
      return const SizedBox.shrink();
    }

    void onTap() {
      if (item is Task) {
        beamToNamed('/tasks/${item.meta.id}');
      } else {
        beamToNamed('/journal/${item.meta.id}');
      }
    }

    return ModernBaseCard(
      onTap: onTap,
      margin: EdgeInsets.symmetric(
        horizontal: removeHorizontalMargin ? 0 : AppTheme.spacingLarge,
        vertical: AppTheme.cardSpacing / 2,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPadding,
        vertical: AppTheme.cardPaddingCompact,
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 5),
        _buildBody(context),
        const SizedBox(height: 5),
        TagsViewWidget(item: item),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Leading icon
        if (_hasLeadingIcon()) ...[
          ModernIconContainer(
            isCompact: isCompact,
            child: _buildLeadingIcon(context),
          ),
          SizedBox(
            width: isCompact ? AppTheme.spacingMedium : AppTheme.spacingLarge,
          ),
        ],

        // Main content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _formatDate(),
                    style: context.textTheme.bodySmall?.copyWith(
                      fontFeatures: [const FontFeature.tabularFigures()],
                      color: context.colorScheme.onSurfaceVariant
                          .withValues(alpha: AppTheme.alphaSurfaceVariant),
                      fontSize: isCompact
                          ? AppTheme.subtitleFontSizeCompact
                          : AppTheme.subtitleFontSize,
                    ),
                  ),
                  if (_shouldShowCategoryIcon()) ...[
                    const SizedBox(width: 8),
                    CategoryIconCompact(
                      item.meta.categoryId,
                      size: CategoryIconConstants.iconSizeMedium,
                    ),
                  ],
                  const Spacer(),
                  _buildStatusIndicators(context),
                ],
              ),
              if (item is Task || item is JournalEvent) ...[
                const SizedBox(height: 4),
                _buildTitleRow(context),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTitleRow(BuildContext context) {
    if (item is Task) {
      final task = item as Task;
      return Row(
        children: [
          Expanded(
            child: Text(
              task.data.title,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: AppTheme.letterSpacingTitle,
                fontSize: isCompact
                    ? AppTheme.titleFontSizeCompact
                    : AppTheme.titleFontSize,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isCompact) ...[
            const SizedBox(width: 8),
            TaskStatusWidget(task),
          ],
        ],
      );
    } else if (item is JournalEvent) {
      final event = item as JournalEvent;
      final title = event.data.title;

      if (title.isNotEmpty) {
        return Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: AppTheme.letterSpacingTitle,
            fontSize: isCompact
                ? AppTheme.titleFontSizeCompact
                : AppTheme.titleFontSize,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildBody(BuildContext context) {
    // Special handling for tasks with linked duration
    if (item is Task && showLinkedDuration) {
      final task = item as Task;
      return LimitedBox(
        maxHeight: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            LinkedDuration(taskId: task.id),
            Flexible(
              child: TextViewerWidgetNonScrollable(
                entryText: task.entryText,
                maxHeight: maxHeight -
                    linkedDurationHeight, // Account for LinkedDuration height
              ),
            ),
          ],
        ),
      );
    }

    final textColor =
        context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: () {
        switch (item) {
          case final QuantitativeEntry qe:
            return HealthSummary(qe, showChart: false);
          case final JournalAudio audio:
            return _buildTextContent(audio.entryText, textColor);
          case final JournalEntry entry:
            return _buildTextContent(entry.entryText, textColor);
          case final JournalImage image:
            return _buildTextContent(image.entryText, textColor);
          case final SurveyEntry survey:
            return SurveySummary(survey, showChart: false);
          case final MeasurementEntry measurement:
            return MeasurementSummary(measurement);
          case final Task task:
            return _buildTextContent(task.entryText, textColor);
          case final JournalEvent event:
            return _buildTextContent(event.entryText, textColor);
          case final AiResponseEntry ai:
            return GptMarkdown(ai.data.response);
          case final WorkoutEntry workout:
            return WorkoutSummary(workout, showChart: false);
          case final HabitCompletionEntry habit:
            return HabitSummary(habit);
          case final Checklist checklist:
            return Text(
              checklist.data.title,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: isCompact
                    ? AppTheme.titleFontSizeCompact
                    : AppTheme.titleFontSize,
              ),
            );
          case final ChecklistItem ci:
            return Text(
              ci.data.title,
              style: context.textTheme.bodyMedium?.copyWith(
                decoration:
                    ci.data.isChecked ? TextDecoration.lineThrough : null,
              ),
            );
        }
      }(),
    );
  }

  Widget _buildTextContent(EntryText? entryText, Color color) {
    if (isCompact && entryText != null && entryText.plainText.isNotEmpty) {
      return Text(
        entryText.plainText,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppTheme.subtitleFontSize,
          color: color,
        ),
      );
    }
    return TextViewerWidgetNonScrollable(
      entryText: entryText,
      maxHeight: maxHeight,
    );
  }

  Widget _buildStatusIndicators(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Time recording icon for tasks
        if (item is Task)
          TimeRecordingIcon(
            taskId: item.id,
            padding: const EdgeInsets.only(left: 8),
          ),

        // Event specific indicators
        if (item is JournalEvent) ...[
          EventStatusWidget((item as JournalEvent).data.status),
          const SizedBox(width: 8),
          StarRating(
            rating: (item as JournalEvent).data.stars,
            size: 18,
            allowHalfRating: true,
          ),
        ],

        // Common indicators
        if (fromNullableBool(item.meta.private))
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              MdiIcons.security,
              color: context.colorScheme.error,
              size: 18,
            ),
          ),
        if (item is! JournalEvent && fromNullableBool(item.meta.starred))
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              MdiIcons.star,
              color: starredGold,
              size: 18,
            ),
          ),
        if (item is! JournalEvent && item.meta.flag == EntryFlag.import)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              MdiIcons.flag,
              color: context.colorScheme.error,
              size: 18,
            ),
          ),
      ],
    );
  }

  bool _hasLeadingIcon() {
    return item is JournalAudio ||
        item is ChecklistItem ||
        item is Checklist ||
        item is QuantitativeEntry ||
        item is MeasurementEntry ||
        item is HabitCompletionEntry ||
        item is AiResponseEntry;
  }

  Widget _buildLeadingIcon(BuildContext context) {
    final errorColor = context.colorScheme.error;

    return item.maybeMap(
      journalAudio: (item) {
        final transcripts = item.data.transcripts;
        return Icon(
          Icons.mic_rounded,
          color: transcripts != null && transcripts.isNotEmpty
              ? context.colorScheme.onSurfaceVariant
              : errorColor.withValues(alpha: 0.4),
          size: isCompact ? AppTheme.iconSizeCompact : AppTheme.iconSize,
        );
      },
      checklistItem: (item) => Icon(
        item.data.isChecked
            ? MdiIcons.checkboxMarked
            : MdiIcons.checkboxBlankOutline,
        color: _getChecklistColor(context, item),
        size: isCompact ? AppTheme.iconSizeCompact : AppTheme.iconSize,
      ),
      checklist: (_) => Icon(
        MdiIcons.checkAll,
        color: _getChecklistColor(context, item),
        size: isCompact ? AppTheme.iconSizeCompact : AppTheme.iconSize,
      ),
      quantitative: (_) => Icon(
        MdiIcons.heart,
        color: context.colorScheme.error,
        size: isCompact ? AppTheme.iconSizeCompact : AppTheme.iconSize,
      ),
      measurement: (_) => Icon(
        MdiIcons.numeric,
        color: context.colorScheme.primary,
        size: isCompact ? AppTheme.iconSizeCompact : AppTheme.iconSize,
      ),
      habitCompletion: (habitCompletion) =>
          HabitCompletionColorIcon(habitCompletion.data.habitId),
      aiResponse: (_) => Icon(
        Icons.assistant,
        color: context.colorScheme.primary,
        size: isCompact ? AppTheme.iconSizeCompact : AppTheme.iconSize,
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }

  bool _shouldShowCategoryIcon() {
    return item is! ChecklistItem &&
        item is! Checklist &&
        item is! HabitCompletionEntry &&
        item is! MeasurementEntry &&
        item is! WorkoutEntry &&
        item is! QuantitativeEntry &&
        item is! SurveyEntry;
  }

  String _formatDate() {
    return item is JournalEvent
        ? dfShort.format(item.meta.dateFrom)
        : dfShorter.format(item.meta.dateFrom);
  }

  Color _getChecklistColor(BuildContext context, JournalEntity item) {
    final categoryId = item.categoryId;
    final category = getIt<EntitiesCacheService>().getCategoryById(categoryId);
    return category != null
        ? colorFromCssHex(category.color)
        : context.colorScheme.onSurfaceVariant;
  }
}
