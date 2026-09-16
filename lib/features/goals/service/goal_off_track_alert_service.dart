import 'package:clock/clock.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/goals/runtime/goal_agent_phase_a.dart';
import 'package:lotti/features/goals/runtime/goal_wake_facts.dart';
import 'package:lotti/features/notifications/producer/notification_episode_producer.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/device_messages.dart';

/// Local hour at which a slipped goal's alert fires.
///
/// The cadence tick that detects a slip runs at [goalCadenceHour] (06:00),
/// and a signal-driven tick can run at any hour; neither is a time to be told
/// you are behind. The alert is armed for the next [goalOffTrackAlertHour]
/// instead — today's if still ahead, tomorrow's otherwise — the same hour
/// the check-in reminder uses, so a morning with both says both at once.
const goalOffTrackAlertHour = 9;

/// Turns the goal agent's deterministic slip verdict into a durable alert row
/// (ADR 0062) — the half of the goal's attention story the banner dock
/// structurally cannot cover: the device the user is not holding.
///
/// It owns no judgement of its own. Whether the goal has slipped is decided
/// in Phase A by `automaticGoalAdEligible`, the banner's own predicate; the
/// episode is the day the status transitioned, so a goal that stays behind is
/// alerted once per slip, and one that recovers has its alert retracted by
/// Phase A's `clearFor`. See [NotificationEpisodeProducer] for the
/// choreography that follows from that.
class GoalOffTrackAlertService
    extends
        NotificationEpisodeProducer<GoalOffTrackSubject, GoalWakeDerivation> {
  GoalOffTrackAlertService({
    required super.notificationRepository,
    required super.domainLogger,
    AppLocalizations Function()? messages,
  }) : _messages = messages ?? deviceMessages;

  final AppLocalizations Function() _messages;

  @override
  String get kind => NotificationKinds.goalOffTrack;

  @override
  String get logSubDomain => 'goalOffTrackAlert';

  @override
  String subjectIdOf(GoalOffTrackSubject subject) => subject.agentId;

  /// The transition day. Phase A calls `arm` only on the tick whose status
  /// changed, so the evaluation day of that tick names the slip — and a
  /// later tick in the same slip, with nothing transitioned, never asks.
  @override
  String episodeKeyOf(GoalWakeDerivation derivation) => derivation.periodKey;

  /// The next [goalOffTrackAlertHour] in local time.
  ///
  /// Calendar components, not a Duration: a slip detected across a DST
  /// change must still fire at the wall-clock hour, and adding 24 elapsed
  /// hours would shift it.
  @override
  DateTime scheduledInstantOf(GoalWakeDerivation derivation) {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day, goalOffTrackAlertHour);
    return now.isBefore(today)
        ? today
        : DateTime(now.year, now.month, now.day + 1, goalOffTrackAlertHour);
  }

  /// Content-minimal, the ADR 0039 Decision 6 rule applied to every kind:
  /// the goal's title and nothing about how far behind it is, because the
  /// copy lands on a lock screen. Baked in the arming device's locale and
  /// synced as-is; see the notifications concept for why.
  @override
  NotificationEntity buildRow({
    required GoalOffTrackSubject subject,
    required GoalWakeDerivation derivation,
    required NotificationMeta meta,
  }) {
    final messages = _messages();
    return NotificationEntity.goalOffTrack(
      meta: meta,
      linkedGoalAgentId: subject.agentId,
      title: messages.goalOffTrackNotificationTitle(subject.goalTitle),
      body: messages.goalOffTrackNotificationBody,
    );
  }
}
