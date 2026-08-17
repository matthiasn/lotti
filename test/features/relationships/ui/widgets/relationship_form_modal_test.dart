import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/categories/ui/widgets/category_field.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/entity_factories.dart';

void main() {
  final testDate = DateTime(2026, 8, 13, 10, 30);

  late MockRelationshipRepository mockRepository;
  late MockRelationshipAgentService mockAgentService;
  late MockJournalRepository mockJournalRepository;
  late MockEntitiesCacheService mockCacheService;

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

  setUp(() async {
    mockRepository = MockRelationshipRepository();
    mockAgentService = MockRelationshipAgentService();
    mockJournalRepository = MockJournalRepository();
    when(
      () => mockAgentService.ensureAgentForRelationship(any()),
    ).thenAnswer((invocation) async => throw StateError('unstubbed identity'));
    when(
      () => mockJournalRepository.updateCategoryId(
        any(),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => true);
    // CategoryField (rendered by the form) reads the category name through
    // `getIt<EntitiesCacheService>()`; default the lookup to "no category".
    mockCacheService = MockEntitiesCacheService();
    when(() => mockCacheService.getCategoryById(any())).thenReturn(null);
    await setUpTestGetIt(
      additionalSetup: () =>
          getIt.registerSingleton<EntitiesCacheService>(mockCacheService),
    );
  });

  tearDown(tearDownTestGetIt);

  Widget buildForm({RelationshipEntry? initial}) =>
      makeTestableWidgetWithScaffold(
        RelationshipForm(initial: initial),
        overrides: [
          relationshipRepositoryProvider.overrideWithValue(mockRepository),
          relationshipAgentServiceProvider.overrideWithValue(mockAgentService),
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
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
      ),
    );
  });

  testWidgets(
    'persists name, nickname, importance, and the picked cadence preset',
    (tester) async {
      when(
        () => mockRepository.createRelationship(
          data: any(named: 'data'),
          categoryId: any(named: 'categoryId'),
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
                  categoryId: any(named: 'categoryId'),
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
      ),
    );
  });

  testWidgets(
    'saving an IMPORTANT person lazily mints their agent — the consent '
    'switch is the trigger (ADR 0059 Decision 2)',
    (tester) async {
      when(
        () => mockRepository.createRelationship(
          data: any(named: 'data'),
          categoryId: any(named: 'categoryId'),
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
          categoryId: any(named: 'categoryId'),
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
          categoryId: any(named: 'categoryId'),
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
        categoryId: any(named: 'categoryId'),
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
                categoryId: any(named: 'categoryId'),
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

    // Regression: every collaborator was pulled through `ref.read` *after*
    // awaiting the save. Saving pops the sheet, so on a slow write the element
    // was already gone and Riverpod threw "Using ref when a widget is about to
    // or has been unmounted is unsafe" — aborting the save's tail, with the
    // observed symptom "Failed to save relationship" and the agent (or the
    // category change) silently never written.
    testWidgets('finishes the save when the sheet unmounts mid-write', (
      tester,
    ) async {
      final saved = Completer<bool>();
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenAnswer((_) => saved.future);
      when(
        () => mockAgentService.ensureAgentForRelationship(any()),
      ).thenAnswer((_) async => makeTestIdentity(agentId: 'agent-1'));

      await tester.pumpWidget(buildForm(initial: existing()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(DesignSystemButton, 'Save'),
      );
      await tester.tap(find.widgetWithText(DesignSystemButton, 'Save'));
      await tester.pump();

      // The sheet disappears while the repository write is still in flight.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      saved.complete(true);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      verify(
        () => mockAgentService.ensureAgentForRelationship(any()),
      ).called(1);
    });

    // The category lives on metadata, not the payload, so it takes a second
    // write through the journal path. Nothing else in this suite reaches that
    // branch, and it is the one the unmount crash aborted.
    testWidgets('routes a changed category through the journal repository', (
      tester,
    ) async {
      when(
        () => mockJournalRepository.updateCategoryId(
          any(),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildForm(initial: existing()));
      await tester.pumpAndSettle();

      // Drive the field's callback rather than its picker: the picker is a
      // nested modal with its own harness, and the branch under test is what
      // the form does with the chosen category.
      tester
          .widget<CategoryField>(find.byType(CategoryField))
          .onSave(
            CategoryDefinition(
              id: 'category-7',
              name: 'People',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
              private: false,
              active: true,
              color: '#FFFFFF',
            ),
          );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(DesignSystemButton, 'Save'),
      );
      await tester.tap(find.widgetWithText(DesignSystemButton, 'Save'));
      await tester.pumpAndSettle();

      verify(
        () => mockJournalRepository.updateCategoryId(
          'rel-1',
          categoryId: 'category-7',
        ),
      ).called(1);
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

  group('error toasts', () {
    testWidgets('shows a toast when create returns null', (tester) async {
      when(
        () => mockRepository.createRelationship(
          data: any(named: 'data'),
          categoryId: any(named: 'categoryId'),
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

  group('the category leg of an edit', () {
    /// A person filed under `cat-1`, so the field renders its clear button.
    RelationshipEntry categorized() {
      when(() => mockCacheService.getCategoryById('cat-1')).thenReturn(
        CategoryDefinition(
          id: 'cat-1',
          name: 'Family',
          private: false,
          active: true,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        ),
      );
      return RelationshipEntry(
        meta: Metadata(
          id: 'rel-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          categoryId: 'cat-1',
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
    }

    /// Clears the category through the field's × affordance, then saves.
    Future<void> clearCategoryAndSave(WidgetTester tester) async {
      await tester.pumpWidget(buildForm(initial: categorized()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('routes the cleared category through the journal path — a '
        'freezed copyWith cannot null the field', (tester) async {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenAnswer((_) async => true);

      await clearCategoryAndSave(tester);

      verify(
        () => mockJournalRepository.updateCategoryId('rel-1', categoryId: null),
      ).called(1);
      expect(
        find.text('Could not save the changes. Please try again.'),
        findsNothing,
      );
    });

    testWidgets('a failed category write is reported instead of being '
        'swallowed — the payload landed but the category did not, and '
        'reporting success would leave nothing to retry', (tester) async {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockJournalRepository.updateCategoryId(
          any(),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => false);

      await clearCategoryAndSave(tester);

      expect(
        find.text('Could not save the changes. Please try again.'),
        findsOne,
      );
    });

    testWidgets('the agent is still wired when only the category leg '
        'failed — importance and cadence did persist', (tester) async {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockJournalRepository.updateCategoryId(
          any(),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => false);
      when(
        () => mockAgentService.ensureAgentForRelationship(any()),
      ).thenAnswer((_) async => throw StateError('unstubbed identity'));

      await tester.pumpWidget(buildForm(initial: categorized()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      verify(
        () => mockAgentService.ensureAgentForRelationship(any()),
      ).called(1);
    });
  });
}
