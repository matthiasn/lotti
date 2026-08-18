import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/logic/goal_timeline_projection.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/model/goal_timeline_item.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/goal_progress_card.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/timeline/timeline_models.dart';
import 'package:lotti/widgets/timeline/timeline_view.dart';

/// The goal's rail of check-ins and reflections.
///
/// Presentation only: the merge and the day grouping are pure functions
/// (`goalTimelineItems`, `groupGoalItemsByDay`), and this turns their output
/// into the shared timeline's vocabulary. Every beat kind here rides the shared
/// component's escape hatch or its built-in audio shape, so adding one never
/// means editing `lib/widgets/timeline/`.
class GoalCheckInTimeline extends ConsumerStatefulWidget {
  const GoalCheckInTimeline({
    required this.agentId,
    this.maxBeats,
    this.onOpenReflection,
    this.emptyAction,
    super.key,
  });

  final String agentId;

  /// Caps the rail to the most recent N beats — the inline preview on a phone.
  /// Null shows everything loaded.
  final int? maxBeats;

  /// Reopens a day's reflection sheet. Null renders reflections as static.
  final ValueChanged<DateTime>? onOpenReflection;

  /// Rendered under the empty-state invitation, normally the record CTA.
  final Widget? emptyAction;

  @override
  ConsumerState<GoalCheckInTimeline> createState() =>
      _GoalCheckInTimelineState();
}

class _GoalCheckInTimelineState extends ConsumerState<GoalCheckInTimeline> {
  static const _pageSize = 20;

  int _visibleCount = _pageSize;

  @override
  void didUpdateWidget(covariant GoalCheckInTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.agentId != widget.agentId ||
        oldWidget.maxBeats != widget.maxBeats) {
      _visibleCount = _pageSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(goalTimelineItemsProvider(widget.agentId));
    final cap = widget.maxBeats ?? _visibleCount;
    final visible = items.length <= cap ? items : items.sublist(0, cap);
    final hasOlder = widget.maxBeats == null && visible.length < items.length;

    final locale = Localizations.localeOf(context).toLanguageTag();
    final groups = groupGoalItemsByDay(
      visible,
      labelForDay: (day) => _dayLabel(context, day, locale),
    );

    return TimelineView(
      groups: [
        for (final group in groups)
          TimelineGroup(
            label: group.label,
            beats: [
              for (final item in group.items) _beat(context, item, locale),
            ],
          ),
      ],
      onLoadOlder: hasOlder
          ? () => setState(
              () => _visibleCount = math.min(
                items.length,
                _visibleCount + _pageSize,
              ),
            )
          : null,
      // Every check-in beat is a journal entry, so the rail offers what the
      // event timeline already does: open the entry itself. The rail shows a
      // clamped transcript and a player; the full entry is where the text can
      // be read whole, edited, or deleted.
      onOpenBeat: (entryId) => beamToNamed('/journal/$entryId'),
      onRetryTranscript: (entryId) => unawaited(
        ref.read(
          triggerSkillProvider((
            entityId: entryId,
            skillId: skillTranscribeContextId,
            linkedTaskId: null,
            referenceImages: null,
            overrideModelId: null,
            geminiThinkingMode: null,
          )).future,
        ),
      ),
      empty: _Empty(action: widget.emptyAction),
    );
  }

  /// Today and yesterday read as words; anything older carries its date, so a
  /// rail spanning months stays navigable.
  String _dayLabel(BuildContext context, DateTime day, String locale) {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return context.messages.timelineDayToday.toUpperCase();
    if (difference == 1) {
      return context.messages.timelineDayYesterday.toUpperCase();
    }
    return DateFormat('EEEE · d MMM', locale).format(day).toUpperCase();
  }

  TimelineBeat _beat(
    BuildContext context,
    GoalTimelineItem item,
    String locale,
  ) {
    final tokens = context.designTokens;
    final timeLabel = DateFormat.Hm(locale).format(item.at.toLocal());

    switch (item) {
      case final GoalAudioCheckIn checkIn:
        final inferenceStatus = ref.watch(
          inferenceStatusControllerProvider((
            id: checkIn.id,
            aiResponseType: AiResponseType.audioTranscription,
          )),
        );
        final durableFailure =
            checkIn.transcript == null &&
            (ref
                    .watch(
                      goalAudioTranscriptionFailedProvider(checkIn.id),
                    )
                    .value ??
                false);
        return TimelineBeat(
          id: checkIn.id,
          entryId: checkIn.id,
          timeLabel: timeLabel,
          kindLabel: context.messages.goalCheckInKindVoice,
          glyph: Icons.mic_rounded,
          accent: tokens.colors.interactive.enabled,
          content: TimelineBeatContent.audio(
            player: AudioPlayerWidget(checkIn.audio),
            transcript: checkIn.transcript,
            // Absent words are normal, not an error: the recording is saved
            // first and transcribed after.
            transcriptStatus: checkIn.transcript != null
                ? TimelineTranscriptStatus.none
                : inferenceStatus == InferenceStatus.running
                ? TimelineTranscriptStatus.pending
                : inferenceStatus == InferenceStatus.error || durableFailure
                ? TimelineTranscriptStatus.failed
                : TimelineTranscriptStatus.pending,
          ),
        );

      case final GoalTextCheckIn checkIn:
        return TimelineBeat(
          id: checkIn.id,
          entryId: checkIn.id,
          timeLabel: timeLabel,
          kindLabel: context.messages.goalCheckInKindNote,
          glyph: Icons.edit_note_rounded,
          accent: tokens.colors.text.mediumEmphasis,
          content: TimelineBeatContent.text(checkIn.text),
        );

      case final GoalReflectionItem reflection:
        final rating = reflection.record.rating;
        return TimelineBeat(
          id: reflection.id,
          timeLabel: timeLabel,
          kindLabel: context.messages.goalCheckInKindReflection,
          glyph: goalAssessmentRatingGlyph(rating),
          // The verdict's own colour, so the rail agrees with the day strip
          // and the reflection sheet rather than inventing a third vocabulary.
          accent: goalAssessmentRatingSurfaceInk(tokens, rating),
          content: TimelineBeatContent.custom(
            _ReflectionBody(
              record: reflection.record,
              onOpen: widget.onOpenReflection,
            ),
          ),
        );
    }
  }
}

class _ReflectionBody extends StatelessWidget {
  const _ReflectionBody({required this.record, this.onOpen});

  final GoalAssessmentRecord record;
  final ValueChanged<DateTime>? onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final note = record.note?.trim();
    final dimensions = record.dimensionRatings.length;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _VerdictPill(rating: record.rating),
            if (dimensions > 0) ...[
              SizedBox(width: tokens.spacing.step2),
              Text(
                context.messages.goalCheckInDimensionsRated(dimensions),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ],
          ],
        ),
        if (note != null && note.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.step2),
          Text(
            note,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ],
    );

    if (onOpen == null) return body;
    return InkWell(
      onTap: () => onOpen!(record.day),
      borderRadius: BorderRadius.circular(tokens.radii.s),
      child: body,
    );
  }
}

class _VerdictPill extends StatelessWidget {
  const _VerdictPill({required this.rating});

  final GoalAssessmentRating rating;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: goalAssessmentRatingFill(tokens, rating).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Text(
        goalAssessmentRatingLabel(context, rating),
        style: tokens.typography.styles.others.caption.copyWith(
          color: goalAssessmentRatingSurfaceInk(tokens, rating),
          fontWeight: tokens.typography.weight.semiBold,
        ),
      ),
    );
  }
}

/// An invitation, not an apology: the empty rail says what a check-in is for
/// and offers the one action that fixes it.
class _Empty extends StatelessWidget {
  const _Empty({this.action});

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
      child: Column(
        children: [
          Icon(
            Icons.mic_none_rounded,
            size: IconSizes.l,
            color: tokens.colors.text.lowEmphasis,
          ),
          SizedBox(height: tokens.spacing.step3),
          Text(
            context.messages.goalCheckInsEmptyInvitation,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          if (action != null) ...[
            SizedBox(height: tokens.spacing.step4),
            action!,
          ],
        ],
      ),
    );
  }
}
