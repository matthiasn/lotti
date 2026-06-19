import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/events/state/events_controller.dart';
import 'package:lotti/features/events/ui/pages/events_overview_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

ResolvedEvent _resolved({
  required String id,
  required DateTime date,
  String categoryId = 'friends',
  String categoryName = 'Friends',
  Color color = const Color(0xFFE91E63),
}) {
  return ResolvedEvent(
    event: JournalEvent(
      meta: Metadata(
        id: id,
        createdAt: date,
        updatedAt: date,
        dateFrom: date,
        dateTo: date,
        categoryId: categoryId,
      ),
      data: EventData(
        title: 'Event $id',
        stars: 4,
        status: EventStatus.completed,
      ),
    ),
    categoryColor: color,
    categoryName: categoryName,
  );
}

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    Stream<List<ResolvedEvent>> stream, {
    Size size = const Size(1280, 900),
  }) async {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventsStreamProvider.overrideWith((ref) => stream)],
        child: makeTestableWidget2(
          const EventsOverviewPage(),
          mediaQueryData: MediaQueryData(size: size),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows a loading indicator before events arrive', (tester) async {
    await pumpPage(tester, const Stream.empty());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows an error indicator when the stream errors', (
    tester,
  ) async {
    await pumpPage(tester, Stream.error(Exception('boom')));
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('groups events into Upcoming + year sections with cards', (
    tester,
  ) async {
    await pumpPage(
      tester,
      Stream.value([
        _resolved(id: 'future', date: DateTime(2099, 7)),
        _resolved(
          id: 'past',
          date: DateTime(2020, 3),
          categoryId: 'work',
          categoryName: 'Work',
          color: const Color(0xFF2196F3),
        ),
      ]),
    );

    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('2020'), findsOneWidget);
    expect(find.text('Event future'), findsOneWidget);
    expect(find.text('Event past'), findsOneWidget);
    // Filter chips derived from the events' categories (+ "All").
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Friends'), findsWidgets);
    expect(find.text('Work'), findsWidgets);
  });

  testWidgets('selecting a category chip filters the visible events', (
    tester,
  ) async {
    await pumpPage(
      tester,
      Stream.value([
        _resolved(id: 'future', date: DateTime(2099, 7)),
        _resolved(
          id: 'past',
          date: DateTime(2020, 3),
          categoryId: 'work',
          categoryName: 'Work',
          color: const Color(0xFF2196F3),
        ),
      ]),
    );

    expect(find.text('Event future'), findsOneWidget);
    expect(find.text('Event past'), findsOneWidget);

    // Tap the "Work" filter chip (header comes first in the tree) → only the
    // Work (past) event remains.
    await tester.tap(find.text('Work').first);
    await tester.pump();

    expect(find.text('Event past'), findsOneWidget);
    expect(find.text('Event future'), findsNothing);
    expect(find.text('Upcoming'), findsNothing);
  });

  group('navigation callbacks', () {
    late MockPersistenceLogic persistence;

    setUpAll(() {
      registerFallbackValue(
        const EventData(status: EventStatus.tentative, title: '', stars: 0),
      );
      registerFallbackValue(const EntryText(plainText: ''));
    });

    setUp(() async {
      persistence = MockPersistenceLogic();
      await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<PersistenceLogic>(persistence);
        },
      );
    });

    tearDown(() async {
      beamToNamedOverride = null;
      await tearDownTestGetIt();
    });

    testWidgets('opening an event card beams to its detail route', (
      tester,
    ) async {
      final beamed = <String>[];
      beamToNamedOverride = beamed.add;

      await pumpPage(
        tester,
        Stream.value([_resolved(id: 'future', date: DateTime(2099, 7))]),
      );

      await tester.tap(find.text('Event future'));
      await tester.pump();

      expect(beamed, ['/events/future']);
    });

    testWidgets('the New event button creates an event and beams to it', (
      tester,
    ) async {
      final beamed = <String>[];
      beamToNamedOverride = beamed.add;
      when(
        () => persistence.createEventEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer(
        (_) async => _resolved(id: 'new-1', date: DateTime(2026)).event,
      );

      await pumpPage(
        tester,
        Stream.value([_resolved(id: 'past', date: DateTime(2020, 3))]),
      );

      await tester.tap(find.text('New event'));
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
  });
}
