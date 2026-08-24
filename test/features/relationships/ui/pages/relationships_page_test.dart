import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/imported_contact.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/features/relationships/ui/pages/relationships_page.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Counts pushes so a test can tell which navigator a route landed on.
class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // The observer sees the host route itself; only later pushes count.
    if (previousRoute != null) pushes++;
  }
}

/// A contacts service that reports the platform as supported, so the import
/// action renders, and refuses everything else — the import screen under it
/// is not what these tests are about.
class _SupportedContactsService implements ContactsService {
  @override
  bool get isSupported => true;

  @override
  Future<ContactsAccess> requestReadAccess() async => ContactsAccess.denied;

  @override
  Future<ImportedContact?> pickSingle() async => null;

  @override
  Future<List<ImportedContact>> readAll() async => const [];

  @override
  Future<ImportedContact?> readById(String id) async => null;

  @override
  Future<void> openSystemSettings() async {}
}

void main() {
  final testDate = DateTime(2026, 8, 13, 10, 30);

  late MockRelationshipRepository mockRepository;
  late MockUpdateNotifications mockNotifications;

  RelationshipListItem item(
    String id, {
    required String title,
    bool important = false,
    int? cadenceDays,
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
        checkInCadenceDays: cadenceDays,
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

  Widget buildPage({List<Override> overrides = const []}) =>
      makeTestableWidgetNoScroll(
        const RelationshipsPage(),
        overrides: [
          relationshipRepositoryProvider.overrideWithValue(mockRepository),
          ...overrides,
        ],
      );

  testWidgets('renders the empty state with an add affordance', (tester) async {
    when(
      () => mockRepository.getRelationshipsByRecency(),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(
      find.text('Add the people you want to stay close to.'),
      findsOneWidget,
    );
    // Two: the persistent header circle plus the empty state's own inline
    // CTA (design plan §1). With people present only the header one remains
    // — asserted by 'the import door sits beside the add circle' below.
    expect(find.byIcon(LottiIcons.add), findsNWidgets(2));
  });

  testWidgets('shows the error text when the first load fails', (tester) async {
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

  testWidgets('the header add circle opens the add-person form', (
    tester,
  ) async {
    when(
      () => mockRepository.getRelationshipsByRecency(),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    // The only add affordances are circles (design plan §0.3): no FAB, no
    // app-bar person-add icon. With an empty list there are two — the header
    // circle and the empty state's inline CTA — and the header is built
    // first, so `.first` is the one this test is about.
    final addIcons = find.byIcon(LottiIcons.add);
    expect(addIcons, findsNWidgets(2));

    await tester.tap(addIcons.first);
    await tester.pumpAndSettle();

    // Create mode: the name field is up, and the edit-only status picker is
    // not.
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Status'), findsNothing);
  });

  testWidgets('the add circle names itself for a screen reader and a pointer', (
    tester,
  ) async {
    when(
      () => mockRepository.getRelationshipsByRecency(),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(RelationshipsPage));
    final label = context.messages.relationshipCreateTitle;

    // Both add circles — the header one and the empty state's inline CTA —
    // are the same bare glyph, which tells assistive tech nothing on its
    // own. Each carries the localized name in both channels, and states it
    // once rather than twice.
    final labelled = find.byTooltip(label);
    expect(labelled, findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      expect(
        tester.getSemantics(labelled.at(i)),
        matchesSemantics(
          label: label,
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    }
  });

  testWidgets(
    'renders one row per relationship, with persona avatars and inline stars '
    'only for important people',
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

      await withClock(Clock.fixed(testDate), () async {
        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();
      });

      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Ben'), findsOneWidget);
      // Persona avatars replace the bare person icon.
      expect(find.byType(PersonaAvatar), findsNWidgets(2));
      // Exactly one star: Anna is important, Ben is not. The star is inline
      // with the name (11px), not a trailing app-bar icon.
      expect(find.byIcon(LottiIconsFilled.star), findsOneWidget);
      // The status line is the last meaningful event, mono — "Checked in …",
      // never "Tracking since …" (design plan §0.8).
      final context = tester.element(find.byType(RelationshipsPage));
      expect(
        find.text(
          context.messages.relationshipCheckedInLabel('Yesterday 18:00'),
        ),
        findsOneWidget,
      );
      // Ben has no check-in: the quiet-streak caption (here 0 days → "Just
      // added"), never "Tracking since …".
      expect(find.text(context.messages.relationshipJustAdded), findsOneWidget);
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

  testWidgets(
    'a notification-triggered reload keeps the previous rows on screen — '
    'the no-flash house rule, pinned',
    (tester) async {
      final updates = StreamController<Set<String>>.broadcast();
      addTearDown(updates.close);
      when(
        () => mockNotifications.updateStream,
      ).thenAnswer((_) => updates.stream);
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
    },
  );

  // The import screen docks its Import action in a `bottomNavigationBar`, and
  // the mobile shell paints the nav pill over each tab's page stack — so a
  // push onto the tab's own navigator leaves that action behind the pill.
  // `bottomNavSafeNavigatorOf` is what lifts it above the shell.
  testWidgets('opens contact import above the shell, not inside the tab', (
    tester,
  ) async {
    when(
      () => mockRepository.getRelationshipsByRecency(),
    ).thenAnswer((_) async => []);

    final rootObserver = _RecordingNavigatorObserver();
    final nestedObserver = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Navigator(
          observers: [nestedObserver],
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const RelationshipsPage(),
          ),
        ),
        overrides: [
          relationshipRepositoryProvider.overrideWithValue(mockRepository),
          contactsServiceProvider.overrideWithValue(
            _SupportedContactsService(),
          ),
        ],
        navigatorObservers: [rootObserver],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LottiIcons.contactImport));
    await tester.pump();

    expect(rootObserver.pushes, 1, reason: 'pushed above the shell');
    expect(nestedObserver.pushes, 0, reason: 'never onto the tab navigator');
  });

  testWidgets('hides the import door on unsupported platforms (desktop)', (
    tester,
  ) async {
    when(
      () => mockRepository.getRelationshipsByRecency(),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(
      buildPage(
        overrides: [
          contactsServiceProvider.overrideWithValue(
            _UnsupportedContactsService(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(LottiIcons.contactImport), findsNothing);
    // Hiding the import door leaves the add circles untouched: the header's
    // and, because this case has no people, the empty state's.
    expect(find.byIcon(LottiIcons.add), findsNWidgets(2));
  });

  testWidgets('sorts due people ahead of on-track people', (tester) async {
    // Anna: due (last check-in 10 days ago, weekly cadence).
    // Ben:  on track (last check-in today, weekly cadence).
    when(() => mockRepository.getRelationshipsByRecency()).thenAnswer(
      (_) async => [
        item(
          'rel-ben',
          title: 'Ben',
          cadenceDays: 7,
          lastCheckInAt: DateTime(2026, 8, 13, 9),
        ),
        item(
          'rel-anna',
          title: 'Anna',
          cadenceDays: 7,
          lastCheckInAt: DateTime(2026, 8, 3, 9),
        ),
      ],
    );

    await withClock(Clock.fixed(testDate), () async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
    });

    // Anna (due) renders above Ben (on track).
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Ben'), findsOneWidget);
    // The due pill is the warning-tinted "Due {day}" label.
    final context = tester.element(find.byType(RelationshipsPage));
    // Anna's last check-in was 2026-08-03; +7 days of cadence is
    // 2026-08-10, a Monday.
    final dueLabel = find.text(
      context.messages.relationshipDueDay('Mon'),
    );
    expect(dueLabel, findsOneWidget);
    expect(
      find.text(context.messages.relationshipCadenceOnTrack),
      findsOneWidget,
    );
    // Anna's row sits above Ben's: her text is found first in the column.
    final annaCenter = tester.getCenter(find.text('Anna'));
    final benCenter = tester.getCenter(find.text('Ben'));
    expect(annaCenter.dy, lessThan(benCenter.dy));
  });

  testWidgets('a person with no cadence shows no cadence pill', (tester) async {
    when(() => mockRepository.getRelationshipsByRecency()).thenAnswer(
      (_) async => [item('rel-1', title: 'Anna')],
    );

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('Anna'), findsOneWidget);
    final context = tester.element(find.byType(RelationshipsPage));
    expect(
      find.text(context.messages.relationshipCadenceOnTrack),
      findsNothing,
    );
  });
}

class _UnsupportedContactsService implements ContactsService {
  @override
  bool get isSupported => false;

  @override
  Future<ContactsAccess> requestReadAccess() async => ContactsAccess.denied;

  @override
  Future<ImportedContact?> pickSingle() async => null;

  @override
  Future<List<ImportedContact>> readAll() async => const [];

  @override
  Future<ImportedContact?> readById(String id) async => null;

  @override
  Future<void> openSystemSettings() async {}
}
