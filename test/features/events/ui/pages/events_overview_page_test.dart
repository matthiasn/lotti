import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/chips/active_filter_chip.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/pages/events_overview_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

CategoryDefinition _category(String id, String name, String color) =>
    CategoryDefinition(
      id: id,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      name: name,
      vectorClock: null,
      private: false,
      active: true,
      color: color,
    );

JournalEvent _event(
  String id,
  DateTime date, {
  required String title,
  String categoryId = 'friends',
}) => JournalEvent(
  meta: Metadata(
    id: id,
    createdAt: date,
    updatedAt: date,
    dateFrom: date,
    dateTo: date,
    categoryId: categoryId,
  ),
  data: EventData(title: title, stars: 0, status: EventStatus.completed),
);

void main() {
  late MockJournalDb db;
  late MockEntitiesCacheService cache;
  late MockUpdateNotifications updateNotifications;
  late MockPersistenceLogic persistence;

  final categories = <String, CategoryDefinition>{
    'friends': _category('friends', 'Friends', '#E91E63'),
    'work': _category('work', 'Work', '#2196F3'),
  };

  setUpAll(() {
    registerFallbackValue(<String>[]);
    registerFallbackValue(<bool>[]);
    registerFallbackValue(<int>[]);
    registerFallbackValue(
      const EventData(status: EventStatus.tentative, title: '', stars: 0),
    );
    registerFallbackValue(const EntryText(plainText: ''));
  });

  setUp(() async {
    await getIt.reset();
    db = MockJournalDb();
    cache = MockEntitiesCacheService();
    updateNotifications = MockUpdateNotifications();
    persistence = MockPersistenceLogic();

    when(
      () => updateNotifications.updateStream,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());
    when(
      () => db.linksFromIds(any()),
    ).thenReturn(MockSelectable<LinkedDbEntry>([]));
    when(() => cache.showPrivateEntries).thenReturn(true);
    when(() => cache.sortedCategories).thenReturn(categories.values.toList());
    when(
      () => cache.getCategoryById(any()),
    ).thenAnswer((inv) => categories[inv.positionalArguments.first as String?]);

    getIt
      ..registerSingleton<JournalDb>(db)
      ..registerSingleton<EntitiesCacheService>(cache)
      ..registerSingleton<UpdateNotifications>(updateNotifications)
      ..registerSingleton<PersistenceLogic>(persistence)
      ..registerSingleton<Directory>(Directory.systemTemp);
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await getIt.reset();
  });

  /// Pages over [all] honoring offset/limit + category filter, like the real DB.
  void stubPaged(List<JournalEvent> all) {
    when(
      () => db.getJournalEntities(
        types: any(named: 'types'),
        ids: any(named: 'ids'),
        starredStatuses: any(named: 'starredStatuses'),
        privateStatuses: any(named: 'privateStatuses'),
        flaggedStatuses: any(named: 'flaggedStatuses'),
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((invocation) async {
      final limit = invocation.namedArguments[#limit] as int;
      final offset = invocation.namedArguments[#offset] as int;
      final categoryIds =
          invocation.namedArguments[#categoryIds] as Set<String>?;
      final filtered = categoryIds == null
          ? all
          : all.where((e) => categoryIds.contains(e.meta.categoryId)).toList();
      if (offset >= filtered.length) return <JournalEntity>[];
      final end = (offset + limit).clamp(0, filtered.length);
      return filtered.sublist(offset, end);
    });
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(1280, 900),
  }) async {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: makeTestableWidget2(
          const EventsOverviewPage(),
          mediaQueryData: MediaQueryData(size: size),
        ),
      ),
    );
    // Let the async controller build resolve (query + cover resolution).
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows a loading indicator before events arrive', (tester) async {
    final completer = Completer<List<JournalEntity>>();
    when(
      () => db.getJournalEntities(
        types: any(named: 'types'),
        ids: any(named: 'ids'),
        starredStatuses: any(named: 'starredStatuses'),
        privateStatuses: any(named: 'privateStatuses'),
        flaggedStatuses: any(named: 'flaggedStatuses'),
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) => completer.future);

    await tester.pumpWidget(
      ProviderScope(
        child: makeTestableWidget2(const EventsOverviewPage()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(const []);
    await tester.pump();
  });

  testWidgets('shows an error indicator when the query fails', (tester) async {
    when(
      () => db.getJournalEntities(
        types: any(named: 'types'),
        ids: any(named: 'ids'),
        starredStatuses: any(named: 'starredStatuses'),
        privateStatuses: any(named: 'privateStatuses'),
        flaggedStatuses: any(named: 'flaggedStatuses'),
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenThrow(Exception('boom'));

    await pumpPage(tester);

    expect(find.byIcon(LottiIcons.error), findsOneWidget);
  });

  testWidgets('groups events into Upcoming + year sections with cards', (
    tester,
  ) async {
    stubPaged([
      _event('future', DateTime(2099, 7), title: 'Event future'),
      _event(
        'past',
        DateTime(2020, 3),
        title: 'Event past',
        categoryId: 'work',
      ),
    ]);

    await pumpPage(tester);

    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('2020'), findsOneWidget);
    expect(find.text('Event future'), findsOneWidget);
    expect(find.text('Event past'), findsOneWidget);
    // Nothing narrows the list yet: no filter chips, a resting funnel.
    expect(find.byType(ActiveFilterChip), findsNothing);
  });

  testWidgets('typing in the search field narrows the list', (tester) async {
    stubPaged([
      _event('future', DateTime(2099, 7), title: 'Marathon'),
      _event('past', DateTime(2020, 3), title: 'Launch gala'),
    ]);

    await pumpPage(tester);
    await tester.enterText(find.byType(TextField), 'GALA');
    await tester.pump();
    await tester.pump();

    expect(find.text('Launch gala'), findsOneWidget);
    expect(find.text('Marathon'), findsNothing);

    await tester.tap(find.byIcon(LottiIcons.closeCircled));
    await tester.pump();
    await tester.pump();

    expect(find.text('Marathon'), findsOneWidget);
    expect(find.text('Launch gala'), findsOneWidget);
  });

  testWidgets('a search matching nothing offers to clear it', (tester) async {
    stubPaged([_event('past', DateTime(2020, 3), title: 'Launch gala')]);

    await pumpPage(tester);
    await tester.enterText(find.byType(TextField), 'wedding');
    await tester.pump();
    await tester.pump();

    expect(find.text('No matching events'), findsOneWidget);

    await tester.tap(find.widgetWithText(DesignSystemButton, 'Clear all'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Launch gala'), findsOneWidget);
    expect(find.text('No matching events'), findsNothing);
  });

  testWidgets(
    'the filter narrows by category, and its chip removes the narrowing',
    (tester) async {
      stubPaged([
        _event('future', DateTime(2099, 7), title: 'Event future'),
        _event(
          'past',
          DateTime(2020, 3),
          title: 'Event past',
          categoryId: 'work',
        ),
      ]);

      await pumpPage(tester);
      await tester.tap(find.byIcon(LottiIcons.filter));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      tester
          .widget<DesignSystemSelectionRow>(
            find.byKey(
              const ValueKey('design-system-filter-selection-option-work'),
            ),
          )
          .onTap!();
      await tester.pump();
      tester
          .widget<DesignSystemButton>(
            find.byKey(const ValueKey('design-system-task-filter-apply')),
          )
          .onPressed!();
      await tester.pumpAndSettle();

      // Only the Work (past) event remains; the chip names the narrowing.
      expect(find.text('Event past'), findsOneWidget);
      expect(find.text('Event future'), findsNothing);
      final chip = tester.widget<ActiveFilterChip>(
        find.byType(ActiveFilterChip),
      );
      expect(chip.label, 'Work');
      expect(chip.accentColor, const Color(0xFF2196F3));

      await tester.tap(find.byType(ActiveFilterChip));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ActiveFilterChip), findsNothing);
      expect(find.text('Event future'), findsOneWidget);
    },
  );

  testWidgets('opening an event card beams to its detail route', (
    tester,
  ) async {
    final beamed = <String>[];
    beamToNamedOverride = beamed.add;
    stubPaged([_event('future', DateTime(2099, 7), title: 'Event future')]);

    await pumpPage(tester);
    await tester.tap(find.text('Event future'));
    await tester.pump();

    expect(beamed, ['/events/future']);
  });

  testWidgets('the New event button creates an event and beams to it', (
    tester,
  ) async {
    final beamed = <String>[];
    beamToNamedOverride = beamed.add;
    stubPaged([_event('past', DateTime(2020, 3), title: 'Event past')]);
    when(
      () => persistence.createEventEntry(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer(
      (_) async => _event('new-1', DateTime(2026), title: 'New'),
    );

    await pumpPage(tester);
    await tester.tap(find.byType(DesignSystemFloatingActionButton));
    await tester.pump();
    await tester.pump();

    verify(
      () => persistence.createEventEntry(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).called(1);
    expect(beamed, ['/events/new-1']);
  });

  testWidgets('the launcher dock action creates an event and beams to it', (
    tester,
  ) async {
    final beamed = <String>[];
    beamToNamedOverride = beamed.add;
    stubPaged(const []);
    when(
      () => persistence.createEventEntry(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer(
      (_) async => _event('new-2', DateTime(2026), title: 'New'),
    );

    await pumpPage(tester);
    final action = eventsTabDockAction(
      tester.element(find.byType(EventsOverviewPage)),
    );
    // A bare glyph: the page's title already says what it adds.
    expect(action.worded, isFalse);
    expect(action.label, 'New event');
    action.onPressed();
    await tester.pump();
    await tester.pump();

    expect(beamed, ['/events/new-2']);
  });
}
