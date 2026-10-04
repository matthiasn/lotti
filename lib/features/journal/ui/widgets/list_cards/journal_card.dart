import 'package:flutter_rating/flutter_rating.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/journal/ui/widgets/time_span_bar.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/tasks/state/checklist_completion_controller.dart';
import 'package:lotti/features/tasks/ui/linked_duration.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_stream.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/entry_tools.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:material_ui/material_ui.dart';

part 'journal_card_habit_completion_content_state_part.dart';

/// Resolves an entry to the slots of [_EntryCardScaffold]. One method per type
/// keeps the per-type presentation explicit and testable.
class _EntryCardContent extends StatelessWidget {
  const _EntryCardContent({
    required this.item,
    required this.showLinkedDuration,
  });

  final JournalEntity item;
  final bool showLinkedDuration;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      final JournalEntry e => _journalEntryCard(context, e),
      final JournalAudio a => _scaffold(
        context,
        icon: LottiIcons.mic,
        iconColor: _categoryColor(context, item),
        title: _contentTitle(
          context,
          a.entryText,
          fallback: context.messages.entryTypeLabelJournalAudio,
        ),
        secondary: _contentRemainder(context, a.entryText),
        metaChips: [
          _metricChip(
            context,
            icon: LottiIcons.waveform,
            label: _shortDuration(a.data.dateTo.difference(a.data.dateFrom)),
          ),
        ],
      ),
      final JournalImage img => _scaffold(
        context,
        icon: LottiIcons.image,
        iconColor: _categoryColor(context, item),
        title: _contentTitle(
          context,
          img.entryText,
          fallback: context.messages.entryTypeLabelJournalImage,
        ),
        secondary: _contentRemainder(context, img.entryText),
      ),
      final Task t => _taskScaffold(context, t),
      final JournalEvent ev => _scaffold(
        context,
        icon: LottiIcons.calendar,
        iconColor: _categoryColor(context, item),
        title: _titleText(
          context,
          ev.data.title.isNotEmpty
              ? ev.data.title
              : context.messages.entryTypeLabelJournalEvent,
        ),
        metaChips: [
          _eventStatusChip(context, ev.data.status),
          StarRating(
            rating: ev.data.stars,
            size: 16,
            allowHalfRating: true,
          ),
        ],
        secondary: _notePreview(context, ev.entryText),
        opensElsewhere: true,
      ),
      final QuantitativeEntry qe => _scaffold(
        context,
        icon: LottiIcons.heartRate,
        iconColor: _categoryColor(context, item),
        title: _titleText(context, humanHealthTypeName(qe.data.dataType)),
        metaChips: [
          _metricChip(
            context,
            label: '${nf.format(qe.data.value)} ${humanHealthUnit(qe.data)}',
          ),
        ],
      ),
      final MeasurementEntry m => _measurementScaffold(context, m),
      final WorkoutEntry w => _scaffold(
        context,
        icon: _workoutIcon(w.data.workoutType),
        iconColor: _categoryColor(context, item),
        title: _titleText(context, humanWorkoutType(w.data.workoutType)),
        metaChips: _workoutChips(context, w.data),
      ),
      final SurveyEntry s => _scaffold(
        context,
        icon: LottiIcons.clipboardText,
        iconColor: _categoryColor(context, item),
        title: _titleText(context, _surveyName(context, s)),
        metaChips: s.data.calculatedScores.entries
            .map(
              (score) => _metricChip(
                context,
                label: '${_shortScoreLabel(score.key)} ${score.value}',
                color: _scoreChipColor(context, score.key),
              ),
            )
            .toList(),
      ),
      final HabitCompletionEntry h => _HabitCompletionContent(
        habitCompletion: h,
        dateLabel: entryDateLabel(context, h.meta.dateFrom),
        trailing: _statusIndicators(context),
        labelIds: h.meta.labelIds,
      ),
      final AiResponseEntry ai => _scaffold(
        context,
        icon: LottiIcons.aiSpark,
        iconColor: _categoryColor(context, item),
        // Same first-line split as text entries: no entry type may render a
        // multi-line bold block at title tier.
        title: _contentTitle(
          context,
          EntryText(plainText: ai.data.response),
          fallback: 'AI',
        ),
        secondary: _contentRemainder(
          context,
          EntryText(plainText: ai.data.response),
        ),
        metaChips: [
          _metricChip(
            context,
            icon: LottiIcons.aiSpark,
            label: 'AI',
            color: context.designTokens.colors.interactive.enabled,
          ),
        ],
      ),
      final Checklist c => _ChecklistContent(
        checklist: c,
        dateLabel: entryDateLabel(context, c.meta.dateFrom),
        iconColor: _categoryColor(context, item),
        trailing: _statusIndicators(context),
        labelIds: c.meta.labelIds,
      ),
      final ChecklistItem ci => _scaffold(
        context,
        icon: ci.data.isChecked
            ? LottiIcons.checkboxChecked
            : LottiIcons.checkboxUnchecked,
        iconColor: _categoryColor(context, item),
        title: _titleText(
          context,
          ci.data.title,
          strikethrough: ci.data.isChecked,
          dim: ci.data.isChecked,
        ),
      ),
      final DayPlanEntry dp => _scaffold(
        context,
        icon: LottiIcons.today,
        iconColor: _categoryColor(context, item),
        title: _titleText(
          context,
          dp.data.dayLabel ?? context.messages.dailyOsDayPlan,
        ),
      ),
      RatingEntry() => _scaffold(
        context,
        icon: LottiIcons.insights,
        iconColor: _categoryColor(context, item),
        title: _titleText(context, context.messages.sessionRatingCardLabel),
      ),
      final ProjectEntry p => _scaffold(
        context,
        icon: LottiIcons.folder,
        iconColor: _categoryColor(context, item),
        title: _titleText(context, p.data.title),
      ),
      final RelationshipEntry r => _scaffold(
        context,
        icon: LottiIcons.person,
        iconColor: _categoryColor(context, item),
        title: _titleText(context, r.data.title),
        secondary: _notePreview(context, r.entryText),
      ),
      // Named for the person, as the check-in's own page is; the note it was
      // logged with follows. It opens on the People tab.
      final CheckInEntry c => _scaffold(
        context,
        icon: checkInInteractionIcon(c.data.interactionType),
        iconColor: _categoryColor(context, item),
        title: Consumer(
          builder: (context, ref, _) {
            final name = ref
                .watch(relationshipNameProvider(c.data.relationshipId))
                .value;
            return _titleText(
              context,
              name == null
                  ? context.messages.entryTypeLabelCheckIn
                  : context.messages.relationshipCheckInTitle(name),
            );
          },
        ),
        secondary: _notePreview(context, c.entryText),
        opensElsewhere: true,
      ),
      // A goal is a container, not a journal moment: its home is the Goals
      // tab, and its own detail surface is far richer than a list row. It is
      // rendered here only so the switch stays exhaustive — the goal list
      // query excludes spec snapshots, and goals themselves are not offered by
      // the journal's entry-type filter.
      final GoalEntry g => _scaffold(
        context,
        icon: LottiIcons.flag,
        iconColor: _categoryColor(context, item),
        title: _titleText(context, g.data.title),
      ),
      // A linked pull request lives in its task's pull request section. It is
      // rendered here only so the switch stays exhaustive: the journal's
      // entry-type filter does not offer it.
      final PullRequestEntry pr => _scaffold(
        context,
        icon: LottiIcons.merge,
        iconColor: _categoryColor(context, item),
        title: _titleText(context, pr.data.snapshot?.title ?? pr.data.key),
      ),
    };
  }

  // --- Scaffolding -----------------------------------------------------------

  Widget _scaffold(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Widget title,
    List<Widget> metaChips = const [],
    Widget? secondary,
    bool opensElsewhere = false,
  }) {
    final indicators = _statusIndicators(context);
    final trailing = opensElsewhere
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?indicators,
              _opensElsewhereGlyph(context),
            ],
          )
        : indicators;
    return _EntryCardScaffold(
      icon: icon,
      iconColor: iconColor,
      title: title,
      dateLabel: entryDateLabel(context, item.meta.dateFrom),
      metaChips: metaChips,
      secondary: secondary,
      trailing: trailing,
      labelIds: item.meta.labelIds,
    );
  }

  /// A plain journal entry renders as a note; a time recording (its `dateTo`
  /// after its `dateFrom`) leads with a timer glyph and a [TimeSpanBar] so it
  /// reads as elapsed time rather than a point-in-time observation.
  Widget _journalEntryCard(BuildContext context, JournalEntry e) {
    final span = e.meta.dateTo.difference(e.meta.dateFrom);
    // Only surface the span where durations are relevant — a task/event's linked
    // timeline (showLinkedDuration) — so the main logbook feed stays calm.
    final isTimeRecording = showLinkedDuration && isTimeRecordingSpan(span);
    return _scaffold(
      context,
      icon: isTimeRecording ? LottiIcons.timer : LottiIcons.note,
      iconColor: _categoryColor(context, item),
      title: _contentTitle(
        context,
        e.entryText,
        fallback: context.messages.entryTypeLabelJournalEntry,
      ),
      secondary: () {
        final remainder = _contentRemainder(context, e.entryText);
        final timeSpan = isTimeRecording
            ? TimeSpanBar(
                startLabel: hhMmFormat.format(e.meta.dateFrom.toLocal()),
                endLabel: hhMmFormat.format(e.meta.dateTo.toLocal()),
                durationLabel: formatRangeDuration(span),
              )
            : null;
        if (remainder != null && timeSpan != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [remainder, timeSpan],
          );
        }
        return remainder ?? timeSpan;
      }(),
    );
  }

  Widget _taskScaffold(BuildContext context, Task task) {
    final brightness = Theme.of(context).brightness;
    final secondary = <Widget>[
      if (showLinkedDuration) LinkedDuration(taskId: task.id),
      ?_notePreview(context, task.entryText),
    ];

    return _EntryCardScaffold(
      icon: LottiIcons.confirmCircled,
      iconColor: _categoryColor(context, item),
      title: _taskTitle(context, task.data.title),
      dateLabel: entryDateLabel(context, task.meta.dateFrom),
      metaChips: [
        // Neutral like the other metric chips: hue is reserved for workflow
        // status, so a P2-blue chip can't read as one thing with an
        // In-Progress-blue chip beside it.
        _metricChip(
          context,
          label: task.data.priority.short,
        ),
        // Tonal like every other metric chip — a filled saturated status
        // chip in a logbook of entries outshouted the selection highlight
        // and the titles. Hue lives in the tint alone; the label sits at the
        // same luminance tier as its neutral neighbours (the tasks-showcase
        // pattern), so it is neither the dimmest nor the loudest small text.
        _metricChip(
          context,
          label: task.data.status.localizedLabel(context),
          color: task.data.status.colorForBrightness(brightness),
          labelColor: context.designTokens.colors.text.highEmphasis,
        ),
      ],
      secondary: secondary.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: secondary,
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TimeRecordingIcon(taskId: task.id),
          _opensElsewhereGlyph(context),
        ],
      ),
      labelIds: task.meta.labelIds,
    );
  }

  /// Trailing marker for rows that navigate away from the logbook on tap
  /// (tasks open in the Tasks tab, events in the Events tab) instead of
  /// filling the split-pane details like every other entry type. Medium
  /// emphasis with a tooltip: it is the only signal of a different navigation
  /// model, so it must not be the faintest ink on the row.
  Widget _opensElsewhereGlyph(BuildContext context) {
    final tokens = context.designTokens;
    // Names the tab the row opens on.
    final label = switch (item) {
      Task() => context.messages.navTabTitleTasks,
      CheckInEntry() => context.messages.navTabTitlePeople,
      _ => context.messages.navTabTitleEvents,
    };
    return Padding(
      padding: EdgeInsets.only(left: tokens.spacing.step2),
      child: Tooltip(
        message: label,
        child: Semantics(
          label: label,
          child: Icon(
            LottiIcons.openExternal,
            size: tokens.spacing.step4,
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ),
    );
  }

  Widget _measurementScaffold(BuildContext context, MeasurementEntry m) {
    final dataType = getIt<EntitiesCacheService>().getDataTypeById(
      m.data.dataTypeId,
    );
    final name = dataType?.displayName ?? context.messages.measurableNotFound;
    // Without its definition the value can only be the raw number; with it,
    // the shared formatter reads a choice recording as the choice's title.
    final value = dataType == null
        ? nf.format(m.data.value)
        : measurementValueLabel(
            m.data,
            dataType,
            removedChoiceLabel: context.messages.measurableChoiceNotFound,
          );

    return _scaffold(
      context,
      icon: LottiIcons.measure,
      iconColor: _categoryColor(context, item),
      title: _titleText(context, name),
      metaChips: [_metricChip(context, label: value)],
      secondary: _notePreview(context, m.entryText),
    );
  }

  // --- Per-type helpers ------------------------------------------------------

  List<Widget> _workoutChips(BuildContext context, WorkoutData data) {
    final chips = <Widget>[];
    final duration = data.dateTo.difference(data.dateFrom);
    if (duration > Duration.zero) {
      chips.add(
        _metricChip(
          context,
          icon: LottiIcons.schedule,
          label: '${duration.inMinutes} min',
        ),
      );
    }
    final energy = data.energy;
    if (energy != null && energy > 0) {
      chips.add(
        _metricChip(
          context,
          icon: LottiIcons.streak,
          label: '${nfWhole.format(energy)} kcal',
        ),
      );
    }
    final distance = data.distance;
    if (distance != null && distance > 0) {
      chips.add(
        _metricChip(
          context,
          icon: LottiIcons.measure,
          label: _distanceLabel(distance),
        ),
      );
    }
    return chips;
  }

  IconData _workoutIcon(String workoutType) {
    final type = workoutType.toLowerCase();
    if (type.contains('run')) return LottiIcons.running;
    if (type.contains('walk')) return LottiIcons.walk;
    if (type.contains('swim')) return LottiIcons.swimming;
    if (type.contains('cycl') || type.contains('bike')) {
      return LottiIcons.cycling;
    }
    return LottiIcons.fitness;
  }

  String _distanceLabel(num meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${nfWhole.format(meters)} m';
  }

  /// Gives a survey score chip a valence tint: positive scores pick up the
  /// affirmative accent, negative scores stay muted, anything else is neutral.
  Color? _scoreChipColor(BuildContext context, String key) {
    final lower = key.toLowerCase();
    final alert = context.designTokens.colors.alert;
    if (lower.contains('positive')) {
      return alert.success.defaultColor;
    }
    if (lower.contains('negative')) {
      return alert.warning.defaultColor;
    }
    return null;
  }

  /// Trims survey score keys to a compact glance label, e.g.
  /// `Positive Affect Score` → `Positive`.
  String _shortScoreLabel(String key) {
    final trimmed = key
        .replaceAll(RegExp(r'\s*Affect Score$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*Score$', caseSensitive: false), '')
        .trim();
    return trimmed.isEmpty ? key : trimmed;
  }

  Widget _eventStatusChip(BuildContext context, EventStatus status) {
    return ModernStatusChip(
      label: status.localizedLabel(context),
      color: status.color,
    );
  }

  String _surveyName(BuildContext context, SurveyEntry survey) {
    final identifier = survey.data.taskResult.identifier;
    return switch (identifier) {
      'panasSurveyTask' => 'PANAS',
      'cfq11SurveyTask' => 'CFQ 11',
      _ => context.messages.entryTypeLabelSurveyEntry,
    };
  }

  String _shortDuration(Duration d) {
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
      return '${d.inHours}:$minutes:$seconds';
    }
    return '${d.inMinutes}:$seconds';
  }

  Color _categoryColor(BuildContext context, JournalEntity item) {
    final category = getIt<EntitiesCacheService>().getCategoryById(
      item.categoryId,
    );
    // Fall back to the design-token accent, not colorScheme.primary — the
    // Material primary is a second accent family that made uncategorized
    // glyph tiles clash with the app's teal.
    return category != null
        ? colorFromCssHex(category.color)
        : context.designTokens.colors.interactive.enabled;
  }

  // --- Shared content widgets ------------------------------------------------

  /// Splits an entry's text into a title-tier first line and a quiet
  /// remainder, so a body excerpt never renders three bold lines that
  /// outshout the real titles around it: the first line keeps subtitle2, the
  /// rest drops to the caption note-preview tier.
  ({String title, String? remainder}) _splitContent(EntryText? entryText) {
    final raw = entryText?.plainText.trim() ?? '';
    if (raw.isEmpty) {
      return (title: '', remainder: null);
    }
    final newline = raw.indexOf('\n');
    if (newline < 0) {
      return (title: _collapseWhitespace(raw), remainder: null);
    }
    final remainder = _collapseWhitespace(raw.substring(newline));
    return (
      title: _collapseWhitespace(raw.substring(0, newline)),
      remainder: remainder.isEmpty ? null : remainder,
    );
  }

  /// Primary line for a "content is text" entry: the first line of the entry's
  /// text at title tier, falling back to the localized type label when the
  /// entry has no text. Pair with [_contentRemainder] for the rest of the
  /// text.
  Widget _contentTitle(
    BuildContext context,
    EntryText? entryText, {
    required String fallback,
  }) {
    final title = _splitContent(entryText).title;
    if (title.isEmpty) {
      return _titleText(context, fallback);
    }
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: context.designTokens.typography.styles.subtitle.subtitle2.copyWith(
        color: context.designTokens.colors.text.highEmphasis,
      ),
    );
  }

  /// The lines after the first, rendered at the quiet note-preview tier — or
  /// null when the entry is a single line.
  Widget? _contentRemainder(BuildContext context, EntryText? entryText) {
    final remainder = _splitContent(entryText).remainder;
    if (remainder == null) {
      return null;
    }
    return Text(
      remainder,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      // bodySmall, one step above the caption date line, so the two grey
      // tiers inside a card stay distinguishable while both defer to the
      // title.
      style: context.designTokens.typography.styles.body.bodySmall.copyWith(
        color: context.designTokens.colors.text.mediumEmphasis,
      ),
    );
  }

  /// Flattens an entry's multi-line text into one preview string. Without
  /// this, an entry whose text starts with "title\n\nbody" renders a phantom
  /// blank line inside the row's 2–3 line preview window.
  static String _collapseWhitespace(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Widget _titleText(
    BuildContext context,
    String text, {
    bool strikethrough = false,
    bool dim = false,
  }) {
    final styles = context.designTokens.typography.styles;
    // A "done" line (dim) drops to regular body weight so the strikethrough
    // reads as a quiet de-emphasis rather than a heavy crossed-out heading.
    // Both sit at 14px to match the tasks list row title.
    final base = dim ? styles.body.bodySmall : styles.subtitle.subtitle2;
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: base.copyWith(
        color: dim
            ? context.designTokens.colors.text.mediumEmphasis.withValues(
                alpha: 0.62,
              )
            : context.designTokens.colors.text.highEmphasis,
        decoration: strikethrough ? TextDecoration.lineThrough : null,
        decorationColor: context.designTokens.colors.text.mediumEmphasis
            .withValues(
              alpha: 0.4,
            ),
        decorationThickness: strikethrough ? 1 : null,
      ),
    );
  }

  /// Task title line. An empty title renders the localized `(untitled)`
  /// placeholder in the error color (italic), matching the tasks list row, so a
  /// titleless task is an obvious gap rather than a silently blank card.
  Widget _taskTitle(BuildContext context, String title) {
    final trimmed = title.trim();
    if (trimmed.isNotEmpty) {
      return _titleText(context, trimmed);
    }
    return Text(
      context.messages.taskUntitled,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: context.designTokens.typography.styles.subtitle.subtitle2.copyWith(
        color: context.designTokens.colors.alert.error.ink,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget? _notePreview(BuildContext context, EntryText? entryText) {
    final text = _collapseWhitespace(entryText?.plainText ?? '');
    if (text.isEmpty) {
      return null;
    }
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: context.designTokens.typography.styles.body.bodySmall.copyWith(
        color: context.designTokens.colors.text.mediumEmphasis,
      ),
    );
  }

  Widget _metricChip(
    BuildContext context, {
    required String label,
    IconData? icon,
    Color? color,
    Color? labelColor,
  }) {
    return ModernStatusChip(
      label: label,
      color: color ?? context.designTokens.colors.text.mediumEmphasis,
      labelColor: labelColor,
      icon: icon,
    );
  }

  Widget? _statusIndicators(BuildContext context) {
    final tokens = context.designTokens;
    final isEvent = item is JournalEvent;
    // Status glyphs sit one step under the 18px they used to be, so they read
    // as annotations next to the 14px title rather than competing with it.
    final size = tokens.spacing.step5;
    // Tooltip + semantic label on every glyph: state must not be conveyed by
    // pictogram-and-color alone.
    Widget labeled(String label, Icon icon) => Tooltip(
      message: label,
      child: Semantics(label: label, child: icon),
    );
    final indicators = <Widget>[
      // Privacy is a property, not an alert: a neutral annotation keeps the
      // semantic hues (status blue, error red) unambiguous. The tooltip and
      // semantic label carry the meaning.
      if (fromNullableBool(item.meta.private))
        labeled(
          context.messages.journalFilterPrivate,
          Icon(
            LottiIcons.shield,
            color: tokens.colors.text.mediumEmphasis,
            size: size,
          ),
        ),
      if (!isEvent && fromNullableBool(item.meta.starred))
        labeled(
          context.messages.journalFilterStarred,
          Icon(LottiIcons.star, color: starredGold, size: size),
        ),
      // An import flag means "needs review", which is a warning, not an error.
      if (!isEvent && item.meta.isFlagged)
        labeled(
          context.messages.journalFilterFlagged,
          Icon(
            LottiIcons.flag,
            color: tokens.colors.alert.warning.defaultColor,
            size: size,
          ),
        ),
    ];

    if (indicators.isEmpty) {
      return null;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final indicator in indicators)
          Padding(
            padding: EdgeInsets.only(left: tokens.spacing.step2),
            child: indicator,
          ),
      ],
    );
  }
}
