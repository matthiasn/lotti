import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/agents/ui/agent_editor_scaffold.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/pages/relationship_editor_page.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/repositories/entry_category_move.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// The person page's own read, answered by the test.
class _FakeDetailController extends RelationshipDetailController {
  _FakeDetailController(this._load) : super('rel-1');

  final Future<RelationshipDetail?> Function() _load;

  @override
  Future<RelationshipDetail?> build() => _load();
}

void main() {
  final testDate = DateTime(2026, 8, 13, 10, 30);

  late MockRelationshipRepository repository;
  late MockEntitiesCacheService cache;
  late List<String> navigated;

  RelationshipEntry person() => RelationshipEntry(
    meta: Metadata(
      id: 'rel-1',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    ),
    data: RelationshipData(
      title: 'Commander Pip Frostbeak',
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 0,
      ),
    ),
  );

  RelationshipDetail detailOf(RelationshipEntry relationship) => (
    relationship: relationship,
    checkIns: const [],
    checkInEntries: const {},
    linkedTasks: const [],
    timelineEntries: const [],
    recordingSummaries: const {},
  );

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    repository = MockRelationshipRepository();
    cache = MockEntitiesCacheService();
    when(() => cache.getCategoryById(any())).thenReturn(null);
    navigated = [];
    beamToNamedOverride = navigated.add;
    await setUpTestGetIt(
      additionalSetup: () =>
          getIt.registerSingleton<EntitiesCacheService>(cache),
    );
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    String? relationshipId,
    Future<RelationshipDetail?> Function()? load,
  }) async {
    tester.view
      ..physicalSize = const Size(900, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        RelationshipEditorPage(relationshipId: relationshipId),
        overrides: [
          relationshipRepositoryProvider.overrideWithValue(repository),
          relationshipAgentServiceProvider.overrideWithValue(
            MockRelationshipAgentService(),
          ),
          journalRepositoryProvider.overrideWithValue(MockJournalRepository()),
          entryCategoryMoveProvider.overrideWithValue(MockEntryCategoryMove()),
          entitiesCacheServiceProvider.overrideWithValue(cache),
          if (relationshipId != null)
            relationshipDetailControllerProvider(relationshipId).overrideWith(
              () => _FakeDetailController(
                load ?? () async => detailOf(person()),
              ),
            ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    "editing is the goal editor's page: its scaffold, the person on the "
    'form, Cancel and Save in the footer',
    (tester) async {
      await pumpPage(tester, relationshipId: 'rel-1');

      expect(find.byType(AgentEditorScaffold), findsOneWidget);
      expect(find.text('Edit person'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Commander Pip Frostbeak'),
        findsOneWidget,
        reason: 'the form edits this person, not a blank one',
      );
      expect(
        find.text('Status'),
        findsOneWidget,
        reason: 'only an edit offers the status picker',
      );
      expect(find.byKey(const ValueKey('person-form-cancel')), findsOneWidget);
      expect(find.byKey(const ValueKey('person-form-save')), findsOneWidget);
      // A page, not a sheet: the editor owns the screen's app bar.
      expect(
        find.descendant(
          of: find.byType(AgentEditorScaffold),
          matching: find.byType(AppBar),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('an untouched edit leaves for the person it edits', (
    tester,
  ) async {
    await pumpPage(tester, relationshipId: 'rel-1');

    await tester.tap(find.byKey(const ValueKey('person-form-cancel')));
    await tester.pumpAndSettle();

    expect(navigated, ['/people/rel-1']);
  });

  testWidgets('a saved edit lands on the person', (tester) async {
    when(
      () => repository.updateRelationship(any()),
    ).thenAnswer((_) async => true);
    await pumpPage(tester, relationshipId: 'rel-1');

    await tester.enterText(
      find.byKey(const ValueKey('person-form-nickname')),
      'Pip',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('person-form-save')));
    await tester.pumpAndSettle();

    final saved =
        verify(
              () => repository.updateRelationship(captureAny()),
            ).captured.single
            as RelationshipEntry;
    expect(saved.data.nickname, 'Pip');
    expect(navigated, ['/people/rel-1']);
  });

  testWidgets(
    'adding someone is the same page; leaving goes back to the list and a '
    'save opens the new person',
    (tester) async {
      when(
        () => repository.createRelationship(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
          id: any(named: 'id'),
        ),
      ).thenAnswer(
        (invocation) async => RelationshipEntry(
          meta: Metadata(
            id: 'rel-new',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
          ),
          data: invocation.namedArguments[#data] as RelationshipData,
        ),
      );
      await pumpPage(tester);

      expect(find.byType(AgentEditorScaffold), findsOneWidget);
      expect(find.text('Add person'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('person-form-cancel')));
      await tester.pumpAndSettle();
      expect(navigated, ['/people']);

      await tester.enterText(
        find.byKey(const ValueKey('person-form-name')),
        'Tilly Snowdrift',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('person-form-save')));
      await tester.pumpAndSettle();
      expect(navigated, ['/people', '/people/rel-new']);
    },
  );

  testWidgets('a refused write keeps the editor open — nothing is lost and '
      'nowhere is opened', (tester) async {
    when(
      () => repository.createRelationship(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
        id: any(named: 'id'),
      ),
    ).thenAnswer((_) async => null);
    await pumpPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('person-form-name')),
      'Tilly Snowdrift',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('person-form-save')));
    await tester.pumpAndSettle();

    expect(navigated, isEmpty);
    expect(find.widgetWithText(TextField, 'Tilly Snowdrift'), findsOneWidget);
  });

  testWidgets('a person who is gone says so instead of spinning, and the '
      'way back still leaves', (tester) async {
    await pumpPage(tester, relationshipId: 'rel-1', load: () async => null);

    expect(find.byType(DesignSystemSpinner), findsNothing);
    expect(find.text('This person is no longer tracked.'), findsOneWidget);
    expect(find.byType(RelationshipForm), findsNothing);
    await tester.tap(find.byType(BackButton));
    expect(navigated, ['/people/rel-1']);
  });

  testWidgets('a read that failed says so instead of spinning', (
    tester,
  ) async {
    await pumpPage(
      tester,
      relationshipId: 'rel-1',
      load: () async => throw StateError('read failed'),
    );

    expect(find.byType(DesignSystemSpinner), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('person-editor-unavailable')))
          .data,
      'Error',
    );
    expect(find.text('This person is no longer tracked.'), findsNothing);
    expect(find.byType(RelationshipForm), findsNothing);
  });

  testWidgets(
    'before the person has read the page holds its title and way back over a '
    'spinner, not an empty form',
    (tester) async {
      final pending = Completer<RelationshipDetail?>();
      tester.view
        ..physicalSize = const Size(900, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const RelationshipEditorPage(relationshipId: 'rel-1'),
          overrides: [
            relationshipRepositoryProvider.overrideWithValue(repository),
            entitiesCacheServiceProvider.overrideWithValue(cache),
            relationshipDetailControllerProvider('rel-1').overrideWith(
              () => _FakeDetailController(() => pending.future),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(DesignSystemSpinner), findsOneWidget);
      expect(find.text('Edit person'), findsOneWidget);
      expect(find.byType(RelationshipForm), findsNothing);
      await tester.tap(find.byType(BackButton));
      expect(navigated, ['/people/rel-1']);
    },
  );
}
