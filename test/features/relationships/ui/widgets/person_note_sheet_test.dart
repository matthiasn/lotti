import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/relationships/repository/person_timeline_repository.dart';
import 'package:lotti/features/relationships/ui/widgets/person_note_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final at = DateTime(2026, 8, 13, 10);
  late MockPersonTimelineRepository repository;

  Metadata meta(String id, {bool? starred}) => Metadata(
    id: id,
    createdAt: at,
    updatedAt: at,
    dateFrom: at,
    dateTo: at,
    starred: starred,
  );

  final pip = RelationshipEntry(
    meta: meta('pip'),
    data: RelationshipData(
      title: 'Commander Pip Frostbeak',
      nickname: 'Pip',
      status: RelationshipStatus.active(id: 's', createdAt: at, utcOffset: 0),
    ),
  );

  final existing =
      JournalEntity.journalEntry(
            meta: meta('note-1', starred: true),
            entryText: const EntryText(plainText: 'Met at the ice summit.'),
          )
          as JournalEntry;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    repository = MockPersonTimelineRepository();
  });

  Future<void> open(WidgetTester tester, {JournalEntry? note}) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open'),
            onPressed: () =>
                showPersonNoteSheet(context: context, person: pip, note: note),
            child: const Text('open'),
          ),
        ),
        overrides: [
          personTimelineRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
  }

  Finder field() => find.descendant(
    of: find.byKey(const ValueKey('person-note-text')),
    matching: find.byType(EditableText),
  );

  DesignSystemButton save(WidgetTester tester) => tester.widget(
    find.byKey(const ValueKey('person-note-save')),
  );

  testWidgets('a new note: Save waits for words, and saving writes the note '
      'pinned as chosen and closes the sheet', (tester) async {
    when(
      () => repository.createNote(
        person: any(named: 'person'),
        text: any(named: 'text'),
        pinned: any(named: 'pinned'),
      ),
    ).thenAnswer((_) async => existing);
    await open(tester);

    expect(find.text('Note about Pip'), findsOneWidget);
    expect(save(tester).onPressed, isNull);

    await tester.enterText(field(), 'Gift idea: a thermal scarf.');
    await tester.tap(find.byKey(const ValueKey('person-note-pin')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('person-note-save')));
    await tester.pumpAndSettle();

    verify(
      () => repository.createNote(
        person: pip,
        text: 'Gift idea: a thermal scarf.',
        pinned: true,
      ),
    ).called(1);
    expect(find.text('Note about Pip'), findsNothing);
    expect(find.byKey(const ValueKey('person-note-delete')), findsNothing);
  });

  testWidgets('a note that could not be saved keeps the sheet open and says '
      'so', (tester) async {
    when(
      () => repository.createNote(
        person: any(named: 'person'),
        text: any(named: 'text'),
        pinned: any(named: 'pinned'),
      ),
    ).thenAnswer((_) async => null);
    await open(tester);

    await tester.enterText(field(), 'Prefers mornings.');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('person-note-save')));
    await tester.pumpAndSettle();
    verify(
      () => repository.createNote(
        person: any(named: 'person'),
        text: any(named: 'text'),
        pinned: any(named: 'pinned'),
      ),
    ).called(1);

    expect(find.text('Could not save the note.'), findsOneWidget);
    expect(find.text('Note about Pip'), findsOneWidget);
  });

  testWidgets('an existing note opens with its words and its pin, and saving '
      'updates it', (tester) async {
    when(
      () => repository.updateNote(
        any(),
        text: any(named: 'text'),
        pinned: any(named: 'pinned'),
      ),
    ).thenAnswer((_) async => true);
    await open(tester, note: existing);

    expect(find.text('Met at the ice summit.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('person-note-pin')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('person-note-save')));
    await tester.pumpAndSettle();

    verify(
      () => repository.updateNote(
        existing,
        text: 'Met at the ice summit.',
        pinned: false,
      ),
    ).called(1);
  });

  testWidgets('an existing note can be deleted from its sheet', (tester) async {
    when(() => repository.deleteNote(any())).thenAnswer((_) async => true);
    await open(tester, note: existing);

    await tester.tap(find.byKey(const ValueKey('person-note-delete')));
    await tester.pumpAndSettle();

    verify(() => repository.deleteNote(existing)).called(1);
    expect(find.text('Note about Pip'), findsNothing);
  });

  testWidgets('cancelling writes nothing', (tester) async {
    await open(tester);

    await tester.enterText(field(), 'Half a thought');
    await tester.tap(find.byKey(const ValueKey('person-note-cancel')));
    await tester.pumpAndSettle();

    verifyNever(
      () => repository.createNote(
        person: any(named: 'person'),
        text: any(named: 'text'),
        pinned: any(named: 'pinned'),
      ),
    );
    expect(find.text('Note about Pip'), findsNothing);
  });
}
