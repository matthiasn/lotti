import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/pipeline/metrics_utils.dart';

Map<String, int> build({
  int dbApplied = 0,
  int dbIgnoredByVectorClock = 0,
  int conflictsCreated = 0,
  Map<String, int> droppedByType = const <String, int>{},
  List<String> lastIgnored = const <String>[],
}) => MetricsUtils.buildSnapshot(
  dbApplied: dbApplied,
  dbIgnoredByVectorClock: dbIgnoredByVectorClock,
  conflictsCreated: conflictsCreated,
  droppedByType: droppedByType,
  lastIgnored: lastIgnored,
);

void main() {
  group('MetricsUtils.buildSnapshot', () {
    test('carries the scalar counters through unchanged', () {
      final snap = build(
        dbApplied: 7,
        dbIgnoredByVectorClock: 3,
        conflictsCreated: 1,
      );

      expect(snap['dbApplied'], 7);
      expect(snap['dbIgnoredByVectorClock'], 3);
      expect(snap['conflictsCreated'], 1);
    });

    test('flattens droppedByType under a prefixed key per type', () {
      final snap = build(
        droppedByType: const {'journalEntity': 4, 'entryLink': 2},
      );

      expect(snap['droppedByType.journalEntity'], 4);
      expect(snap['droppedByType.entryLink'], 2);
    });

    test('reports lastIgnored as a count plus one length per 1-based slot', () {
      // The snapshot is Map<String, int>, so the diagnostics ring buffer is
      // carried as entry *lengths* — the panel shows how many were ignored and
      // roughly how big each payload was, not the payloads themselves.
      final snap = build(lastIgnored: const ['abc', 'de']);

      expect(snap['lastIgnoredCount'], 2);
      expect(snap['lastIgnored.1'], 3);
      expect(snap['lastIgnored.2'], 2);
      expect(snap.containsKey('lastIgnored.0'), isFalse);
    });

    test('an empty snapshot still carries every scalar key at zero', () {
      final snap = build();

      expect(snap['dbApplied'], 0);
      expect(snap['dbIgnoredByVectorClock'], 0);
      expect(snap['conflictsCreated'], 0);
      expect(snap['lastIgnoredCount'], 0);
      expect(
        snap.keys.where((k) => k.startsWith('droppedByType.')),
        isEmpty,
      );
    });
  });

  glados.Glados(
    glados.any.listWithLengthInRange(0, 6, glados.any.letters),
  ).test('every ignored entry reaches the snapshot exactly once', (ignored) {
    final snap = build(lastIgnored: ignored);

    expect(snap['lastIgnoredCount'], ignored.length);
    for (var i = 0; i < ignored.length; i++) {
      expect(snap['lastIgnored.${i + 1}'], ignored[i].length);
    }
  }, tags: 'glados');
}
