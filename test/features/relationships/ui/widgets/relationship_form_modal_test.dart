import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final testDate = DateTime(2026, 8, 13, 10, 30);

  late MockRelationshipRepository mockRepository;
  late MockRelationshipAgentService mockAgentService;

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

  setUpAll(() {
    final fallbackData = RelationshipData(
      title: 'fallback',
      status: RelationshipStatus.active(
        id: 'fallback-status',
        createdAt: testDate,
        utcOffset: 0,
      ),
    );
    registerFallbackValue(fallbackData);
    registerFallbackValue(
      RelationshipEntry(
        meta: Metadata(
          id: 'fallback',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
        ),
        data: fallbackData,
      ),
    );
  });

  setUp(() {
    mockRepository = MockRelationshipRepository();
    mockAgentService = MockRelationshipAgentService();
    when(
      () => mockAgentService.ensureAgentForRelationship(any()),
    ).thenAnswer((invocation) async => throw StateError('unstubbed identity'));
  });

  Widget buildForm({RelationshipEntry? initial}) =>
      makeTestableWidgetWithScaffold(
        RelationshipForm(initial: initial),
        overrides: [
          relationshipRepositoryProvider.overrideWithValue(mockRepository),
          relationshipAgentServiceProvider.overrideWithValue(mockAgentService),
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

  testWidgets(
    'saving an IMPORTANT person lazily mints their agent — the consent '
    'switch is the trigger (ADR 0059 Decision 2)',
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

      when(
        () => mockAgentService.ensureAgentForRelationship(any()),
      ).thenAnswer((_) async => throw StateError('identity unused'));

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Anna Example');
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final entry =
          verify(
                () => mockAgentService.ensureAgentForRelationship(
                  captureAny(),
                ),
              ).captured.single
              as RelationshipEntry;
      expect(entry.data.important, isTrue);
    },
  );

  testWidgets(
    'saving a person who is NOT important never touches the agent layer',
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
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      verifyNever(() => mockAgentService.ensureAgentForRelationship(any()));
    },
  );

  testWidgets(
    'an agent-wiring failure never fails the save the user watched '
    'succeed',
    (tester) async {
      // The default stub above throws; the save must still pop cleanly.
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
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.byType(RelationshipForm), findsNothing);
    },
  );

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
  });

  group('error toasts', () {
    testWidgets('shows a toast when create returns null', (tester) async {
      when(
        () => mockRepository.createRelationship(
          data: any(named: 'data'),
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
        findsOne,
      );
    });

    testWidgets('shows a toast when create throws', (tester) async {
      when(
        () => mockRepository.createRelationship(
          data: any(named: 'data'),
        ),
      ).thenThrow(Exception('db locked'));

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Anna');
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save this person. Please try again.'),
        findsOne,
      );
    });

    testWidgets('shows a toast when update returns false', (tester) async {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenAnswer((_) async => false);

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
          status: RelationshipStatus.active(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      );

      await tester.pumpWidget(buildForm(initial: initial));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the changes. Please try again.'),
        findsOne,
      );
    });

    testWidgets('shows a toast when update throws', (tester) async {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenThrow(Exception('db locked'));

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
          status: RelationshipStatus.active(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      );

      await tester.pumpWidget(buildForm(initial: initial));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the changes. Please try again.'),
        findsOne,
      );
    });
  });

  group('error toasts', () {
    testWidgets('shows a toast when create returns null', (tester) async {
      when(
        () => mockRepository.createRelationship(
          data: any(named: 'data'),
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
        findsOne,
      );
    });

    testWidgets('shows a toast when create throws', (tester) async {
      when(
        () => mockRepository.createRelationship(
          data: any(named: 'data'),
        ),
      ).thenThrow(Exception('db locked'));

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Anna');
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save this person. Please try again.'),
        findsOne,
      );
    });

    testWidgets('shows a toast when update returns false', (tester) async {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenAnswer((_) async => false);

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
          status: RelationshipStatus.active(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      );

      await tester.pumpWidget(buildForm(initial: initial));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the changes. Please try again.'),
        findsOne,
      );
    });

    testWidgets('shows a toast when update throws', (tester) async {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenThrow(Exception('db locked'));

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
          status: RelationshipStatus.active(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      );

      await tester.pumpWidget(buildForm(initial: initial));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the changes. Please try again.'),
        findsOne,
      );
    });
  });
}
