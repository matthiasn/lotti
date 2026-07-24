import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/logic/blocks_cycle_guard.dart';
import 'package:mocktail/mocktail.dart';

import '../widget_test_utils.dart';

/// Unit coverage for [wouldCreateBlocksCycle] as a standalone function
/// (extracted from `PersistenceEntries` so `JournalRepository.updateLinkType`
/// can reuse it too). The 1-hop/2-hop/dedup/self-block scenarios already
/// covered indirectly via `PersistenceEntries.createLink` in
/// `test/logic/persistence_entries_test.dart` are not repeated here beyond a
/// couple of smoke cases — this file's focus is the `excludeLinkId` behavior
/// that only the edit path needs.
void main() {
  late TestGetItMocks mocks;

  setUp(() async {
    mocks = await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  test(
    'a direct self-block is rejected without querying the database',
    () async {
      final result = await wouldCreateBlocksCycle(fromId: 'same', toId: 'same');

      expect(result, isTrue);
      verifyNever(
        () => mocks.journalDb.typedLinksForTaskIds(
          any(),
          types: any(named: 'types'),
        ),
      );
    },
  );

  test('no existing chain closes a cycle', () async {
    when(
      () => mocks.journalDb.typedLinksForTaskIds(
        any(),
        types: any(named: 'types'),
      ),
    ).thenAnswer((_) async => <EntryLink>[]);

    final result = await wouldCreateBlocksCycle(fromId: 'a', toId: 'b');

    expect(result, isFalse);
  });

  test('rejects a 1-hop cycle (b already blocks a)', () async {
    when(
      () => mocks.journalDb.typedLinksForTaskIds({'b'}, types: {'BlocksLink'}),
    ).thenAnswer(
      (_) async => [
        EntryLink.blocks(
          id: 'existing',
          fromId: 'b',
          toId: 'a',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
        ),
      ],
    );

    final result = await wouldCreateBlocksCycle(fromId: 'a', toId: 'b');

    expect(result, isTrue);
  });

  group('excludeLinkId', () {
    test(
      'a direction flip on an existing 2-node blocks edge succeeds — the '
      'edge is not falsely rejected against its own stale row',
      () async {
        // The only existing edge IS the link being edited (id: 'flip-me',
        // a blocks b). Flipping it to (b blocks a) must not see 'flip-me'
        // itself as evidence of a cycle.
        when(
          () => mocks.journalDb.typedLinksForTaskIds(
            {'a'},
            types: {'BlocksLink'},
          ),
        ).thenAnswer(
          (_) async => [
            EntryLink.blocks(
              id: 'flip-me',
              fromId: 'a',
              toId: 'b',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              vectorClock: null,
            ),
          ],
        );

        final result = await wouldCreateBlocksCycle(
          fromId: 'b',
          toId: 'a',
          excludeLinkId: 'flip-me',
        );

        expect(result, isFalse);
      },
    );

    test(
      'without excludeLinkId the same flip is (correctly, for a create) '
      'rejected as a cycle',
      () async {
        when(
          () => mocks.journalDb.typedLinksForTaskIds(
            {'a'},
            types: {'BlocksLink'},
          ),
        ).thenAnswer(
          (_) async => [
            EntryLink.blocks(
              id: 'flip-me',
              fromId: 'a',
              toId: 'b',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              vectorClock: null,
            ),
          ],
        );

        final result = await wouldCreateBlocksCycle(fromId: 'b', toId: 'a');

        expect(result, isTrue);
      },
    );

    test(
      'excludeLinkId only ignores the matching link id, not other edges '
      'from the same source that would still close a genuine cycle',
      () async {
        // 'a' has two outgoing blocks edges: 'flip-me' (a->b, the one being
        // edited) and 'real-edge' (a->c, a genuine, unrelated edge).
        when(
          () => mocks.journalDb.typedLinksForTaskIds(
            {'a'},
            types: {'BlocksLink'},
          ),
        ).thenAnswer(
          (_) async => [
            EntryLink.blocks(
              id: 'flip-me',
              fromId: 'a',
              toId: 'b',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              vectorClock: null,
            ),
            EntryLink.blocks(
              id: 'real-edge',
              fromId: 'a',
              toId: 'c',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              vectorClock: null,
            ),
          ],
        );

        // Would c->a close a cycle, excluding only 'flip-me'? The traversal
        // must still walk 'real-edge' (a->c) and find it closes the loop
        // back to fromId 'c' — proving exclusion is scoped to the one link
        // id, not every edge sharing its source.
        final result = await wouldCreateBlocksCycle(
          fromId: 'c',
          toId: 'a',
          excludeLinkId: 'flip-me',
        );

        expect(result, isTrue);
      },
    );
  });
}
