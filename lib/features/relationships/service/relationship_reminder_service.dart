import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/device_messages.dart';
import 'package:lotti/services/domain_logging.dart';

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
/// person is due.
///
/// **One reminder per episode, so an ignored person is reminded once.** The
/// episode key is the due day, and the due day only moves when a check-in
/// lands — so a person the user never checks in with is never re-reminded.
/// That is the banner escalation's anti-nag ceiling applied to the OS channel,
/// and it is deliberate: a reminder that repeats until obeyed is what trains
/// people to switch reminders off. Making it recur would mean rolling the
/// episode key forward on elapsed cadences rather than on check-ins.
class RelationshipReminderService implements RelationshipReminderSink {
  RelationshipReminderService({
    required NotificationRepository notificationRepository,
    required DomainLogger domainLogger,
    AppLocalizations Function()? messages,
  }) : _notifications = notificationRepository,
       _logger = domainLogger,
       _messages = messages ?? deviceMessages;

  final NotificationRepository _notifications;
  final DomainLogger _logger;
  final AppLocalizations Function() _messages;

  /// Arms the reminder for the episode [derivation] describes, and retracts
  /// every superseded one.
  ///
  /// Called after the eligibility gate has already passed, so this does not
  /// re-check `important`/`active` — [clearFor] is the ineligible path.
  ///
  /// The retraction is what makes a logged check-in feel instant: the new
  /// check-in moves the due day, which mints a new episode, and the alarm for
  /// the old date is cancelled rather than left to fire about a date that no
  /// longer means anything.
  @override
  Future<void> arm({
    required RelationshipEntry relationship,
    required RelationshipCadenceDerivation derivation,
  }) async {
    final relationshipId = relationship.meta.id;
    await _bestEffort('arm', () async {
      final messages = _messages();

      final scheduledFor = _reminderInstant(derivation);
      // A due day already behind us gets no OS alarm. `schedule` routes a
      // past instant to `showNotificationNow`, so arming a lapsed person —
      // switching the feature on with several overdue people is the ordinary
      // case — would fire a banner per person on the spot, duplicating the
      // in-app nudges the same tick raises. The banner channel already
      // covers a device the user is holding; this one exists for the device
      // they are not.
      //
      // The retraction below still runs: whether or not this episode earns
      // an alarm, the ones it superseded must stop being armed.
      if (scheduledFor.isAfter(clock.now())) {
        await _notifications.createRelationshipCheckIn(
          linkedRelationshipId: relationshipId,
          dueDayKey: derivation.dueDayKey,
          // Content-minimal by design (ADR 0039 Decision 6): notification
          // copy leaves the app sandbox and lands on a lock screen, so it
          // carries the person's name and nothing else about them — no
          // cadence, no recency, nothing from a check-in.
          title: messages.relationshipCheckInReminderTitle(
            relationship.data.title,
          ),
          body: messages.relationshipCheckInReminderBody,
          scheduledFor: scheduledFor,
          category: relationship.meta.categoryId,
        );
      }

      await _notifications.retractRelationshipCheckIns(
        relationshipId,
        exceptId: _notifications.notificationIdForRelationshipCheckIn(
          linkedRelationshipId: relationshipId,
          dueDayKey: derivation.dueDayKey,
        ),
      );
    });
  }

  /// Retracts every open reminder for a person who should no longer be
  /// nudged — un-marked as important, moved to dormant/archived, or deleted.
  ///
  /// Retraction rather than deletion: the rows are synced CRDT state, and
  /// `deletedAt` is the monotonic mark every device converges on. It is also
  /// what cancels the OS alert, which is the part that actually matters here.
  @override
  Future<void> clearFor(String relationshipId) async {
    await _bestEffort(
      'clearFor',
      () => _notifications.retractRelationshipCheckIns(relationshipId),
    );
  }

  /// Honours [RelationshipReminderSink]'s non-throwing contract.
  ///
  /// The caller is an agent wake whose actual job — recomputing the cadence
  /// register — has already committed by the time this runs. Letting a
  /// notification-store failure escape would fail that wake and schedule a
  /// retry of work that already succeeded, to fix an alarm the next daily
  /// tick re-derives from scratch anyway.
  Future<void> _bestEffort(
    String subDomain,
    Future<void> Function() body,
  ) async {
    try {
      await body();
    } catch (error, stackTrace) {
      _logger.error(
        LogDomain.notifications,
        error,
        stackTrace: stackTrace,
        subDomain: 'relationshipReminder.$subDomain',
      );
    }
  }

  /// The due day at [relationshipReminderHour], in local time.
  ///
  /// A [RelationshipCadenceDerivation]'s `dueDayUtc` is a DST-safe *day key*
  /// (UTC
  /// midnight standing for a local calendar day), not an instant — reading it
  /// as one would fire the reminder at the user's UTC offset instead of in
  /// their morning. Rebuilding from its calendar components lands on the
  /// intended local hour whichever side of a DST transition the due day
  /// falls.
  DateTime _reminderInstant(RelationshipCadenceDerivation derivation) {
    final dueDay = derivation.dueDayUtc;
    return DateTime(
      dueDay.year,
      dueDay.month,
      dueDay.day,
      relationshipReminderHour,
    );
  }
}
