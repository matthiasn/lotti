import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/notifications/model/notification_episode_id.dart';

void main() {
  final v5 = RegExp(
    '^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-'
    r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  String checkIn(String subjectId, String dueDayKey) => notificationEpisodeId(
    kind: NotificationKinds.relationshipCheckIn,
    subjectId: subjectId,
    episodeKey: dueDayKey,
  );

  group('notificationEpisodeId', () {
    test('is the id check-in reminders have always been synced under', () {
      // Pinned to the literal the repository's former per-kind helper
      // produced: rows with this id already sit in notifications.sqlite on
      // synced devices, so the scheme cannot move without orphaning them.
      expect(
        checkIn('rel-1', '2026-09-01'),
        'b9aa11b6-963a-5e19-abf8-f1c9731b7edf',
      );
    });

    test('is episode-scoped, not subject-scoped', () {
      // Two episodes of one person must be two rows: the lifecycle marks are
      // monotonic, so one row per person would let an August dismissal
      // permanently silence September.
      expect(
        checkIn('rel-1', '2026-08-17'),
        isNot(checkIn('rel-1', '2026-09-16')),
      );
    });

    test('is subject-scoped', () {
      expect(
        checkIn('rel-1', '2026-08-17'),
        isNot(checkIn('rel-2', '2026-08-17')),
      );
    });

    test('is kind-scoped, so two kinds never collide on one subject', () {
      expect(
        checkIn('rel-1', '2026-08-17'),
        isNot(
          notificationEpisodeId(
            kind: NotificationKinds.taskOverdue,
            subjectId: 'rel-1',
            episodeKey: '2026-08-17',
          ),
        ),
      );
    });

    test('is a version 5 uuid', () {
      expect(checkIn('rel-1', '2026-08-17'), matches(v5));
    });
  });

  glados.Glados3<String, String, String>(
    glados.any.letterOrDigits,
    glados.any.letterOrDigits,
    glados.any.letterOrDigits,
    glados.ExploreConfig(numRuns: 64),
  ).test(
    'is deterministic, well-formed and sensitive to every component',
    (kind, subjectId, episodeKey) {
      final id = notificationEpisodeId(
        kind: kind,
        subjectId: subjectId,
        episodeKey: episodeKey,
      );

      expect(
        id,
        notificationEpisodeId(
          kind: kind,
          subjectId: subjectId,
          episodeKey: episodeKey,
        ),
      );
      expect(id, matches(v5));
      expect(
        id,
        isNot(
          notificationEpisodeId(
            kind: '$kind!',
            subjectId: subjectId,
            episodeKey: episodeKey,
          ),
        ),
      );
      expect(
        id,
        isNot(
          notificationEpisodeId(
            kind: kind,
            subjectId: subjectId,
            episodeKey: '$episodeKey!',
          ),
        ),
      );
    },
    tags: 'glados',
  );
}
