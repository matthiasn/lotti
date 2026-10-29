import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/title_search.dart';
import 'package:lotti/features/keyboard/domain/palette_jump.dart';
import 'package:lotti/features/keyboard/service/palette_jumps.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockFts5Db fts;
  late MockJournalDb journalDb;
  late Invocation asked;

  setUp(() {
    fts = MockFts5Db();
    journalDb = MockJournalDb();
    when(
      () => fts.searchTitles(
        any(),
        types: any(named: 'types'),
        categoryIds: any(named: 'categoryIds'),
        includePrivate: any(named: 'includePrivate'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((invocation) async {
      asked = invocation;
      return const [
        TitleMatch(entityId: 't', type: 'Task', title: 'Feed the chicks'),
        TitleMatch(entityId: 'c', type: 'ChecklistItem', title: 'Feed'),
        TitleMatch(
          entityId: 'p',
          type: 'Relationship',
          title: 'Pip',
          fuzzy: true,
        ),
      ];
    });
  });

  void showsPrivate({required bool shows}) => when(
    () => journalDb.getConfigFlag(privateFlag),
  ).thenAnswer((_) async => shows);

  test('finds the kinds it can open, by title, in their own kind', () async {
    showsPrivate(shows: true);
    final search = paletteJumpSearch(
      fts5Db: () => fts,
      journalDb: journalDb,
      categoryIds: () => null,
    );

    expect(await search('feed'), const [
      PaletteJumpTarget(
        entityId: 't',
        kind: PaletteJumpKind.task,
        title: 'Feed the chicks',
      ),
      PaletteJumpTarget(
        entityId: 'p',
        kind: PaletteJumpKind.person,
        title: 'Pip',
        fuzzy: true,
      ),
    ]);
    expect(
      asked.namedArguments[#types],
      paletteJumpKinds.keys.toSet(),
      reason: 'only the kinds a jump can open are asked for',
    );
  });

  test('honours private mode and the categories it is given', () async {
    showsPrivate(shows: false);
    final search = paletteJumpSearch(
      fts5Db: () => fts,
      journalDb: journalDb,
      categoryIds: () => {'colony'},
    );

    await search('feed');

    expect(asked.namedArguments[#includePrivate], isFalse);
    expect(asked.namedArguments[#categoryIds], {'colony'});
  });

  test('a world without an index finds nothing', () async {
    final search = paletteJumpSearch(
      fts5Db: () => null,
      journalDb: journalDb,
      categoryIds: () => null,
    );

    expect(await search('feed'), isEmpty);
  });

  test('each kind opens where it lives; a task by its id', () {
    final nav = MockNavService();
    PaletteJumpTarget target(PaletteJumpKind kind) =>
        PaletteJumpTarget(entityId: 'id-1', kind: kind, title: 'x');

    openPaletteJump(nav, target(PaletteJumpKind.task));
    verify(() => nav.openTask('id-1')).called(1);

    for (final (kind, route) in [
      (PaletteJumpKind.entry, '/journal/id-1'),
      (PaletteJumpKind.project, '/projects/id-1'),
      (PaletteJumpKind.event, '/events/id-1'),
      (PaletteJumpKind.person, '/people/id-1'),
    ]) {
      openPaletteJump(nav, target(kind));
      verify(() => nav.beamToNamed(route)).called(1);
    }
  });
}
