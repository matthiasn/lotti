import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/components/timeline/design_system_timeline_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/logic/goal_timeline_projection.dart';
import 'package:lotti/features/goals/model/goal_timeline_item.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_duration.dart';
import 'package:lotti/features/speech/ui/widgets/recording_playback.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme_text_styles.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';
import 'package:lotti/widgets/transcript/folded_words.dart';
import 'package:lotti/widgets/transcript/recording_transcript.dart';
import 'package:lotti/widgets/transcript/transcript_status.dart';
import 'package:material_ui/material_ui.dart';

/// The goal's rail of check-ins and reflections.
///
/// Presentation only: the merge and the day grouping are pure functions
/// (`goalTimelineItems`, `groupGoalItemsByDay`), and this draws their output
/// with the design system's timeline rows — the person timeline's anatomy —
/// and the shared transcript and fold, so a goal's check-ins and a person's
/// look alike.
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

class _GoalCheckInTimelineState extends ConsumerState<GoalCheckInTimeline>
    with TranscriptGraceRebuild {
  static const _pageSize = 20;

  int _visibleCount = _pageSize;

  /// When the soonest beat still inside its grace window leaves it.
  ///
  /// Collected while building the beats, then used to arm the rebuild.
  DateTime? _nextGraceExpiry;

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
    _nextGraceExpiry = null;
    if (items.isEmpty) return _Empty(action: widget.emptyAction);
    final cap = widget.maxBeats ?? _visibleCount;
    final visible = items.length <= cap ? items : items.sublist(0, cap);
    final hasOlder = widget.maxBeats == null && visible.length < items.length;

    final locale = Localizations.localeOf(context).toLanguageTag();
    final groups = groupGoalItemsByDay(
      visible,
      labelForDay: (day) => _dayLabel(context, day),
    );

    // The person timeline's own anatomy — section headers, a tile on a
    // rail, a caption meta line, the body, a trailing control — so a goal's
    // check-ins and a person's read as one kind of history.
    final rows = <Widget>[
      for (final group in groups) ...[
        DesignSystemTimelineSectionHeader(label: group.label),
        for (final (index, item) in group.items.indexed)
          _row(
            context,
            item,
            locale,
            last: index == group.items.length - 1,
          ),
      ],
    ];
    // After the rows, because building them is what discovers the deadline.
    // Arming only changes a timer, so it is safe from inside build.
    armGraceRebuild(_nextGraceExpiry);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...rows,
        if (hasOlder)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DesignSystemButton(
              key: const ValueKey('goal-checkin-load-older'),
              label: context.messages.timelineLoadOlder,
              variant: DesignSystemButtonVariant.tertiary,
              size: DesignSystemButtonSize.dense,
              onPressed: () => setState(
                () => _visibleCount = math.min(
                  items.length,
                  _visibleCount + _pageSize,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Today and yesterday read as words; anything older carries its date, so a
  /// rail spanning months stays navigable. Sentence case, as the person
  /// timeline's sections are.
  String _dayLabel(BuildContext context, DateTime day) {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return context.messages.timelineDayToday;
    if (difference == 1) return context.messages.timelineDayYesterday;
    return DateFormat(
      'EEEE · d MMM',
      Localizations.localeOf(context).toLanguageTag(),
    ).format(day);
  }

  /// The meta line every row leads with — the time, then the kind — in the
  /// person timeline's caption grammar.
  Widget _meta(BuildContext context, String time, String kind) {
    final tokens = context.designTokens;
    final style = tokens.typography.styles.others.caption.copyWith(
      fontFeatures: dateFigureFontFeatures,
      color: tokens.colors.text.mediumEmphasis,
    );
    // Both at every width, as the person timeline keeps its time and kind.
    return DsTieredText(tiers: ['$time · $kind'], style: style);
  }

  /// Opens a check-in's own entry, where its words can be read whole,
  /// edited or deleted.
  void _open(String entryId) => beamToNamed('/journal/$entryId');

  void _retry(String entryId) => unawaited(
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
  );

  Widget _row(
    BuildContext context,
    GoalTimelineItem item,
    String locale, {
    required bool last,
  }) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final time = DateFormat.Hm(locale).format(item.at.toLocal());

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
        // Absent words are normal, not an error: the recording is saved first
        // and transcribed after. Only once the grace window has closed does
        // the same picture mean nobody picked the recording up.
        final graceExpiry = checkIn.at.add(kTranscriptGrace);
        final waiting =
            checkIn.transcript == null &&
            inferenceStatus == InferenceStatus.idle &&
            !durableFailure;
        if (waiting && graceExpiry.isAfter(clock.now())) {
          // The rail has to wake itself for this one: nothing else is coming.
          _nextGraceExpiry =
              _nextGraceExpiry == null ||
                  graceExpiry.isBefore(_nextGraceExpiry!)
              ? graceExpiry
              : _nextGraceExpiry;
        }
        final kind = messages.goalCheckInKindVoice;
        return DesignSystemTimelineRow(
          key: ValueKey('goal-checkin-row-${checkIn.id}'),
          leading: const DesignSystemTimelineTile(icon: LottiIcons.mic),
          meta: _meta(context, time, kind),
          semanticsLabel: '$kind, $time',
          // The time this check-in counts for, correctable in place — the
          // recording's own length until the user says otherwise.
          trailing: GoalCheckInTimeChip(checkIn: checkIn),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              RecordingPlayback(checkIn.audio),
              RecordingTranscript(
                id: checkIn.id,
                status: transcriptStatusOf(
                  hasTranscript: checkIn.transcript != null,
                  running: inferenceStatus == InferenceStatus.running,
                  failed:
                      inferenceStatus == InferenceStatus.error ||
                      durableFailure,
                  graceExpiry: graceExpiry,
                  now: clock.now(),
                ),
                transcript: checkIn.transcript,
                onRetry: () => _retry(checkIn.id),
              ),
            ],
          ),
          onTap: () => _open(checkIn.id),
          last: last,
        );

      case final GoalTextCheckIn checkIn:
        final kind = messages.goalCheckInKindNote;
        return DesignSystemTimelineRow(
          key: ValueKey('goal-checkin-row-${checkIn.id}'),
          leading: const DesignSystemTimelineTile(icon: LottiIcons.note),
          meta: _meta(context, time, kind),
          semanticsLabel: '$kind, $time',
          trailing: GoalCheckInTimeChip(checkIn: checkIn),
          body: FoldedWords(id: checkIn.id, words: checkIn.text.trim()),
          onTap: () => _open(checkIn.id),
          last: last,
        );

      case final GoalReflectionItem reflection:
        final record = reflection.record;
        final note = record.note?.trim();
        final onOpen = widget.onOpenReflection;
        final dimensions = record.dimensionRatings.length;
        final kind = messages.goalCheckInKindReflection;
        return DesignSystemTimelineRow(
          key: ValueKey('goal-checkin-row-${reflection.id}'),
          // The verdict's glyph names the day; its colour is the pill's, so
          // the tile stays the one neutral tile every row wears.
          leading: DesignSystemTimelineTile(
            icon: dayVerdictGlyph(record.rating),
          ),
          meta: _meta(context, time, kind),
          semanticsLabel:
              '$kind, $time, ${dayVerdictLabel(context, record.rating)}',
          // No "Rated by you"-style attribution — the provenance stays on
          // the record, it is not day-to-day reading.
          trailing: _VerdictPill(rating: record.rating),
          body: note == null || note.isEmpty
              ? null
              : FoldedWords(id: reflection.id, words: note),
          footer: dimensions == 0
              ? null
              : Text(
                  messages.goalCheckInDimensionsRated(dimensions),
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
          onTap: onOpen == null ? null : () => onOpen(record.day),
          last: last,
        );
    }
  }
}

class _VerdictPill extends StatelessWidget {
  const _VerdictPill({required this.rating});

  final DayVerdict rating;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: dayVerdictFill(tokens, rating).withValues(alpha: 0.16),
        // Informative, not tappable: the small-chip radius, never the pill —
        // full rounding is reserved for clickable elements on this surface.
        borderRadius: BorderRadius.circular(tokens.radii.smallChips),
      ),
      child: Text(
        dayVerdictLabel(context, rating),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tokens.typography.styles.others.caption.copyWith(
          color: dayVerdictSurfaceInk(tokens, rating),
          fontWeight: tokens.typography.weight.semiBold,
        ),
      ),
    );
  }
}

/// An invitation, not an apology: the empty rail says what a check-in is for
/// and offers the one action that fixes it — in the design system's empty
/// state, as the person timeline's is.
class _Empty extends StatelessWidget {
  const _Empty({this.action});

  final Widget? action;

  @override
  Widget build(BuildContext context) => DesignSystemEmptyState(
    key: const ValueKey('goal-checkin-empty'),
    icon: LottiIcons.micIdle,
    hint: context.messages.goalCheckInsEmptyInvitation,
    action: action,
  );
}
