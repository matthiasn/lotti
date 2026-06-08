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
    test('projects metadata as a DEFERRED inline event at its submission '
        'time (no transcript loaded)', () {
      final events = dayCaptureEvents([captureEventMeta(_capture('cap-1'))]);

      expect(events, hasLength(1));
      final event = events.single;
      expect(event.position.at, DateTime.utc(2026, 6, 4, 8, 1));
      expect(event.position.sourceAt, DateTime.utc(2026, 6, 4, 8));
      expect(event.position.key, 'capture|cap-1');
      expect(event.contentEntryId, 'cap-1');
      expect(event.sourceCreatedAt, DateTime.utc(2026, 6, 4, 8));
      // Deferred: content is resolved lazily, so neither digest nor inline
      // content is carried up front.
      expect(event.deferredInline, isTrue);
      expect(event.contentDigest, isNull);
      expect(event.inlineContent, isNull);
    });

    test('preserves submission order across multiple captures', () {
      final events = dayCaptureEvents([
        captureEventMeta(_capture('cap-1')),
        captureEventMeta(_capture('cap-2')),
      ]);
      expect(events.map((e) => e.contentEntryId), ['cap-1', 'cap-2']);
      expect(events.every((e) => e.deferredInline), isTrue);
    });
  });

  group('captureEventMeta', () {
    test('extracts id and the two ordering timestamps', () {
      final meta = captureEventMeta(_capture('cap-1'));
      expect(meta.id, 'cap-1');
      expect(meta.createdAt, DateTime.utc(2026, 6, 4, 8, 1));
      expect(meta.capturedAt, DateTime.utc(2026, 6, 4, 8));
    });
  });

  group('captureInlineContent', () {
    test(
      'tags the entry as a capture and normalizes transcript whitespace',
      () {
        expect(
          captureInlineContent('first thought\n\nsecond  thought\n'),
          {'entryType': 'capture', 'text': 'first thought second thought'},
        );
      },
    );
  });
}
