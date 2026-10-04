part of 'goal_progress_card.dart';

/// The weekday label track paired with the day squares. It shares the same
/// pitch and item extent — and the same horizontal scroller — as the squares
/// below it, so labels and cells can never drift out of alignment.
class _WeekdayTrack extends StatelessWidget {
  const _WeekdayTrack({
    required this.days,
    required this.trackId,
    required this.metrics,
  });

  final List<GoalProgressDay> days;

  /// Key namespace for this track's captions — a habit id, or the metric's
  /// criterion id. Not a habit id as such: a metric track wearing a habit's
  /// identity to reach this widget was the field name lying about itself.
  final String trackId;
  final DayTrackMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    // The one-letter form only where the column cannot hold "Mon": narrow
    // labels are harder to read, so they are a fallback, not the default.
    final format = metrics.narrowLabels
        ? DateFormat.EEEEE(locale)
        : DateFormat.E(locale);
    return DayTrack(
      height: metrics.labelHeight,
      pitch: metrics.pitch,
      children: [
        for (final day in days)
          SizedBox(
            key: ValueKey(
              'goal-habit-weekday-$trackId-'
              '${day.day.toIso8601String().substring(0, 10)}',
            ),
            width: daySquareSize(context),
            child: OverflowBox(
              maxWidth: double.infinity,
              child: Text(
                format.format(day.day),
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _periodLabel(BuildContext context, List<GoalProgressDay> days) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final format = DateFormat.MMMd(locale);
  return '${format.format(days.first.day)} – ${format.format(days.last.day)}';
}

String _dimensionSource(BuildContext context, GoalDimensionKind kind) =>
    switch (kind) {
      GoalDimensionKind.habit => context.messages.goalDimensionHabitSource,
      GoalDimensionKind.health => context.messages.goalDimensionHealthSource,
      GoalDimensionKind.measurable =>
        context.messages.goalDimensionMeasurableSource,
      GoalDimensionKind.categoryTime =>
        context.messages.goalDimensionCategoryTimeSource,
      GoalDimensionKind.labelTime =>
        context.messages.goalDimensionLabelTimeSource,
    };

/// Index of the authored rolling window's first day inside [activeDays] —
/// the cell the ages-out ring belongs to. Falls back to the list head for
/// non-rolling windows or short lists.
int _windowStartIndex(
  GoalHabitProgressView habit,
  List<GoalProgressDay> activeDays,
) {
  final window = habit.window;
  if (window is! GoalWindowRollingDays) return 0;
  if (activeDays.length < window.count) return 0;
  return activeDays.length - window.count;
}

class _HabitProgressRow extends StatefulWidget {
  const _HabitProgressRow({
    required this.habit,
    required this.today,
    required this.onOutcomeSelected,
    this.successfulWeeks,
    this.scrollGroup,
    this.verdictsByDay = const {},
  });

  final LinkedScrollGroup? scrollGroup;
  final Map<DateTime, DayVerdict> verdictsByDay;

  /// The rolling-week reliability tail, drawn on the trailing edge of the
  /// window line. Null for habits whose window is not a rolling week — the
  /// tail counts weeks, and nothing else here is measured in them.
  final int? successfulWeeks;
  final GoalHabitProgressView habit;
  final DateTime today;
  final GoalHabitOutcomeSelected? onOutcomeSelected;

  @override
  State<_HabitProgressRow> createState() => _HabitProgressRowState();
}

class _HabitProgressRowState extends State<_HabitProgressRow> {
  DateTime? _savingDay;

  Future<void> _recordOutcome(
    DateTime day,
    HabitCompletionType outcome,
  ) async {
    final callback = widget.onOutcomeSelected;
    if (callback == null || _savingDay != null) return;
    setState(() => _savingDay = day);
    var saved = false;
    try {
      saved = await callback(
        habitId: widget.habit.habitId,
        day: day,
        outcome: outcome,
      );
    } on Object {
      saved = false;
    } finally {
      if (mounted) setState(() => _savingDay = null);
    }
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.messages.saveFailedRetry)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final habit = widget.habit;
    final activeDays = habit.days;
    // Deterministic arithmetic, not a verdict — the header's status caption
    // owns the warning ink; the countdown stays neutral so urgency isn't
    // flattened by repetition. A habit that is AT its rate says nothing here:
    // the header already reads "On track", and the cryptic "at rate" beside
    // the reliability tail read as part of that figure.
    final note = habit.deficit == 0
        ? null
        : context.messages.goalDaysToRecover(habit.deficit);
    // NO cadence line at all: the corner block now carries count, target AND
    // the concrete window ("1 of 3 · calendar week"), so a "3× · calendar
    // week" line here would be the same facts twice on one card. The period
    // line is left with the one thing nothing else states: which dates the
    // squares below it cover.
    final cadenceStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final noteStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    Widget cells(DayTrackMetrics metrics) {
      // Interactive rows own a touch-floor-high track so each cell's hit
      // slot meets TapTargets.minimum vertically; read-only rows keep the
      // compact height.
      final trackHeight = widget.onOutcomeSelected == null
          ? daySquareSize(context)
          : TapTargets.minimum;
      return DayTrack(
        height: trackHeight,
        pitch: metrics.pitch,
        children: [
          for (var index = 0; index < activeDays.length; index++)
            _ProgressDayCell(
              day: activeDays[index],
              habitId: habit.habitId,
              today: DateUtils.isSameDay(
                activeDays[index].day,
                widget.today,
              ),
              verdict:
                  widget.verdictsByDay[DateTime.utc(
                    activeDays[index].day.year,
                    activeDays[index].day.month,
                    activeDays[index].day.day,
                  )],
              // The WINDOW's first day — with the page's shared span
              // rendering extra history, the list head can be a blank day
              // weeks before the window.
              agingOut:
                  index == _windowStartIndex(habit, activeDays) &&
                  habit.oldestSuccessAgesOutTonight,
              saving: _savingDay == activeDays[index].day,
              enabled: !activeDays[index].day.isAfter(widget.today),
              onOutcomeSelected: widget.onOutcomeSelected == null
                  ? null
                  : (outcome) => _recordOutcome(
                      activeDays[index].day,
                      outcome,
                    ),
            ),
        ],
      );
    }

    // The squares alone; the date axis is the tooltip on each of them.
    Widget track(DayTrackMetrics metrics) => cells(metrics);

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = dayTrackMetrics(context);
        final contentWidth = metrics.pitch * activeDays.length;
        final periodLine = _periodLabel(context, activeDays);
        // The deficit note shares the period line whenever everything on it
        // fits side by side: facts about the same window on one caption row,
        // instead of a dedicated line whose only content is usually one short
        // sentence. Only a narrow card stacks them.
        final successfulWeeks = widget.successfulWeeks;
        // The tail measured, not guessed: its bars are token-sized and its
        // caption is localized, so the only honest width is a laid-out one.
        final reliabilityWidth = successfulWeeks == null
            ? 0.0
            : _Reliability.bars * BorderWidths.emphasis * 2 +
                  (_Reliability.bars - 1) * tokens.spacing.step1 +
                  tokens.spacing.step3 +
                  goalTextWidth(
                    context,
                    context.messages.goalReliabilityWeeks(successfulWeeks),
                    noteStyle,
                  );
        final noteSharesLine =
            note != null &&
            goalTextWidth(context, periodLine, cadenceStyle) +
                    tokens.spacing.step4 +
                    goalTextWidth(context, note, noteStyle) +
                    (reliabilityWidth == 0
                        ? 0
                        : tokens.spacing.step4 + reliabilityWidth) <=
                constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The stacked fallback: the note flush to the trailing edge under
            // the corner block it qualifies, with the whole row to itself —
            // it wraps only when the card is narrower than the sentence, not
            // at an arbitrary fraction of a row nothing else shares.
            if (note != null && !noteSharesLine) ...[
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(note, textAlign: TextAlign.end, style: noteStyle),
              ),
              SizedBox(height: tokens.spacing.step2),
            ],
            // The span the squares below cover, on the same rail as the
            // squares themselves — it used to sit a chart's y-axis gutter to
            // their left, keyed to a plot this card does not draw.
            KeyedSubtree(
              key: ValueKey('goal-habit-plot-${habit.habitId}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Window line: which days these squares cover, and — for a
                  // rolling week — how many of the last six the habit
                  // actually carried. One row, because both qualify the same
                  // window; the tail on the trailing rail, so the line reads
                  // span-then-record rather than as two stacked captions.
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          periodLine,
                          style: cadenceStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (noteSharesLine) ...[
                        SizedBox(width: tokens.spacing.step4),
                        Text(note, style: noteStyle),
                      ],
                      const Spacer(),
                      if (successfulWeeks != null) ...[
                        SizedBox(width: tokens.spacing.step4),
                        _Reliability(successfulWeeks: successfulWeeks),
                      ],
                    ],
                  ),
                  // step1, not step2: the window line LABELS the squares, so
                  // it has to read as attached to them rather than floating
                  // midway between them and the header block above. A
                  // tappable track brings its own air: its touch-floor slot
                  // is taller than the square it centres.
                  if (widget.onOutcomeSelected == null)
                    SizedBox(height: tokens.spacing.step1),
                  // Labels and squares pan as one unit, and only where even
                  // the narrowest column overflows.
                  fitOrScrollDayTrack(
                    contentWidth: contentWidth,
                    availableWidth: constraints.maxWidth,
                    group: widget.scrollGroup,
                    child: track(metrics),
                  ),
                ],
              ),
            ),
            if (widget.onOutcomeSelected != null &&
                habit.suggestedFromDimensionName != null) ...[
              SizedBox(height: tokens.spacing.step4),
              // The design system's inline callout, with the action it is
              // asking for on its trailing edge: this is the one thing on the
              // card the app wants the user to do, and as a caption row
              // between two other caption rows it read as more fine print.
              DesignSystemInlineCallout(
                key: ValueKey('goal-habit-checkoff-callout-${habit.habitId}'),
                icon: LottiIcons.aiSpark,
                tone: tokens.colors.interactive.enabled,
                text: context.messages.goalHabitCheckOffSuggestion(
                  habit.suggestedFromDimensionName!,
                ),
                trailing: DesignSystemButton(
                  key: ValueKey('goal-habit-checkoff-${habit.habitId}'),
                  label: context.messages.goalHabitCheckOffAction,
                  onPressed: _savingDay != null
                      ? null
                      : () => _recordOutcome(
                          widget.today,
                          HabitCompletionType.success,
                        ),
                  size: DesignSystemButtonSize.dense,
                  leadingIcon: LottiIcons.confirm,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Localized authored cadence used by progress and Watching surfaces.
String goalWindowLabel(BuildContext context, GoalWindow window) =>
    switch (window) {
      GoalWindowDay() => context.messages.goalWindowSingleDay,
      GoalWindowRollingDays(:final count) =>
        context.messages.goalWindowRollingDays(count),
      GoalWindowCalendarWeek() => context.messages.goalWindowCalendarWeek,
      GoalWindowCalendarMonth() => context.messages.goalWindowCalendarMonth,
    };

class _ProgressDayCell extends StatelessWidget {
  const _ProgressDayCell({
    required this.day,
    required this.habitId,
    required this.agingOut,
    required this.saving,
    required this.enabled,
    required this.onOutcomeSelected,
    required this.today,
    this.verdict,
  });

  final GoalProgressDay day;
  final String habitId;

  /// Whether this is the current day. Empty and unjudged, it draws as the
  /// dashed unresolved outline rather than a past day's neutral fill.
  final bool today;

  /// The user's verdict on this habit for this day, when they recorded one
  /// in the reflection sheet. It decides the fill; the measured outcome is
  /// only what the app observed.
  final DayVerdict? verdict;

  /// Whether this is the window's oldest kept day and it ages out tonight.
  /// Said in the tooltip and the semantics, not drawn on the square.
  final bool agingOut;
  final bool saving;
  final bool enabled;
  final ValueChanged<HabitCompletionType>? onOutcomeSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final completionType = day.habitCompletionType;
    final missed = completionType == HabitCompletionType.fail;
    // A completed day is a partial success (lighter wash) while the habit's
    // own window target was not yet met as of that day; a null verdict from
    // older projections keeps the established full-strength rendering.
    final dayState = goalProgressDayMarkState(day);
    // A recorded verdict outranks the measured outcome for the fill, exactly
    // as on the whole-goal strip: the measurement is evidence, the
    // reflection is the user's ruling on the day.
    final verdict = this.verdict;
    final dayKey = day.day.toIso8601String().substring(0, 10);
    final pending =
        today &&
        verdict == null &&
        dayState == DayMarkState.none &&
        (completionType == null || completionType == HabitCompletionType.open);
    final size = daySquareSize(context);
    Widget cell = pending
        ? PlaceholderDayCell(
            key: ValueKey('goal-habit-day-visual-$habitId-$dayKey'),
            day: day.day,
          )
        : Container(
            key: ValueKey('goal-habit-day-visual-$habitId-$dayKey'),
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: verdict == null
                  ? dayMarkStateFill(tokens, dayState)
                  : dayVerdictFill(tokens, verdict),
              borderRadius: BorderRadius.circular(tokens.radii.xs),
            ),
            child: dayMarkSquareContent(
              context,
              state: dayState,
              verdict: verdict,
              day: day.day,
              size: size,
            ),
          );
    if (dayState == DayMarkState.partial) {
      cell = KeyedSubtree(
        key: ValueKey('goal-day-partial-$habitId-$dayKey'),
        child: cell,
      );
    }
    if (missed) {
      cell = KeyedSubtree(
        key: ValueKey('goal-day-missed-$habitId-$dayKey'),
        child: cell,
      );
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    // Prose, not the device's numeric form: this line is spoken by a screen
    // reader, where "8/10/2026" reads as "eight slash ten slash …" and the
    // year is noise in a week view.
    final date = DateFormat.yMMMd(locale).format(day.day);
    final menuDate = DateFormat.MMMEd(locale).format(day.day);
    final measured = switch (completionType) {
      HabitCompletionType.success =>
        context.messages.completeHabitSuccessButton,
      HabitCompletionType.skip => context.messages.completeHabitSkipButton,
      HabitCompletionType.fail => context.messages.completeHabitFailButton,
      HabitCompletionType.open ||
      null => context.messages.goalProgressHabitDayNoEntry,
    };
    // Spoken and hovered as the verdict where one stands, the measurement
    // otherwise — the cell must say what it shows. The ages-out fact rides
    // along: the square has no room to draw it.
    final ruling = verdict == null
        ? measured
        : dayVerdictLabel(context, verdict);
    final outcome = [
      ruling,
      if (agingOut) context.messages.goalProgressAgesOut,
    ].join(' · ');
    final semanticLabel = context.messages.goalProgressHabitDaySemantics(
      date,
      outcome,
    );
    final callback = onOutcomeSelected;
    if (callback == null) {
      return Semantics(
        label: semanticLabel,
        excludeSemantics: true,
        child: DsTooltip(
          title: menuDate,
          message: outcome,
          preferBelow: false,
          child: cell,
        ),
      );
    }
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: enabled && !saving,
      excludeSemantics: true,
      // The square stays small; the hit slot meets the design system's touch
      // floor vertically and fills the track pitch horizontally — invisible
      // ergonomics, unchanged rhythm.
      child: SizedBox.expand(
        key: ValueKey('goal-habit-day-$habitId-$dayKey'),
        child: _HabitDayOutcomeMenu(
          enabled: enabled && !saving,
          currentOutcome: completionType,
          headerKey: ValueKey('goal-habit-day-date-$habitId-$dayKey'),
          menuDate: menuDate,
          outcomeLabel: outcome,
          semanticLabel: semanticLabel,
          onSelected: callback,
          child: Center(
            child: saving
                ? SizedBox.square(
                    dimension: size,
                    child: const CircularProgressIndicator(
                      strokeWidth: BorderWidths.emphasis,
                    ),
                  )
                : cell,
          ),
        ),
      ),
    );
  }
}

/// The goal-details quick picker for one habit day.
///
/// This stays intentionally smaller than the full habit-recording dialog: a
/// date header and four immediate actions. The old Material popup left its
/// last hover band above the rounded bottom edge; the design-system menu uses
/// one clipped, edge-to-edge surface so the highlight follows both corners.
class _HabitDayOutcomeMenu extends StatefulWidget {
  const _HabitDayOutcomeMenu({
    required this.enabled,
    required this.currentOutcome,
    required this.headerKey,
    required this.menuDate,
    required this.outcomeLabel,
    required this.semanticLabel,
    required this.onSelected,
    required this.child,
  });

  final bool enabled;
  final HabitCompletionType? currentOutcome;
  final Key headerKey;
  final String menuDate;

  /// The day's recorded outcome, localized — the tooltip's body line.
  final String outcomeLabel;
  final String semanticLabel;
  final ValueChanged<HabitCompletionType> onSelected;
  final Widget child;

  @override
  State<_HabitDayOutcomeMenu> createState() => _HabitDayOutcomeMenuState();
}

class _HabitDayOutcomeMenuState extends State<_HabitDayOutcomeMenu> {
  final MenuController _controller = MenuController();

  bool _isSelected(HabitCompletionType outcome) =>
      outcome == HabitCompletionType.open
      ? widget.currentOutcome == null ||
            widget.currentOutcome == HabitCompletionType.open
      : widget.currentOutcome == outcome;

  void _select(HabitCompletionType outcome) {
    _controller.close();
    if (_isSelected(outcome)) return;
    widget.onSelected(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return MenuAnchor(
      controller: _controller,
      alignmentOffset: Offset(0, tokens.spacing.step2),
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
        side: WidgetStatePropertyAll(BorderSide.none),
      ),
      menuChildren: [
        DesignSystemContextMenu(
          key: const ValueKey('goal-habit-day-menu'),
          header: widget.menuDate,
          headerKey: widget.headerKey,
          edgeToEdge: true,
          size: DesignSystemContextMenuSize.small,
          width: tokens.spacing.step13,
          semanticsLabel: widget.semanticLabel,
          items: [
            DesignSystemContextMenuItem(
              key: const ValueKey('goal-habit-day-success'),
              label: context.messages.completeHabitSuccessButton,
              icon: LottiIcons.confirm,
              iconColor: tokens.colors.alert.success.ink,
              isSelected: _isSelected(HabitCompletionType.success),
              onTap: () => _select(HabitCompletionType.success),
            ),
            DesignSystemContextMenuItem(
              key: const ValueKey('goal-habit-day-skipped'),
              label: context.messages.completeHabitSkipButton,
              icon: LottiIcons.remove,
              iconColor: tokens.colors.text.mediumEmphasis,
              isSelected: _isSelected(HabitCompletionType.skip),
              onTap: () => _select(HabitCompletionType.skip),
            ),
            DesignSystemContextMenuItem(
              key: const ValueKey('goal-habit-day-missed'),
              label: context.messages.completeHabitFailButton,
              icon: LottiIcons.close,
              iconColor: tokens.colors.alert.error.ink,
              isSelected: _isSelected(HabitCompletionType.fail),
              onTap: () => _select(HabitCompletionType.fail),
            ),
            DesignSystemContextMenuItem(
              key: const ValueKey('goal-habit-day-none'),
              label: context.messages.goalProgressHabitDayNoEntry,
              icon: LottiIcons.radioUnselected,
              iconColor: tokens.colors.text.lowEmphasis,
              isSelected: _isSelected(HabitCompletionType.open),
              onTap: () => _select(HabitCompletionType.open),
            ),
          ],
        ),
      ],
      // No hover fill: the pitch-wide hit slot is far larger than the square
      // it serves, so the overlay drew a phantom button around the cell.
      // Hover answers with the styled tooltip naming the day and its
      // recorded outcome instead.
      builder: (context, controller, child) => DsTooltip(
        title: widget.menuDate,
        message: widget.outcomeLabel,
        preferBelow: false,
        child: DsQuietInk(
          onTap: widget.enabled
              ? () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                }
              : null,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          focusRing: true,
          builder: (context, highlighted) => widget.child,
        ),
      ),
    );
  }
}

class _Reliability extends StatelessWidget {
  const _Reliability({required this.successfulWeeks});

  /// Weeks the tail draws. Public so the window line can reserve the tail's
  /// width from the same number the tail is built from.
  static const int bars = 6;

  final int successfulWeeks;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Bars and their caption on ONE line, on the trailing rail of the window
    // line they qualify. Hugging, not stretching: the row that hosts it owns
    // the slack.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < bars; index++) ...[
          if (index > 0) SizedBox(width: tokens.spacing.step1),
          Container(
            width: BorderWidths.emphasis * 2,
            height: index < successfulWeeks
                ? IconSizes.s
                : tokens.spacing.step3,
            decoration: BoxDecoration(
              color: index < successfulWeeks
                  ? tokens.colors.alert.success.defaultColor
                  : tokens.colors.background.level03,
              borderRadius: BorderRadius.circular(tokens.radii.xs),
            ),
          ),
        ],
        SizedBox(width: tokens.spacing.step3),
        Text(
          context.messages.goalReliabilityWeeks(successfulWeeks),
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
    );
  }
}
