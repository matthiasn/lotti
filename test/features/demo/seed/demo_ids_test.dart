import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/demo/seed/demo_ids.dart';
import 'package:lotti/utils/uuid.dart';

void main() {
  group('demoUuid', () {
    test('produces a real UUID, which is what the detail routes require', () {
      // The whole point of the helper: `TasksLocation`/`JournalLocation`
      // gate their detail page on `isUuid`, so a seeded slug id would open
      // nothing at all.
      expect(isUuid(demoUuid('task-air-scrubbers')), isTrue);
      expect(isUuid(demoUuid('note-scrubber-order')), isTrue);
      expect(isUuid(demoUuid('manual-rehearsal-item-0')), isTrue);
    });

    test('is deterministic: the same slug always yields the same id', () {
      // Stability is what lets a reseeded world keep the ids its manifest
      // recorded, and what keeps screenshot fixtures reproducible.
      expect(
        demoUuid('task-air-scrubbers'),
        demoUuid('task-air-scrubbers'),
      );
      expect(
        demoUuid('task-air-scrubbers'),
        'd019db46-b7d6-5941-a6d6-2b76d797e4ce',
        reason:
            'the derivation namespace is fixed forever — changing it silently '
            'orphans every already-seeded demo world',
      );
    });

    test('distinct slugs yield distinct ids', () {
      final slugs = [
        'task-air-scrubbers',
        'task-humidity-spike',
        'note-scrubber-order',
        'time-scrubber-swap',
        'link-a-b',
      ];
      expect(slugs.map(demoUuid).toSet(), hasLength(slugs.length));
    });
  });
}
