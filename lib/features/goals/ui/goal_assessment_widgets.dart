import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class GoalDayAssessmentSheet extends ConsumerStatefulWidget {
  const GoalDayAssessmentSheet({
    required this.agentId,
    required this.specVersionId,
    required this.specVersion,
    required this.day,
    required this.progress,
    super.key,
  });

  final String agentId;
  final String specVersionId;
  final int specVersion;
  final DateTime day;
  final GoalProgressView progress;

  @override
  ConsumerState<GoalDayAssessmentSheet> createState() =>
      _GoalDayAssessmentSheetState();
}

class _GoalDayAssessmentSheetState
    extends ConsumerState<GoalDayAssessmentSheet> {
  final _note = TextEditingController();
  GoalAssessmentRating _rating = GoalAssessmentRating.met;
  final _dimensionRatings = <String, GoalAssessmentRating>{};
  var _saving = false;
  String? _error;

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
          );
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.messages.goalBannerActionFailed;
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
              SizedBox(height: tokens.spacing.step4),
              Text(
                context.messages.goalAssessmentMeasuredTitle,
                style: tokens.typography.styles.subtitle.subtitle2,
              ),
              SizedBox(height: tokens.spacing.step2),
              for (final row in measured)
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: tokens.spacing.step1,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        row.met == null
                            ? Icons.circle_outlined
                            : row.met!
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: IconSizes.xs,
                        color: row.met == null
                            ? tokens.colors.text.lowEmphasis
                            : row.met!
                            ? tokens.colors.alert.success.ink
                            : tokens.colors.alert.warning.ink,
                      ),
                      SizedBox(width: tokens.spacing.step2),
                      Expanded(child: Text(row.name)),
                      Text(
                        row.value,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: tokens.spacing.step2),
              Text(
                context.messages.goalAssessmentMeasuredReadOnly,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
              SizedBox(height: tokens.spacing.step5),
              DsSegmentedToggle<GoalAssessmentRating>(
                expand: true,
                selected: _rating,
                onChanged: (value) => setState(() => _rating = value),
                segments: [
                  DsSegment(
                    GoalAssessmentRating.met,
                    context.messages.goalAssessmentMet,
                  ),
                  DsSegment(
                    GoalAssessmentRating.mixed,
                    context.messages.goalAssessmentMixed,
                  ),
                  DsSegment(
                    GoalAssessmentRating.missed,
                    context.messages.goalAssessmentMissed,
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.step4),
              DesignSystemTextarea(
                controller: _note,
                label: context.messages.goalAssessmentNote,
                minLines: 2,
                growWithContent: true,
              ),
              SizedBox(height: tokens.spacing.step3),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  context.messages.goalAssessmentPerDimension,
                  style: tokens.typography.styles.body.bodySmall,
                ),
                children: [
                  for (final row in measured)
                    Padding(
                      padding: EdgeInsets.only(bottom: tokens.spacing.step3),
                      child: Row(
                        children: [
                          Expanded(child: Text(row.name)),
                          SizedBox(
                            width: tokens.spacing.step13 * 3,
                            child: DsSegmentedToggle<GoalAssessmentRating>(
                              expand: true,
                              selected:
                                  _dimensionRatings[row.criterionId] ?? _rating,
                              onChanged: (value) => setState(
                                () =>
                                    _dimensionRatings[row.criterionId] = value,
                              ),
                              segments: [
                                DsSegment(
                                  GoalAssessmentRating.met,
                                  context.messages.goalAssessmentMet,
                                ),
                                DsSegment(
                                  GoalAssessmentRating.mixed,
                                  context.messages.goalAssessmentMixed,
                                ),
                                DsSegment(
                                  GoalAssessmentRating.missed,
                                  context.messages.goalAssessmentMissed,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: tokens.spacing.step4),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.alert.error.ink,
                  ),
                ),
                SizedBox(height: tokens.spacing.step2),
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
});

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
      ),
    for (final metric in progress.metrics)
      (
        criterionId: metric.criterionId,
        name: metric.name,
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
            .map((entry) => entry.isObserved ? metric.meetsTarget(entry) : null)
            .firstOrNull,
      ),
  ];
}

class GoalAssessmentHistoryCard extends StatelessWidget {
  const GoalAssessmentHistoryCard({
    required this.records,
    required this.progress,
    super.key,
  });

  final List<GoalAssessmentRecord> records;
  final GoalProgressView progress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.goalAssessmentHistoryTitle,
            style: tokens.typography.styles.subtitle.subtitle1,
          ),
          SizedBox(height: tokens.spacing.step3),
          for (var index = 0; index < records.length; index++) ...[
            if (index > 0)
              Divider(
                height: tokens.spacing.step4,
                color: tokens.colors.decorative.level01,
              ),
            Builder(
              builder: (context) {
                final record = records[index];
                final suggestedBy = record.suggestedBy?.trim();
                final provenance = switch (record.provenance) {
                  GoalAssessmentProvenance.suggestedAndAccepted
                      when suggestedBy != null && suggestedBy.isNotEmpty =>
                    context.messages.goalAssessmentSuggestedProvenance(
                      suggestedBy,
                    ),
                  GoalAssessmentProvenance.suggestedAndAccepted =>
                    context.messages.goalAssessmentSuggestedProvenanceGeneric,
                  GoalAssessmentProvenance.ratedByUser =>
                    context.messages.goalAssessmentUserProvenance,
                };
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat.MMMEd(locale).format(record.day),
                        style: tokens.typography.styles.body.bodySmall,
                      ),
                    ),
                    _AssessmentRatingPill(rating: record.rating),
                    SizedBox(width: tokens.spacing.step3),
                    Flexible(
                      child: Text(
                        provenance,
                        textAlign: TextAlign.end,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.lowEmphasis,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _AssessmentRatingPill extends StatelessWidget {
  const _AssessmentRatingPill({required this.rating});

  final GoalAssessmentRating rating;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = switch (rating) {
      GoalAssessmentRating.met => tokens.colors.alert.success.defaultColor,
      GoalAssessmentRating.mixed => tokens.colors.alert.warning.defaultColor,
      GoalAssessmentRating.missed => tokens.colors.alert.error.defaultColor,
    };
    final label = switch (rating) {
      GoalAssessmentRating.met => context.messages.goalAssessmentMet,
      GoalAssessmentRating.mixed => context.messages.goalAssessmentMixed,
      GoalAssessmentRating.missed => context.messages.goalAssessmentMissed,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: SurfaceAlphas.washControl),
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step3,
          vertical: tokens.spacing.step1,
        ),
        child: Text(label, style: tokens.typography.styles.others.caption),
      ),
    );
  }
}
