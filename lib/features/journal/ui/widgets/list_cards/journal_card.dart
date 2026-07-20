import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_rating/flutter_rating.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/journal/ui/widgets/time_span_bar.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
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
import 'package:lotti/widgets/cards/index.dart';

/// A modern journal list card with a single, consistent anatomy shared across
/// every entry type:
///
/// ```text
/// ┌──────────────────────────────────────────────┐
/// │ ▣  Primary content (title / text preview)   ★ │  ← glyph rail · title · status
/// │    relative date · metric chips                │  ← de-emphasized meta row
/// │    optional note preview                        │  ← secondary
/// │    label chips                                  │
/// └──────────────────────────────────────────────┘
/// ```
///
/// The leading glyph identifies the type at a glance, the brightest element is
/// the entry's own content, and structured data (health, workout, measurement,
/// survey) is humanised into compact chips instead of raw `key: value` dumps.
class ModernJournalCard extends StatelessWidget {
  const ModernJournalCard({
    required this.item,
    this.maxHeight = 120,
    this.showLinkedDuration = false,
    this.removeHorizontalMargin = false,
    this.selected = false,
    super.key,
  });

  final JournalEntity item;
  final double maxHeight;
  final bool showLinkedDuration;
  final bool removeHorizontalMargin;

  /// Whether this entry is the one open in the desktop detail pane.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (item.meta.deletedAt != null) {
      return const SizedBox.shrink();
    }

    void onTap() {
      if (item is Task) {
        beamToNamed('/tasks/${item.meta.id}');
      } else if (item is JournalEvent) {
        beamToNamed('/events/${item.meta.id}');
      } else {
        beamToNamed('/journal/${item.meta.id}');
      }
    }

    final tokens = context.designTokens;

    return ModernBaseCard(
      onTap: onTap,
      selected: selected,
      backgroundColor: dsCardSurface(context),
      // Same flat material as DesignSystemSectionCard: hairline decorative
      // border, no drop shadow — list rows and the detail card are one
      // surface recipe, not two coincidentally similar ones.
      borderColor: tokens.colors.decorative.level01,
      customShadows: const [],
      // step2 vertical: an 8px seam between neighbours, so the canvas
      // actually separates cards instead of leaving a hairline stripe.
      margin: EdgeInsets.symmetric(
        horizontal: removeHorizontalMargin ? 0 : tokens.spacing.step5,
        vertical: tokens.spacing.step2,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step4,
      ),
      child: _EntryCardContent(
        item: item,
        showLinkedDuration: showLinkedDuration,
      ),
    );
  }
}

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
        icon: Icons.mic_rounded,
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
            icon: Icons.graphic_eq_rounded,
            label: _shortDuration(a.data.dateTo.difference(a.data.dateFrom)),
          ),
        ],
      ),
      final JournalImage img => _scaffold(
        context,
        icon: Icons.image_rounded,
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
        icon: Icons.event_rounded,
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
        icon: MdiIcons.heartPulse,
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
        icon: MdiIcons.clipboardTextOutline,
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
        icon: Icons.auto_awesome_rounded,
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
            icon: Icons.auto_awesome_rounded,
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
            ? MdiIcons.checkboxMarked
            : MdiIcons.checkboxBlankOutline,
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
        icon: Icons.today_rounded,
        iconColor: _categoryColor(context, item),
        title: _titleText(
          context,
          dp.data.dayLabel ?? context.messages.dailyOsDayPlan,
        ),
      ),
      RatingEntry() => _scaffold(
        context,
        icon: Icons.insights_rounded,
        iconColor: _categoryColor(context, item),
        title: _titleText(context, context.messages.sessionRatingCardLabel),
      ),
      final ProjectEntry p => _scaffold(
        context,
        icon: Icons.folder_rounded,
        iconColor: _categoryColor(context, item),
        title: _titleText(context, p.data.title),
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
      icon: isTimeRecording ? Icons.timer_outlined : Icons.notes_rounded,
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
      icon: Icons.check_circle_outline_rounded,
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
    final label = item is Task
        ? context.messages.navTabTitleTasks
        : context.messages.navTabTitleEvents;
    return Padding(
      padding: EdgeInsets.only(left: tokens.spacing.step2),
      child: Tooltip(
        message: label,
        child: Semantics(
          label: label,
          child: Icon(
            Icons.open_in_new_rounded,
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
    final unit = dataType?.unitName ?? '';
    final value = nf.format(m.data.value);

    return _scaffold(
      context,
      icon: MdiIcons.ruler,
      iconColor: _categoryColor(context, item),
      title: _titleText(context, name),
      metaChips: [
        _metricChip(
          context,
          label: unit.isEmpty ? value : '$value $unit',
        ),
      ],
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
          icon: Icons.schedule_rounded,
          label: '${duration.inMinutes} min',
        ),
      );
    }
    final energy = data.energy;
    if (energy != null && energy > 0) {
      chips.add(
        _metricChip(
          context,
          icon: Icons.local_fire_department_rounded,
          label: '${nfWhole.format(energy)} kcal',
        ),
      );
    }
    final distance = data.distance;
    if (distance != null && distance > 0) {
      chips.add(
        _metricChip(
          context,
          icon: Icons.straighten_rounded,
          label: _distanceLabel(distance),
        ),
      );
    }
    return chips;
  }

  IconData _workoutIcon(String workoutType) {
    final type = workoutType.toLowerCase();
    if (type.contains('run')) return Icons.directions_run_rounded;
    if (type.contains('walk')) return Icons.directions_walk_rounded;
    if (type.contains('swim')) return Icons.pool_rounded;
    if (type.contains('cycl') || type.contains('bike')) {
      return Icons.directions_bike_rounded;
    }
    return Icons.fitness_center_rounded;
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
        color: context.designTokens.colors.alert.error.defaultColor,
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
            MdiIcons.security,
            color: tokens.colors.text.mediumEmphasis,
            size: size,
          ),
        ),
      if (!isEvent && fromNullableBool(item.meta.starred))
        labeled(
          context.messages.journalFilterStarred,
          Icon(MdiIcons.star, color: starredGold, size: size),
        ),
      // An import flag means "needs review", which is a warning, not an error.
      if (!isEvent && item.meta.flag == EntryFlag.import)
        labeled(
          context.messages.journalFilterFlagged,
          Icon(
            MdiIcons.flag,
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

/// The shared visual anatomy every journal card is laid out with.
class _EntryCardScaffold extends StatelessWidget {
  const _EntryCardScaffold({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.dateLabel,
    this.metaChips = const [],
    this.secondary,
    this.trailing,
    this.labelIds,
  });

  final IconData icon;
  final Color iconColor;
  final Widget title;
  final String dateLabel;
  final List<Widget> metaChips;
  final Widget? secondary;
  final Widget? trailing;
  final List<String>? labelIds;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final showLabels = labelIds != null && labelIds!.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TintedTypeGlyph(icon: icon, color: iconColor),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  if (trailing != null) ...[
                    SizedBox(width: tokens.spacing.step2),
                    trailing!,
                  ],
                ],
              ),
              SizedBox(height: tokens.spacing.step1),
              // A lone metric on an otherwise bare card (Weight, a
              // measurement) shares the meta row with the date: one fact does
              // not need its own band, and the feed skims two rows tighter.
              if (metaChips.length == 1 && secondary == null && !showLabels)
                Row(
                  children: [
                    Flexible(child: _MetaRow(dateLabel: dateLabel)),
                    SizedBox(width: tokens.spacing.step3),
                    metaChips.single,
                  ],
                )
              else ...[
                _MetaRow(dateLabel: dateLabel),
                if (metaChips.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step2),
                  Wrap(
                    spacing: tokens.spacing.step2,
                    runSpacing: tokens.spacing.step1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: metaChips,
                  ),
                ],
              ],
              if (secondary != null) ...[
                SizedBox(height: tokens.spacing.step2),
                secondary!,
              ],
              if (showLabels) ...[
                SizedBox(height: tokens.spacing.step2),
                _JournalCardLabelsRow(labelIds: labelIds!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// De-emphasized metadata line: just the relative date. The entry's category is
/// now conveyed by the colour of the glyph tile, so no category badge is shown
/// here (a meta-row badge previously collided with the date).
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.dateLabel});

  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Text(
      dateLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      // mediumEmphasis, not outline: timestamps are wayfinding in a
      // chronological feed and were flagged as too faint to skim by.
      style: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }
}

/// Habit completions resolve the habit definition via a notification-driven
/// stream so the card live-updates when the habit (or privacy) changes.
class _HabitCompletionContent extends StatefulWidget {
  const _HabitCompletionContent({
    required this.habitCompletion,
    required this.dateLabel,
    this.trailing,
    this.labelIds,
  });

  final HabitCompletionEntry habitCompletion;
  final String dateLabel;
  final Widget? trailing;
  final List<String>? labelIds;

  @override
  State<_HabitCompletionContent> createState() =>
      _HabitCompletionContentState();
}

class _HabitCompletionContentState extends State<_HabitCompletionContent> {
  late Stream<HabitDefinition?> _habitStream;

  @override
  void initState() {
    super.initState();
    _habitStream = _createStream();
  }

  @override
  void didUpdateWidget(covariant _HabitCompletionContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only re-subscribe when the habit actually changes; a plain parent
    // rebuild must not recreate the stream (which would refetch every frame).
    if (oldWidget.habitCompletion.data.habitId !=
        widget.habitCompletion.data.habitId) {
      _habitStream = _createStream();
    }
  }

  Stream<HabitDefinition?> _createStream() => notificationDrivenItemStream(
    notifications: getIt<UpdateNotifications>(),
    notificationKeys: {habitsNotification, privateToggleNotification},
    fetcher: () =>
        getIt<JournalDb>().getHabitById(widget.habitCompletion.data.habitId),
  );

  @override
  Widget build(BuildContext context) {
    final completion =
        widget.habitCompletion.data.completionType ??
        HabitCompletionType.success;

    return StreamBuilder<HabitDefinition?>(
      stream: _habitStream,
      builder: (context, snapshot) {
        final habit = snapshot.data;
        final name =
            habit?.name ?? context.messages.entryTypeLabelHabitCompletionEntry;
        final categoryColor = _habitColor(context, habit);
        final note = widget.habitCompletion.entryText?.plainText.trim() ?? '';

        return _EntryCardScaffold(
          icon: _completionIcon(completion),
          iconColor: categoryColor,
          title: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.designTokens.typography.styles.subtitle.subtitle2
                .copyWith(color: context.designTokens.colors.text.highEmphasis),
          ),
          dateLabel: widget.dateLabel,
          metaChips: [_statusChip(context, completion)],
          secondary: note.isEmpty
              ? null
              : Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.designTokens.typography.styles.body.bodySmall
                      .copyWith(
                        color: context.designTokens.colors.text.mediumEmphasis,
                      ),
                ),
          trailing: widget.trailing,
          labelIds: widget.labelIds,
        );
      },
    );
  }

  Widget _statusChip(BuildContext context, HabitCompletionType type) {
    final cs = context.colorScheme;
    final (label, color) = switch (type) {
      HabitCompletionType.success => (
        context.messages.habitCompletionStatusCompleted,
        context.designTokens.colors.alert.success.defaultColor,
      ),
      HabitCompletionType.skip => (
        context.messages.habitCompletionStatusSkipped,
        cs.onSurfaceVariant,
      ),
      HabitCompletionType.fail => (
        context.messages.habitCompletionStatusFailed,
        cs.error,
      ),
      HabitCompletionType.open => (
        context.messages.habitCompletionStatusOpen,
        cs.onSurfaceVariant,
      ),
    };
    return ModernStatusChip(
      label: label,
      color: color,
      icon: _completionIcon(type),
    );
  }

  IconData _completionIcon(HabitCompletionType type) {
    return switch (type) {
      HabitCompletionType.success => Icons.check_circle_rounded,
      HabitCompletionType.skip => Icons.remove_circle_outline_rounded,
      HabitCompletionType.fail => Icons.cancel_rounded,
      HabitCompletionType.open => Icons.radio_button_unchecked_rounded,
    };
  }

  Color _habitColor(BuildContext context, HabitDefinition? habit) {
    final accent = context.designTokens.colors.interactive.enabled;
    if (habit == null) {
      return accent;
    }
    final category = getIt<EntitiesCacheService>().getCategoryById(
      habit.categoryId,
    );
    return category != null ? colorFromCssHex(category.color) : accent;
  }
}

/// Checklists resolve their completion (`done/total`) via the shared
/// completion controller so the card surfaces progress at a glance.
class _ChecklistContent extends ConsumerWidget {
  const _ChecklistContent({
    required this.checklist,
    required this.dateLabel,
    required this.iconColor,
    this.trailing,
    this.labelIds,
  });

  final Checklist checklist;
  final String dateLabel;
  final Color iconColor;
  final Widget? trailing;
  final List<String>? labelIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref
        .watch(
          checklistCompletionControllerProvider((
            id: checklist.meta.id,
            taskId: null,
          )),
        )
        .value;

    // Reserve the status chip + progress bar from the first paint using the
    // checklist's synchronous linked-item count, so the row keeps a stable
    // height while the async completion counts resolve — otherwise the card
    // grows after load and shoves the feed below it as you scroll. The
    // completed count fills in (0 until resolved) without changing the layout.
    final total =
        counts?.totalCount ?? checklist.data.linkedChecklistItems.length;
    final completed = counts?.completedCount ?? 0;

    final metaChips = <Widget>[];
    Widget? secondary;
    if (total > 0) {
      metaChips.add(
        ModernStatusChip(
          label: '$completed/$total',
          color: context.designTokens.colors.interactive.enabled,
          icon: Icons.checklist_rounded,
        ),
      );
      secondary = _TypeProgressBar(value: completed / total);
    }

    return _EntryCardScaffold(
      icon: MdiIcons.checkAll,
      iconColor: iconColor,
      title: Text(
        checklist.data.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.designTokens.typography.styles.subtitle.subtitle2
            .copyWith(color: context.designTokens.colors.text.highEmphasis),
      ),
      dateLabel: dateLabel,
      metaChips: metaChips,
      secondary: secondary,
      trailing: trailing,
      labelIds: labelIds,
    );
  }
}

/// A thin, rounded completion bar used by the checklist card.
class _TypeProgressBar extends StatelessWidget {
  const _TypeProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.designTokens.radii.xs),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 4,
        backgroundColor: cs.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(
          context.designTokens.colors.interactive.enabled,
        ),
      ),
    );
  }
}

/// Internal widget that listens to label updates to rebuild when labels change.
class _JournalCardLabelsRow extends ConsumerWidget {
  const _JournalCardLabelsRow({required this.labelIds});

  final List<String> labelIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch label stream to rebuild when labels change globally
    ref.watch(labelsStreamProvider);

    final cache = getIt<EntitiesCacheService>();
    final showPrivate = cache.showPrivateEntries;

    // Use cache for fast label lookups
    final labels =
        labelIds
            .map(cache.getLabelById)
            .whereType<LabelDefinition>()
            .where((label) => showPrivate || !(label.private ?? false))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }

    final tokens = context.designTokens;
    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: labels.map((label) => LabelChip(label: label)).toList(),
    );
  }
}
