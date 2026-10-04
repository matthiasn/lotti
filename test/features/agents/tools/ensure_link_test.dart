import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/agents/tools/ensure_link.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockPersistenceLogic persistenceLogic;
  late MockJournalDb journalDb;

  EntryLink link({DateTime? deletedAt}) => EntryLink.basic(
    id: 'link',
    fromId: 'from',
    toId: 'to',
    createdAt: DateTime(2026, 3, 17),
    updatedAt: DateTime(2026, 3, 17),
    vectorClock: null,
    deletedAt: deletedAt,
  );

  Future<bool> ensure() => ensureLink(
    persistenceLogic: persistenceLogic,
    journalDb: journalDb,
    fromId: 'from',
    toId: 'to',
  );

  void stubWrite({required bool wrote}) => when(
    () => persistenceLogic.createLink(fromId: 'from', toId: 'to'),
  ).thenAnswer((_) async => wrote);

  void stubStored(List<EntryLink> links) => when(
    () => journalDb.linksBetween(
      'from',
      'to',
      type: entryLinkTypeDbName(EntryLinkType.basic),
    ),
  ).thenAnswer((_) async => links);

  setUp(() {
    persistenceLogic = MockPersistenceLogic();
    journalDb = MockJournalDb();
  });

  test('a link written is live, without reading the stored links', () async {
    stubWrite(wrote: true);

    expect(await ensure(), isTrue);
    verifyNever(
      () => journalDb.linksBetween(any(), any(), type: any(named: 'type')),
    );
  });

  test('a write that wrote nothing over a live link is no failure', () async {
    stubWrite(wrote: false);
    stubStored([link()]);

    expect(await ensure(), isTrue);
  });

  test('a write that wrote nothing, with only a removed link stored, '
      'leaves no link live', () async {
    stubWrite(wrote: false);
    stubStored([link(deletedAt: DateTime(2026, 3, 18))]);

    expect(await ensure(), isFalse);
  });
}
