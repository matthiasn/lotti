import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final testDate = DateTime(2026, 8, 13, 10, 30);

  late MockRelationshipRepository mockRepository;

  RelationshipEntry createdEntry(RelationshipData data) => RelationshipEntry(
    meta: Metadata(
      id: 'rel-created',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    ),
    data: data,
  );

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockRepository = MockRelationshipRepository();
  });

  Widget buildForm({RelationshipEntry? initial}) =>
      makeTestableWidgetWithScaffold(
        RelationshipForm(initial: initial),
        overrides: [
          relationshipRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

  testWidgets('does not persist when the name is empty', (tester) async {
    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    verifyNever(
      () => mockRepository.createRelationship(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
        trackingStartedAt: any(named: 'trackingStartedAt'),
      ),
    );
  });

  testWidgets(
    'persists name, nickname, importance, and the picked cadence preset',
    (tester) async {
      when(
        () => mockRepository.createRelationship(
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (invocation) async => createdEntry(
          invocation.namedArguments[#data] as RelationshipData,
        ),
      );

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Anna Example');
      await tester.enterText(find.byType(TextField).at(1), 'Sis');
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Every two weeks'));
      await tester.tap(find.text('Every two weeks'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final data =
          verify(
                () => mockRepository.createRelationship(
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as RelationshipData;
      expect(data.title, 'Anna Example');
      expect(data.nickname, 'Sis');
      expect(data.important, isTrue);
      expect(data.checkInCadenceDays, 14);
      expect(data.status, isA<RelationshipActive>());
    },
  );

  testWidgets('a refused create reports it and keeps what was typed', (
    tester,
  ) async {
    when(
      () => mockRepository.createRelationship(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
        trackingStartedAt: any(named: 'trackingStartedAt'),
      ),
    ).thenAnswer((_) async => null);

    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Anna');
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save this person. Please try again.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'Anna'), findsOneWidget);
  });

  testWidgets('a create that throws reports the create-mode failure', (
    tester,
  ) async {
    when(
      () => mockRepository.createRelationship(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
        trackingStartedAt: any(named: 'trackingStartedAt'),
      ),
    ).thenThrow(Exception('db gone'));

    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Anna');
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // The create-mode copy, not the edit-mode one.
    expect(
      find.text('Could not save this person. Please try again.'),
      findsOneWidget,
    );
    expect(
      find.text('Could not save the changes. Please try again.'),
      findsNothing,
    );
  });

  testWidgets('Cancel closes without persisting anything', (tester) async {
    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Anna');
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(
      () => mockRepository.createRelationship(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
        trackingStartedAt: any(named: 'trackingStartedAt'),
      ),
    );
  });

  testWidgets('cadence defaults to none when nothing is picked', (
    tester,
  ) async {
    when(
      () => mockRepository.createRelationship(
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (invocation) async => createdEntry(
        invocation.namedArguments[#data] as RelationshipData,
      ),
    );

    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Ben');
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final data =
        verify(
              () => mockRepository.createRelationship(
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as RelationshipData;
    expect(data.checkInCadenceDays, isNull);
    expect(data.important, isFalse);
    expect(data.nickname, isNull);
  });

  group('edit mode', () {
    RelationshipEntry existing({int? cadenceDays = 14}) => RelationshipEntry(
      meta: Metadata(
        id: 'rel-1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      ),
      data: RelationshipData(
        title: 'Anna',
        nickname: 'Sis',
        important: true,
        checkInCadenceDays: cadenceDays,
        status: RelationshipStatus.active(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      ),
    );

    setUp(() {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenAnswer((_) async => true);
    });

    testWidgets('prefills the person and saves edited fields', (tester) async {
      await tester.pumpWidget(buildForm(initial: existing()));
      await tester.pumpAndSettle();

      // Prefilled from the entity.
      expect(find.widgetWithText(TextField, 'Anna'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Sis'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Anna Example');
      await tester.ensureVisible(find.text('Monthly'));
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final updated =
          verify(
                () => mockRepository.updateRelationship(captureAny()),
              ).captured.single
              as RelationshipEntry;
      expect(updated.id, 'rel-1');
      expect(updated.data.title, 'Anna Example');
      expect(updated.data.checkInCadenceDays, 30);
      // Untouched fields survive the round-trip.
      expect(updated.data.nickname, 'Sis');
      expect(updated.data.important, isTrue);
      // Status untouched: same instance, no history entry.
      expect(updated.data.status.id, 'status-1');
      expect(updated.data.statusHistory, isEmpty);
    });

    testWidgets(
      'changing the status mints a new one and archives the old to history',
      (tester) async {
        await tester.pumpWidget(buildForm(initial: existing()));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Dormant'));
        await tester.tap(find.text('Dormant'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        final updated =
            verify(
                  () => mockRepository.updateRelationship(captureAny()),
                ).captured.single
                as RelationshipEntry;
        expect(updated.data.status, isA<RelationshipDormant>());
        expect(updated.data.status.id, isNot('status-1'));
        expect(updated.data.statusHistory, hasLength(1));
        expect(updated.data.statusHistory.single.id, 'status-1');
      },
    );

    testWidgets('does not persist when the name is cleared', (tester) async {
      await tester.pumpWidget(buildForm(initial: existing()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      verifyNever(() => mockRepository.updateRelationship(any()));
    });

    testWidgets('archiving mints an archived status', (tester) async {
      await tester.pumpWidget(buildForm(initial: existing()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Archived'));
      await tester.tap(find.text('Archived'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final updated =
          verify(
                () => mockRepository.updateRelationship(captureAny()),
              ).captured.single
              as RelationshipEntry;
      expect(updated.data.status, isA<RelationshipArchived>());
      expect(updated.data.statusHistory.single.id, 'status-1');
    });

    testWidgets(
      "the picker opens on the person's current kind, so an untouched save "
      'keeps it',
      (tester) async {
        final kinds = <String, RelationshipStatus>{
          'status-dormant': RelationshipStatus.dormant(
            id: 'status-dormant',
            createdAt: testDate,
            utcOffset: 0,
          ),
          'status-archived': RelationshipStatus.archived(
            id: 'status-archived',
            createdAt: testDate,
            utcOffset: 0,
          ),
        };

        for (final entry in kinds.entries) {
          final base = existing();
          await tester.pumpWidget(
            buildForm(
              initial: base.copyWith(
                data: base.data.copyWith(status: entry.value),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Save'));
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();

          final updated =
              verify(
                    () => mockRepository.updateRelationship(captureAny()),
                  ).captured.single
                  as RelationshipEntry;
          // The kind round-tripped rather than resetting to active, so no
          // new status was minted and nothing was pushed to history.
          expect(updated.data.status.id, entry.key, reason: entry.key);
          expect(updated.data.statusHistory, isEmpty, reason: entry.key);

          // Pumping a fresh tree next round would hit the popped navigator.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets('a refused update reports it and keeps the edits', (
      tester,
    ) async {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(buildForm(initial: existing()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Anna Example');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the changes. Please try again.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, 'Anna Example'),
        findsOneWidget,
      );
    });

    testWidgets('an update that throws reports the edit-mode failure', (
      tester,
    ) async {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenThrow(Exception('db gone'));

      await tester.pumpWidget(buildForm(initial: existing()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // The edit-mode copy, not the create-mode one.
      expect(
        find.text('Could not save the changes. Please try again.'),
        findsOneWidget,
      );
      expect(
        find.text('Could not save this person. Please try again.'),
        findsNothing,
      );
    });
  });

  group('contact channels', () {
    setUp(() {
      when(
        () => mockRepository.createRelationship(
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (invocation) async => createdEntry(
          invocation.namedArguments[#data] as RelationshipData,
        ),
      );
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenAnswer((_) async => true);
    });

    testWidgets('an added channel persists with value and label', (
      tester,
    ) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Anna');
      await tester.ensureVisible(find.text('Add channel'));
      await tester.tap(find.text('Add channel'));
      await tester.pumpAndSettle();

      // Field order: name, nickname, then the new row's value and label.
      await tester.enterText(
        find.byType(TextField).at(2),
        ' +49 151 1234567 ',
      );
      await tester.enterText(find.byType(TextField).at(3), 'Personal');

      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final data =
          verify(
                () => mockRepository.createRelationship(
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as RelationshipData;
      expect(data.contactChannels, hasLength(1));
      final channel = data.contactChannels.single;
      // Default type; value trimmed; label kept.
      expect(channel.type, ContactChannelType.mobile);
      expect(channel.value, '+49 151 1234567');
      expect(channel.label, 'Personal');
    });

    testWidgets('changing a channel type updates its input and persists', (
      tester,
    ) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Anna');
      await tester.ensureVisible(find.text('Add channel'));
      await tester.tap(find.text('Add channel'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byType(DropdownButtonFormField<ContactChannelType>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Messaging').last);
      await tester.pumpAndSettle();

      final valueField = tester.widget<TextField>(
        find.byType(TextField).at(2),
      );
      expect(valueField.keyboardType, TextInputType.text);
      await tester.enterText(find.byType(TextField).at(2), '@anna');

      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final data =
          verify(
                () => mockRepository.createRelationship(
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as RelationshipData;
      expect(data.contactChannels.single.type, ContactChannelType.messaging);
      expect(data.contactChannels.single.value, '@anna');
    });

    testWidgets('a channel row left empty never persists', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Anna');
      await tester.ensureVisible(find.text('Add channel'));
      await tester.tap(find.text('Add channel'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final data =
          verify(
                () => mockRepository.createRelationship(
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as RelationshipData;
      expect(data.contactChannels, isEmpty);
    });

    testWidgets('edit mode prefills channels and removing one persists', (
      tester,
    ) async {
      final initial = RelationshipEntry(
        meta: Metadata(
          id: 'rel-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
        ),
        data: RelationshipData(
          title: 'Anna',
          contactChannels: const [
            ContactChannel(
              type: ContactChannelType.email,
              value: 'anna@example.com',
            ),
          ],
          status: RelationshipStatus.active(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      );

      await tester.pumpWidget(buildForm(initial: initial));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextField, 'anna@example.com'),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byIcon(Icons.remove_circle_outline_rounded),
      );
      await tester.tap(find.byIcon(Icons.remove_circle_outline_rounded));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final updated =
          verify(
                () => mockRepository.updateRelationship(captureAny()),
              ).captured.single
              as RelationshipEntry;
      expect(updated.data.contactChannels, isEmpty);
    });
  });
}
