import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/pages/relationships_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final testDate = DateTime(2026, 8, 13, 10, 30);

  late MockRelationshipRepository mockRepository;
  late MockUpdateNotifications mockNotifications;

  RelationshipListItem item(
    String id, {
    required String title,
    bool important = false,
    DateTime? lastCheckInAt,
  }) => (
    relationship: RelationshipEntry(
      meta: Metadata(
        id: id,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      ),
      data: RelationshipData(
        title: title,
        important: important,
        status: RelationshipStatus.active(
          id: 'status-$id',
          createdAt: testDate,
          utcOffset: 0,
        ),
      ),
    ),
    lastCheckInAt: lastCheckInAt,
  );

  setUp(() {
    mockRepository = MockRelationshipRepository();
    mockNotifications = MockUpdateNotifications();
    getIt.registerSingleton<UpdateNotifications>(mockNotifications);
    // CategoryField (rendered by the add-person form) reads the category
    // name through `getIt<EntitiesCacheService>()`; default to "no category".
    final cacheService = MockEntitiesCacheService();
    when(() => cacheService.getCategoryById(any())).thenReturn(null);
    getIt.registerSingleton<EntitiesCacheService>(cacheService);
  });

  tearDown(() async {
    await getIt.unregister<UpdateNotifications>();
    await getIt.unregister<EntitiesCacheService>();
  });

  Widget buildPage() => makeTestableWidgetNoScroll(
    const RelationshipsPage(),
    overrides: [
      relationshipRepositoryProvider.overrideWithValue(mockRepository),
    ],
  );

  testWidgets('renders the empty state when nothing is tracked', (
    tester,
  ) async {
    when(
      () => mockRepository.getRelationshipsByRecency(),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(
      find.text('Add the people you want to stay close to.'),
      findsOneWidget,
    );
  });

  testWidgets('shows the error text when the first load fails', (
    tester,
  ) async {
    when(
      () => mockRepository.getRelationshipsByRecency(),
    ).thenThrow(Exception('db gone'));

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsOneWidget);
    expect(
      find.text('Add the people you want to stay close to.'),
      findsNothing,
    );
  });

  testWidgets(
    'shows progress on the first load, then swaps it for the list',
    (tester) async {
      final firstLoad = Completer<List<RelationshipListItem>>();
      when(
        () => mockRepository.getRelationshipsByRecency(),
      ).thenAnswer((_) => firstLoad.future);

      await tester.pumpWidget(buildPage());
      await tester.pump();

      // Nothing has resolved yet: the tab must not read as empty.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.text('Add the people you want to stay close to.'),
        findsNothing,
      );

      firstLoad.complete([item('rel-1', title: 'Anna')]);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Anna'), findsOneWidget);
    },
  );

  testWidgets('reports a failed first load instead of an empty tab', (
    tester,
  ) async {
    when(
      () => mockRepository.getRelationshipsByRecency(),
    ).thenThrow(Exception('db gone'));

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsOneWidget);
    // Never the "you have no people" copy — that would read as data loss.
    expect(
      find.text('Add the people you want to stay close to.'),
      findsNothing,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('tapping a row beams to that person', (tester) async {
    when(() => mockRepository.getRelationshipsByRecency()).thenAnswer(
      (_) async => [item('rel-1', title: 'Anna')],
    );
    final beamedTo = <String>[];
    beamToNamedOverride = beamedTo.add;
    addTearDown(() => beamToNamedOverride = null);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();

    expect(beamedTo, ['/people/rel-1']);
  });

  testWidgets('the FAB opens the add-person form', (tester) async {
    when(
      () => mockRepository.getRelationshipsByRecency(),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add person'));
    await tester.pumpAndSettle();

    // Create mode: the name field is up, and the edit-only status picker
    // is not.
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Status'), findsNothing);
  });

  testWidgets(
    'renders one row per relationship and stars only important ones',
    (tester) async {
      when(() => mockRepository.getRelationshipsByRecency()).thenAnswer(
        (_) async => [
          item(
            'rel-1',
            title: 'Anna',
            important: true,
            lastCheckInAt: DateTime(2026, 8, 12, 18),
          ),
          item('rel-2', title: 'Ben'),
        ],
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Ben'), findsOneWidget);
      // Exactly one star: Anna is important, Ben is not.
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      // Anna's subtitle is her last check-in, Ben's his tracking start —
      // and each names itself: on a recency screen a person added today
      // must not read as recently contacted.
      final context = tester.element(find.byType(RelationshipsPage));
      expect(
        find.text(
          context.messages.relationshipLastCheckInLabel(
            entryDateLabelForTest(tester, DateTime(2026, 8, 12, 18)),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          context.messages.relationshipTrackingSinceLabel(
            entryDateLabelForTest(tester, testDate),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Add the people you want to stay close to.'),
        findsNothing,
      );
    },
  );

  testWidgets('first load shows a spinner, not a blank page', (tester) async {
    final gate = Completer<List<RelationshipListItem>>();
    when(
      () => mockRepository.getRelationshipsByRecency(),
    ).thenAnswer((_) => gate.future);

    await tester.pumpWidget(buildPage());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete([item('rel-1', title: 'Anna')]);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Anna'), findsOneWidget);
  });

  testWidgets('a notification-triggered reload keeps the previous rows on '
      'screen — the no-flash house rule, pinned', (tester) async {
    final updates = StreamController<Set<String>>.broadcast();
    addTearDown(updates.close);
    when(() => mockNotifications.updateStream)
        .thenAnswer((_) => updates.stream);
    var calls = 0;
    final second = Completer<List<RelationshipListItem>>();
    when(() => mockRepository.getRelationshipsByRecency()).thenAnswer((_) {
      calls++;
      if (calls == 1) {
        return Future.value([item('rel-1', title: 'Anna')]);
      }
      return second.future;
    });

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();
    expect(find.text('Anna'), findsOneWidget);

    updates.add({relationshipNotification});
    await tester.pump();
    await tester.pump();

    // Mid-refetch: the established list must stay, with no loading shell.
    expect(calls, 2);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    second.complete([
      item('rel-1', title: 'Anna'),
      item('rel-2', title: 'Ben'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Ben'), findsOneWidget);
  });
}

/// Resolves [entryDateLabel] against the pumped widget tree's locale, so the
/// assertion tracks the production formatting instead of duplicating it.
String entryDateLabelForTest(WidgetTester tester, DateTime date) {
  final context = tester.element(find.byType(RelationshipsPage));
  return entryDateLabel(context, date);
}
