import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/projection/input_events.dart';
import 'package:lotti/features/agents/workflow/prompt_record.dart';

void main() {
  group('prompt record codec', () {
    test('round-trips head, tail and the reconstruction marker', () {
      final until = EventPosition(
        at: DateTime.utc(2026, 6, 4, 10),
        sourceAt: DateTime.utc(2026, 6, 4, 9),
        key: 'e1|link-1',
      );
      final encoded = encodePromptRecord(
        head: 'HEAD\n## Task Log\n',
        tail: '\n## Current Task Context\nTAIL',
        summaryId: 'sum-1',
        until: until,
      );
      final decoded = decodePromptRecord(encoded)!;

      expect(decoded.head, 'HEAD\n## Task Log\n');
      expect(decoded.tail, '\n## Current Task Context\nTAIL');
      expect(decoded.summaryId, 'sum-1');
      expect(decoded.until, until);
    });

    test('round-trips null marker parts (no checkpoint, empty tail)', () {
      final decoded = decodePromptRecord(
        encodePromptRecord(head: 'H', tail: 'T'),
      )!;
      expect(decoded.summaryId, isNull);
      expect(decoded.until, isNull);
    });

    test('returns null for legacy text blobs and malformed payloads', () {
      expect(decodePromptRecord({'text': 'a legacy full prompt'}), isNull);
      expect(
        decodePromptRecord({'promptFormat': 'v2', 'head': 'only-head'}),
        isNull,
      );
      expect(decodePromptRecord({'promptFormat': 'v1'}), isNull);
    });

    test('survives a JSON round-trip (sync serialization shape)', () {
      final until = EventPosition(
        at: DateTime.utc(2026, 6, 4, 10),
        sourceAt: DateTime.utc(2026, 6, 4, 10),
        key: 'k',
      );
      final encoded = encodePromptRecord(
        head: 'H',
        tail: 'T',
        summaryId: 's',
        until: until,
      );
      // The payload persists as JSON: a real encode/decode cycle proves the
      // record contains only plain JSON types and survives intact.
      final reparsed = (jsonDecode(jsonEncode(encoded)) as Map)
          .cast<String, Object?>();
      final decoded = decodePromptRecord(reparsed)!;
      expect(decoded.until, until);
      expect(decoded.head, 'H');
      expect(decoded.tail, 'T');
      expect(decoded.summaryId, 's');
    });
  });
}
