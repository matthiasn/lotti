import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/logic/goal_day_verdict.dart';
import 'package:lotti/features/goals/logic/goal_metric_series.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/checkins/goal_reflection_voice_notes.dart';
import 'package:lotti/features/goals/ui/goal_progress_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';
import 'package:material_ui/material_ui.dart';

/// The sheet's gap scale, so whitespace means something.
///
/// Before this the sheet used five different gaps with no rule, and the same
/// ~35px did duty as both a section break and a heading-to-content binding —
/// which is why nothing on it looked deliberately spaced.
///
///  * [_sectionGap] separates one block from the next.
///  * [_bindGap] ties a heading to the content it introduces.
///  * [_rowGap] is the pitch inside a list of like rows.
double _sectionGap(DsTokens tokens) => tokens.spacing.step5;
double _bindGap(DsTokens tokens) => tokens.spacing.step2;
double _rowGap(DsTokens tokens) => tokens.spacing.step1;

/// Opens one day's reflection sheet — THE one doorway, shared by the day
/// strip (via the detail page), the check-ins rail and the full timeline
/// page. Two call sites building the sheet by hand is how they stop
/// agreeing on what a reopened day shows.
///
/// The existing-record lookup stays scoped to the ACTIVE spec: reopening a day judged
/// under superseded criteria arrives blank, because saving records a NEW
/// verdict under the current criteria — the old record remains in the rail's
/// history.
void showGoalDayAssessmentSheet(
  BuildContext context, {
  required String agentId,
  required GoalSpecVersionEntity spec,
  required GoalProgressView progress,
  required List<GoalAssessmentRecord> assessments,
  required DateTime day,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Keeps the sheet clear of the status bar: without it the big date
    // title collided with the system clock.
    useSafeArea: true,
    builder: (context) => GoalDayAssessmentSheet(
      agentId: agentId,
      specVersionId: spec.id,
      specVersion: spec.version,
      day: day,
      progress: progress,
      // Reopening a judged day shows what was recorded. Arriving blank
      // offered Met with an empty note, and saving replaced the real
      // reflection with that default.
      existing: latestAssessmentsByDay(
        assessments,
        specVersionId: spec.id,
      )[DateTime.utc(day.year, day.month, day.day)],
    ),
  );
}

/// The verdict choices, in order, derived from the enum itself.
///
/// Both the day toggle and the per-dimension toggles read from here: hand-
/// listing them twice is how a fourth verdict ends up offered on one and
/// missing from the other.
List<DsSegment<DayVerdict>> _ratingSegments(BuildContext context) => [
  for (final rating in DayVerdict.values)
    DsSegment(rating, dayVerdictLabel(context, rating)),
];

class GoalDayAssessmentSheet extends ConsumerStatefulWidget {
  const GoalDayAssessmentSheet({
    required this.agentId,
    required this.specVersionId,
    required this.specVersion,
    required this.day,
    required this.progress,
    this.existing,
    this.canRecord = true,
    super.key,
  });

  final String agentId;
  final String specVersionId;
  final int specVersion;
  final DateTime day;
  final GoalProgressView progress;

  /// The verdict already standing for this day, when there is one.
  ///
  /// Every day in the strip can be reopened, so the sheet has to arrive
  /// showing what was recorded. Starting blank meant reopening a day filed as
  /// Missed offered Met with an empty note, and saving replaced the real
  /// reflection with that default — losing the note and the per-dimension
  /// verdicts along with it.
  final GoalAssessmentRecord? existing;

  /// Whether a voice note can be attached. False on a goal that cannot be
  /// reflected on, mirroring how the rest of the sheet gates itself.
  final bool canRecord;

  @override
  ConsumerState<GoalDayAssessmentSheet> createState() =>
      _GoalDayAssessmentSheetState();
}

class _GoalDayAssessmentSheetState
    extends ConsumerState<GoalDayAssessmentSheet> {
  final _note = TextEditingController();
  late DayVerdict _rating;
  final _dimensionRatings = <String, DayVerdict>{};
  var _saving = false;
  String? _error;

  /// What the evidence suggests for this day. Null when there is nothing to
  /// judge, in which case the sheet opens on Met as it always did.
  DayVerdict? _suggested;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _suggested = suggestedDayVerdict(widget.progress, widget.day);
    // A day already reflected on opens on what was recorded. Otherwise the
    // evidence picks the starting point — the verdict used to default to Met
    // regardless of what the numbers directly above it said.
    _rating = existing?.rating ?? _suggested ?? DayVerdict.met;
    _note.text = existing?.note ?? '';
    if (existing != null) _dimensionRatings.addAll(existing.dimensionRatings);
  }

  /// Whether the user has operated the verdict control at all.
  ///
  /// Distinguishes leaving the suggestion standing from choosing the same
  /// verdict deliberately. Comparing values alone cannot: an active choice
  /// that happens to agree with the suggestion is still the user's own
  /// judgement, and filing it as "suggested and accepted" would credit the
  /// agent for a call the user made.
  bool _touchedVerdict = false;

  /// True while the user has left the suggestion untouched on a fresh
  /// reflection — which is an acceptance, and worth recording as one.
  bool get _acceptedSuggestion =>
      widget.existing == null &&
      _suggested != null &&
      !_touchedVerdict &&
      _rating == _suggested;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(goalAssessmentServiceProvider)
          .record(
            agentId: widget.agentId,
            day: widget.day,
            specVersionId: widget.specVersionId,
            rating: _rating,
            dimensionRatings: _dimensionRatings,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            provenance: _acceptedSuggestion
                ? DayVerdictProvenance.suggestedAndAccepted
                : DayVerdictProvenance.ratedByUser,
          );
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.messages.saveFailedRetry;
        });
      }
      return;
    }
    if (!mounted) return;
    ref.invalidate(goalAssessmentHistoryProvider(widget.agentId));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final measured = _measuredRows(context, widget.progress, widget.day);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.step5,
          tokens.spacing.step4,
          tokens.spacing.step5,
          tokens.spacing.step5,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                DateFormat.yMMMMEEEEd(locale).format(widget.day),
                style: tokens.typography.styles.heading.heading3,
              ),
              Text(
                context.messages.goalAssessmentSpecVersion(
                  widget.specVersion,
                ),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
              SizedBox(height: _sectionGap(tokens)),
              // A real fence, not a comment claiming one: on the bare
              // sheet the evidence rows and the decision below them sat
              // on the same ground at the same pitch, so nothing said
              // which lines you could change and which you could not.
              DesignSystemSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The measured evidence is one read-only group, fenced off from
                    // the decision below it. Loose on the page, its rows and its
                    // "not editable" caption interleaved with the verdict control
                    // and its hint — four fine-print lines with nothing saying
                    // which belonged to what.
                    Text(
                      context.messages.goalAssessmentMeasuredTitle,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(
                            color: tokens.colors.text.highEmphasis,
                          ),
                    ),
                    SizedBox(height: _rowGap(tokens)),
                    Text(
                      context.messages.goalAssessmentMeasuredReadOnly,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.lowEmphasis,
                      ),
                    ),
                    SizedBox(height: _bindGap(tokens)),
                    for (final row in measured)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: tokens.spacing.step1,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              row.met == null
                                  ? LottiIcons.radioUnselected
                                  : row.met!
                                  ? LottiIcons.confirmCircled
                                  : LottiIcons.closeCircled,
                              size: IconSizes.xs,
                              // A cross is the MISSED mark in the verdict
                              // vocabulary, so it must not wear the warning hue
                              // that vocabulary gives to Mixed.
                              color: row.met == null
                                  ? tokens.colors.text.lowEmphasis
                                  : row.met!
                                  ? tokens.colors.alert.success.ink
                                  : tokens.colors.alert.error.ink,
                            ),
                            SizedBox(width: tokens.spacing.step2),
                            Expanded(
                              child: Text(
                                row.name,
                                style: tokens.typography.styles.body.bodySmall
                                    .copyWith(
                                      color: tokens.colors.text.highEmphasis,
                                    ),
                              ),
                            ),
                            Text(
                              row.value,
                              style: tokens.typography.styles.body.bodySmall
                                  .copyWith(
                                    color: tokens.colors.text.mediumEmphasis,
                                  ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: _sectionGap(tokens)),
              // The one decision this sheet exists for, and the only block
              // that had no heading — while both OPTIONAL inputs below it had
              // one.
              Text(
                context.messages.goalAssessmentVerdictTitle,
                style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
              SizedBox(height: _bindGap(tokens)),
              DsSegmentedToggle<DayVerdict>(
                expand: true,
                selected: _rating,
                onChanged: (value) => setState(() {
                  _rating = value;
                  _touchedVerdict = true;
                }),
                segments: _ratingSegments(context),
              ),
              // Only while the suggestion still stands. Once the user has
              // moved off it, saying where the old value came from is noise.
              if (_acceptedSuggestion) ...[
                SizedBox(height: _rowGap(tokens)),
                // On the rail, like every other block. Behind a leading icon
                // it was the one line in the sheet that started somewhere
                // else, and the word "Suggested" already carries the meaning
                // the sparkle was there to add.
                Text(
                  context.messages.goalAssessmentSuggestionHint,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ],
              SizedBox(height: _sectionGap(tokens)),
              DesignSystemTextarea(
                controller: _note,
                label: context.messages.goalAssessmentNote,
                minLines: 2,
                growWithContent: true,
              ),
              // A second way to answer the same question. The transcript is
              // never pasted into the textarea above: typed words and spoken
              // words are two contributions, and merging them makes it
              // impossible to tell which the user actually wrote.
              SizedBox(height: _bindGap(tokens)),
              GoalReflectionVoiceNotes(
                agentId: widget.agentId,
                day: widget.day,
                enabled: widget.canRecord,
              ),
              SizedBox(height: _sectionGap(tokens)),
              // Material's own tile chrome, removed: its default vertical
              // padding and minimum height left this row floating with more
              // air around it than the sheet's section gap, so it read as
              // belonging to nothing.
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                minTileHeight: 0,
                childrenPadding: EdgeInsets.zero,
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  context.messages.goalAssessmentPerDimension,
                  style: tokens.typography.styles.body.bodySmall,
                ),
                children: [
                  // Label ABOVE its control, not beside it. Beside it, the
                  // toggle claimed a fixed 480px — wider than a phone sheet —
                  // so the label's Expanded resolved to zero width and every
                  // dimension name rendered as a vertical column of single
                  // letters with the toggle painted across it. Four verdicts
                  // need the full measure on their own row anyway.
                  for (final row in measured)
                    if (row.ratable)
                      Padding(
                        padding: EdgeInsets.only(bottom: _sectionGap(tokens)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              row.name,
                              style: tokens.typography.styles.body.bodySmall
                                  .copyWith(
                                    color: tokens.colors.text.highEmphasis,
                                  ),
                            ),
                            SizedBox(height: _bindGap(tokens)),
                            DsSegmentedToggle<DayVerdict>(
                              expand: true,
                              selected:
                                  _dimensionRatings[row.criterionId] ?? _rating,
                              onChanged: (value) => setState(
                                () =>
                                    _dimensionRatings[row.criterionId] = value,
                              ),
                              segments: _ratingSegments(context),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
              SizedBox(height: _sectionGap(tokens)),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.alert.error.ink,
                  ),
                ),
                SizedBox(height: _bindGap(tokens)),
              ],
              DesignSystemButton(
                label: context.messages.goalAssessmentRecordFor(
                  DateFormat.EEEE(locale).format(widget.day),
                ),
                onPressed: _save,
                isLoading: _saving,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _MeasuredRow = ({
  String criterionId,
  String name,
  String value,
  bool? met,
  bool ratable,
});

/// The evidence rows for one day: what each dimension recorded, and — where a
/// daily number only means something in context — the trailing average that
/// number belongs to.
///
/// Derived rows carry `ratable: false`. The per-dimension verdict control
/// below rates CRITERIA, and a rolling average is not one: offering a Met /
/// Improving / Mixed / Missed toggle against it would file a judgement under
/// the criterion id its parent row already owns.
List<_MeasuredRow> _measuredRows(
  BuildContext context,
  GoalProgressView progress,
  DateTime day,
) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final number = NumberFormat.decimalPattern(locale);
  return [
    for (final habit in progress.habits)
      (
        criterionId: habit.criterionId,
        name: habit.name,
        value:
            habit.days.any(
              (entry) => DateUtils.isSameDay(entry.day, day) && entry.hasValue,
            )
            ? context.messages.goalAssessmentRecorded
            : context.messages.habitNotRecordedLabel,
        met: habit.days
            .where((entry) => DateUtils.isSameDay(entry.day, day))
            .firstOrNull
            ?.hasValue,
        ratable: true,
      ),
    for (final metric in progress.metrics) ...[
      (
        criterionId: metric.criterionId,
        // The DAY's own name for the quantity. A steps criterion is authored
        // as "Average steps per day" because that is what it evaluates over a
        // week — but the number printed beside it here is one day's total, and
        // labelling 9,950 steps an average is simply false.
        name: goalMetricDayRowLabel(context, metric),
        value:
            metric.days
                .where((entry) => DateUtils.isSameDay(entry.day, day))
                .map(
                  (entry) =>
                      entry.isObserved ? number.format(entry.value) : '—',
                )
                .firstOrNull ??
            '—',
        met: metric.days
            .where((entry) => DateUtils.isSameDay(entry.day, day))
            // The shared per-day policy (`GoalMetricProgressView.dayMark`):
            // a per-day target is met by the number this row prints beside
            // it, or for the rolling average by the window verdict as of
            // that day; a period-total criterion only by that verdict, since
            // one day's hours cannot be judged against a weekly total.
            .map((entry) => entry.isObserved ? metric.dayMark(entry) : null)
            .firstOrNull,
        ratable: true,
      ),
      // The average the goal is actually evaluated on, ending that day — the
      // figure the day's own number is either pulling up or dragging down, and
      // the one the criterion's target is compared against.
      if (goalMetricShowsSevenDayAverage(metric))
        if (goalMetricSevenDayAverageOn(metric, day: day) case final average?)
          (
            criterionId: '${metric.criterionId}:seven-day-average',
            name: context.messages.goalDimensionRollingAverageRow(
              goalMetricDayRowLabel(context, metric),
            ),
            value: formatGoalAggregate(
              number,
              average,
              against: metric.target,
            ),
            met: null,
            ratable: false,
          ),
    ],
  ];
}

// The reflection HISTORY deliberately has no widget here any more: reflections
// render as tight single rows in the goal's check-ins rail (see
// `goal_checkin_timeline.dart`), which also dropped the "Rated by you" /
// "suggested, you accepted" attribution — the provenance is still recorded on
// every [GoalAssessmentRecord], it just is not day-to-day reading.
