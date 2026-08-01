import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_helpers.dart';

void main() {
  group('matrix_stream_helpers', () {
    test(
      'isLikelySyncPayloadText detects valid base64 JSON with runtimeType',
      () {
        final valid = base64.encode(
          utf8.encode(
            json.encode(<String, dynamic>{
              'runtimeType': 'journalEntity',
            }),
          ),
        );
        final invalidJson = base64.encode(utf8.encode('not json'));

        expect(isLikelySyncPayloadText(valid), isTrue);
        expect(isLikelySyncPayloadText(invalidJson), isFalse);
        expect(isLikelySyncPayloadText(''), isFalse);
        expect(isLikelySyncPayloadText('not-base64'), isFalse);
      },
    );

    test('ringBufferAdd enforces max size, evicts oldest', () {
      final buffer = <String>[];
      ringBufferAdd(buffer, 'a', 2);
      ringBufferAdd(buffer, 'b', 2);
      ringBufferAdd(buffer, 'c', 2);

      expect(buffer, ['b', 'c']);
      ringBufferAdd(buffer, 'd', 2);
      expect(buffer, ['c', 'd']);
    });

    test('ignoredReasonFromStatus maps to older/equal/unknown', () {
      expect(ignoredReasonFromStatus('a_gt_a'), 'older');
      expect(ignoredReasonFromStatus('a_gt_b'), 'older');
      expect(ignoredReasonFromStatus('equal'), 'equal');
      expect(ignoredReasonFromStatus('x'), 'unknown');
    });
  });

  group('ringBufferAdd — Glados properties', () {
    glados.Glados2(
      glados.ListAnys(glados.any).listWithLengthInRange(
        0,
        20,
        glados.any.letterOrDigits,
      ),
      glados.IntAnys(glados.any).intInRange(1, 10),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'buffer never exceeds maxSize after N insertions',
      (entries, maxSize) {
        final buffer = <String>[];
        for (final entry in entries) {
          ringBufferAdd(buffer, entry, maxSize);
        }
        expect(
          buffer.length,
          lessThanOrEqualTo(maxSize),
          reason: 'maxSize=$maxSize entries=${entries.length}',
        );
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.ListAnys(glados.any).listWithLengthInRange(
        1,
        20,
        glados.any.letterOrDigits,
      ),
      glados.IntAnys(glados.any).intInRange(1, 10),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'last inserted entry is always the last element of the buffer',
      (entries, maxSize) {
        final buffer = <String>[];
        for (final entry in entries) {
          ringBufferAdd(buffer, entry, maxSize);
        }
        expect(buffer.last, entries.last, reason: 'maxSize=$maxSize');
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.ListAnys(glados.any).listWithLengthInRange(
        1,
        20,
        glados.any.letterOrDigits,
      ),
      glados.IntAnys(glados.any).intInRange(1, 10),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'buffer contains the last min(n, maxSize) inserted entries in order',
      (entries, maxSize) {
        final buffer = <String>[];
        for (final entry in entries) {
          ringBufferAdd(buffer, entry, maxSize);
        }
        final expectedTail = entries.length <= maxSize
            ? entries
            : entries.sublist(entries.length - maxSize);
        expect(buffer, expectedTail, reason: 'maxSize=$maxSize');
      },
      tags: 'glados',
    );
  });
}
