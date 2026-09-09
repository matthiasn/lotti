import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/widgets/person_avatar_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/person_photo_actions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  final at = DateTime(2026, 8, 13, 14);
  late MockRelationshipRepository relationships;
  late MockJournalRepository journal;
  late List<String> log;

  /// The page the sheet opens over, and whether the sheet was still on the
  /// navigator when the picker ran — it must not be: the picker and the
  /// crop surface open over the page alone.
  late BuildContext pageContext;
  bool? sheetOpenAtPick;

  RelationshipEntry person({String? avatarImageId}) => RelationshipEntry(
    meta: Metadata(
      id: 'rel-1',
      createdAt: at,
      updatedAt: at,
      dateFrom: at,
      dateTo: at,
    ),
    data: RelationshipData(
      title: 'Pip',
      avatarImageId: avatarImageId,
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: at,
        utcOffset: 0,
      ),
    ),
  );

  /// Real flows over fake surfaces: the picker "returns" a fresh id and the
  /// crop surface "commits" a framing, so a row tap runs end to end without
  /// a picker or a sheet.
  PersonPhotoActions fakeActions() => PersonPhotoActions(
    relationships: relationships,
    journal: journal,
    pickImage: () async {
      log.add('pick');
      // With the sheet still up, the page has a route to pop.
      sheetOpenAtPick = Navigator.of(pageContext).canPop();
      return (id: 'image-new', created: true);
    },
    chooseCrop: (imageId, initial) async {
      log.add('crop $imageId');
      return const AvatarCrop(x: 0.2, y: 0.3, scale: 2);
    },
  );

  setUp(() {
    relationships = MockRelationshipRepository();
    journal = MockJournalRepository();
    log = [];
    sheetOpenAtPick = null;
    when(
      () => relationships.updateRelationship(any()),
    ).thenAnswer((_) async => true);
  });

  /// Opens the sheet from a host button the way the page does — through
  /// `showPersonAvatarSheet`, over fake surfaces — and hands back the future
  /// it resolves.
  Future<Future<PersonPhotoOutcome?>> open(
    WidgetTester tester,
    RelationshipEntry entry,
  ) async {
    late Future<PersonPhotoOutcome?> result;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                pageContext = context;
                result = showPersonAvatarSheet(
                  context: context,
                  relationship: entry,
                  actions: fakeActions(),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('a person without a photo is offered only the library, under '
      'the privacy line', (tester) async {
    await open(tester, person());

    expect(find.byKey(const ValueKey('person-photo-privacy')), findsOneWidget);
    expect(
      find.text('Only on your devices · the agent never sees it'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('person-photo-choose')), findsOneWidget);
    expect(find.byKey(const ValueKey('person-photo-adjust')), findsNothing);
    expect(find.byKey(const ValueKey('person-photo-remove')), findsNothing);
  });

  testWidgets('a person with a photo can re-crop it or remove it, and remove '
      'is the destructive row', (tester) async {
    await open(tester, person(avatarImageId: 'image-1'));

    expect(find.byKey(const ValueKey('person-photo-adjust')), findsOneWidget);
    final remove = tester.widget<DsActionRow>(
      find.byKey(const ValueKey('person-photo-remove')),
    );
    expect(remove.tone, DsActionRowTone.destructive);
    expect(find.text('Remove photo'), findsOneWidget);
  });

  testWidgets('choosing closes the sheet first, then runs pick → crop → '
      'write, and resolves to the outcome', (tester) async {
    final result = await open(tester, person());

    await tester.tap(find.byKey(const ValueKey('person-photo-choose')));
    await tester.pumpAndSettle();

    expect(await result, PersonPhotoOutcome.changed);
    expect(log, ['pick', 'crop image-new']);
    expect(
      sheetOpenAtPick,
      isFalse,
      reason:
          'the picker and the crop surface open over the page alone; a sheet '
          'held open under them would reappear for a frame as they close',
    );
    final written =
        verify(
              () => relationships.updateRelationship(captureAny()),
            ).captured.single
            as RelationshipEntry;
    expect(written.data.avatarImageId, 'image-new');
    expect(find.byKey(const ValueKey('person-photo-choose')), findsNothing);
  });

  testWidgets('adjusting closes the sheet, then re-crops the photo the person '
      'already has — no picker — and writes the framing', (tester) async {
    final result = await open(tester, person(avatarImageId: 'image-1'));

    await tester.tap(find.byKey(const ValueKey('person-photo-adjust')));
    await tester.pumpAndSettle();

    expect(await result, PersonPhotoOutcome.changed);
    expect(log, ['crop image-1'], reason: 'adjusting never opens the picker');
    final written =
        verify(
              () => relationships.updateRelationship(captureAny()),
            ).captured.single
            as RelationshipEntry;
    expect(written.data.avatarImageId, 'image-1');
    expect(written.data.avatarCrop, const AvatarCrop(x: 0.2, y: 0.3, scale: 2));
    expect(find.byKey(const ValueKey('person-photo-adjust')), findsNothing);
  });

  testWidgets('removing writes the cleared person and closes the sheet', (
    tester,
  ) async {
    final result = await open(tester, person(avatarImageId: 'image-1'));

    await tester.tap(find.byKey(const ValueKey('person-photo-remove')));
    await tester.pumpAndSettle();

    expect(await result, PersonPhotoOutcome.changed);
    expect(log, isEmpty, reason: 'removing opens nothing');
    final written =
        verify(
              () => relationships.updateRelationship(captureAny()),
            ).captured.single
            as RelationshipEntry;
    expect(written.data.avatarImageId, isNull);
  });

  testWidgets('a refused write closes the sheet reporting failure', (
    tester,
  ) async {
    when(
      () => relationships.updateRelationship(any()),
    ).thenAnswer((_) async => false);
    final result = await open(tester, person(avatarImageId: 'image-1'));

    await tester.tap(find.byKey(const ValueKey('person-photo-remove')));
    await tester.pumpAndSettle();

    expect(await result, PersonPhotoOutcome.failed);
  });

  group('showPersonAvatarSheet', () {
    testWidgets('a refused write is the one outcome the user hears about — '
        'as a toast on the page, after the sheet has closed', (tester) async {
      when(
        () => relationships.updateRelationship(any()),
      ).thenAnswer((_) async => false);
      late Future<PersonPhotoOutcome?> result;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  result = showPersonAvatarSheet(
                    context: context,
                    relationship: person(avatarImageId: 'image-1'),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
          overrides: [
            relationshipRepositoryProvider.overrideWithValue(relationships),
            journalRepositoryProvider.overrideWithValue(journal),
          ],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Photo of Pip'), findsOneWidget);

      // Remove needs no picker, so the production flow runs end to end.
      await tester.tap(find.byKey(const ValueKey('person-photo-remove')));
      await tester.pumpAndSettle();

      expect(await result, PersonPhotoOutcome.failed);
      expect(find.text('Photo of Pip'), findsNothing);
      expect(find.text('Could not save the photo'), findsOneWidget);
    });

    testWidgets(
      'a flow that throws is a failed save to the user — the toast, and no '
      'error escaping the tap',
      (tester) async {
        late Future<PersonPhotoOutcome?> result;
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    result = showPersonAvatarSheet(
                      context: context,
                      relationship: person(),
                      actions: PersonPhotoActions(
                        relationships: relationships,
                        journal: journal,
                        pickImage: () async =>
                            throw StateError('the picker fell over'),
                        chooseCrop: (imageId, initial) async => null,
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('person-photo-choose')));
        await tester.pumpAndSettle();

        expect(await result, PersonPhotoOutcome.failed);
        expect(find.text('Could not save the photo'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('backing out says nothing', (tester) async {
      late Future<PersonPhotoOutcome?> result;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  result = showPersonAvatarSheet(
                    context: context,
                    relationship: person(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
          overrides: [
            relationshipRepositoryProvider.overrideWithValue(relationships),
            journalRepositoryProvider.overrideWithValue(journal),
          ],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10)); // the barrier
      await tester.pumpAndSettle();

      expect(await result, isNull);
      expect(find.text('Could not save the photo'), findsNothing);
    });
  });
}
