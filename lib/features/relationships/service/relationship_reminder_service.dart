import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/notifications/producer/notification_episode_producer.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/device_messages.dart';

/// Local hour at which a check-in reminder fires on its due day.
///
/// Late morning, deliberately: the reminder asks the user to contact another
/// human being, which is not a 07:00 activity. Offset from
/// [relationshipCadenceHour] (the agent's own tick) so the tick that arms an
/// episode is never racing the alarm it just set.
const relationshipReminderHour = 9;

/// Turns the relationship agent's deterministic cadence verdict into durable
/// check-in reminder rows (ADR 0039, deferred to plan v2 phase 8).
///
/// This is the half of the attention story the in-app banner channel
/// structurally cannot cover. A banner needs the app open; the whole point of
/// a check-in reminder is to reach a user who has not opened Lotti in five
/// weeks. So the reminder is **armed ahead of its due day**, while the app is
/// still running, and the OS holds the alarm from there.
///
/// It deliberately owns no cadence logic of its own. Every date it uses comes
/// from [RelationshipCadenceDerivation], the same single derivation Phase A
/// persists its register from and Phase B re-derives its facts from — so the
/// banner, the briefing and the OS alert can never disagree about when a
/// person is due. The episode is the due day: a check-in moves it, which
/// mints a new row and retracts the old one, and an ignored person is
/// therefore reminded once — see [NotificationEpisodeProducer] for the
/// choreography that follows from that.
class RelationshipReminderService
    extends
        NotificationEpisodeProducer<
          RelationshipEntry,
          RelationshipCadenceDerivation
        > {
  RelationshipReminderService({
    required super.notificationRepository,
    required super.domainLogger,
    AppLocalizations Function()? messages,
  }) : _messages = messages ?? deviceMessages;

  final AppLocalizations Function() _messages;

  @override
  String get kind => NotificationKinds.relationshipCheckIn;

  @override
  String get logSubDomain => 'relationshipReminder';

  @override
  String subjectIdOf(RelationshipEntry subject) => subject.meta.id;

  @override
  String? categoryOf(RelationshipEntry subject) => subject.meta.categoryId;

  @override
  String episodeKeyOf(RelationshipCadenceDerivation derivation) =>
      derivation.dueDayKey;

  /// The due day at [relationshipReminderHour], in local time.
  ///
  /// A [RelationshipCadenceDerivation]'s `dueDayUtc` is a DST-safe *day key*
  /// (UTC midnight standing for a local calendar day), not an instant —
  /// reading it as one would fire the reminder at the user's UTC offset
  /// instead of in their morning. Rebuilding from its calendar components
  /// lands on the intended local hour whichever side of a DST transition the
  /// due day falls.
  @override
  DateTime scheduledInstantOf(RelationshipCadenceDerivation derivation) {
    final dueDay = derivation.dueDayUtc;
    return DateTime(
      dueDay.year,
      dueDay.month,
      dueDay.day,
      relationshipReminderHour,
    );
  }

  /// Content-minimal by design (ADR 0039 Decision 6): notification copy
  /// leaves the app sandbox and lands on a lock screen, so it carries the
  /// person's name and nothing else about them — no cadence, no recency,
  /// nothing from a check-in. Baked in the arming device's locale and then
  /// synced as-is; see the notifications concept for why.
  @override
  NotificationEntity buildRow({
    required RelationshipEntry subject,
    required RelationshipCadenceDerivation derivation,
    required NotificationMeta meta,
  }) {
    final messages = _messages();
    return NotificationEntity.relationshipCheckIn(
      meta: meta,
      linkedRelationshipId: subject.meta.id,
      title: messages.relationshipCheckInReminderTitle(subject.data.title),
      body: messages.relationshipCheckInReminderBody,
    );
  }
}
