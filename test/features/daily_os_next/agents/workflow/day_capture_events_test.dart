import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_capture_events.dart';

CaptureEntity _capture(
  String id, {
  String transcript = 'a spoken capture',
  DateTime? capturedAt,
  DateTime? createdAt,
  DateTime? deletedAt,
}) =>
    AgentDomainEntity.capture(
          id: id,
          agentId: 'agent-1',
          transcript: transcript,
          capturedAt: capturedAt ?? DateTime.utc(2026, 6, 4, 8),
          createdAt: createdAt ?? DateTime.utc(2026, 6, 4, 8, 1),
          vectorClock: null,
          deletedAt: deletedAt,
        )
        as CaptureEntity;

void main() {
  group('dayCaptureEvents', () {
    test('projects a capture as an inline event at its submission time', () {
      final events = dayCaptureEvents([_capture('cap-1')]);

      expect(events, hasLength(1));
      final event = events.single;
      expect(event.position.at, DateTime.utc(2026, 6, 4, 8, 1));
      expect(event.position.sourceAt, DateTime.utc(2026, 6, 4, 8));
      expect(event.position.key, 'capture|cap-1');
      expect(event.contentEntryId, 'cap-1');
      expect(event.contentDigest, isNull);
      expect(event.inlineContent, {
        'entryType': 'capture',
        'text': 'a spoken capture',
      });
    });

    test('skips soft-deleted captures', () {
      final events = dayCaptureEvents([
        _capture('cap-1'),
        _capture('cap-2', deletedAt: DateTime.utc(2026, 6, 5)),
      ]);
      expect(events.map((e) => e.contentEntryId), ['cap-1']);
    });

    test('normalizes transcript whitespace so one capture is one line', () {
      final events = dayCaptureEvents([
        _capture('cap-1', transcript: 'first thought\n\nsecond  thought\n'),
      ]);
      expect(
        events.single.inlineContent!['text'],
        'first thought second thought',
      );
    });
  });
}
