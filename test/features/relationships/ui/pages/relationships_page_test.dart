import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/relationships/model/imported_contact.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/features/relationships/ui/pages/relationship_details_page.dart';
import 'package:lotti/features/relationships/ui/pages/relationships_page.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_detail_view.dart';
import 'package:lotti/features/relationships/ui/widgets/people_list_row.dart';
import 'package:lotti/features/relationships/ui/widgets/people_summary_card.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_chat_pane.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_launcher.dart';
import 'package:material_ui/material_ui.dart';
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
    CheckInInteractionType lastType = CheckInInteractionType.call,
    RelationshipStatus? status,
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
        status:
            status ??
            RelationshipStatus.active(
              id: 'status-$id',
              createdAt: testDate,
              utcOffset: 0,
            ),
      ),
    ),
    lastCheckIn: lastCheckInAt == null
        ? null
        : CheckInEntry(
            meta: Metadata(
              id: 'check-$id',
              createdAt: lastCheckInAt,
              updatedAt: lastCheckInAt,
              dateFrom: lastCheckInAt,
              dateTo: lastCheckInAt,
            ),
            data: CheckInData(relationshipId: id, interactionType: lastType),
          ),
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

  testWidgets('renders the empty state as a message alone — adding is the '
      "page's bottom action, never a second button", (tester) async {
    when(
      () => mockRepository.getRelationshipsByRecency(),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(
      find.text('Add the people you want to stay close to.'),
      findsOneWidget,
    );
    // On a phone the launcher docks the page's one add action; neither the
    // header nor the empty state adds a second.
    expect(find.byIcon(LottiIcons.add), findsNothing);
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

  testWidgets('on a phone the list floats no add button and the header holds '
      'none — the launcher docks it (peopleTabDockAction)', (tester) async {
    when(
      () => mockRepository.getRelationshipsByRecency(),
    ).thenAnswer((_) async => [item('rel-1', title: 'Anna')]);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('Anna'), findsOneWidget);
    expect(find.byKey(const ValueKey('people-add-person-fab')), findsNothing);
    expect(find.byIcon(LottiIcons.add), findsNothing);
  });

  testWidgets('peopleTabDockAction is a worded Add person action that opens '
      'the create form', (tester) async {
    MobileNavDockAction? action;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Consumer(
          builder: (context, ref, _) {
            action = peopleTabDockAction(context);
            return const SizedBox.shrink();
          },
        ),
        overrides: [
          relationshipRepositoryProvider.overrideWithValue(mockRepository),
        ],
      ),
    );
    await tester.pump();

    final messages = tester.element(find.byType(Consumer)).messages;
    // Worded, like the task list's: the plus alone would not say that this
    // one adds a person.
    expect(action!.worded, isTrue);
    expect(action!.icon, LottiIcons.add);
    expect(action!.label, messages.relationshipCreateTitle);

    action!.onPressed();
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Status'), findsNothing);
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
      // Exactly one sparkle: Anna is important, Ben is not (the star is
      // gone — it read as a toggle it was not).
      expect(
        find.byKey(const ValueKey('people-row-important')),
        findsOneWidget,
      );
      expect(find.byIcon(LottiIconsFilled.star), findsNothing);
      // The status line is the last contact — what, when, cadence — in mono,
      // never "Tracking since …".
      // Anna is enrolled without a stored cadence: the line names the
      // runtime's monthly default, never "No cadence".
      expect(find.text('Call · Yesterday 18:00 · Monthly'), findsOneWidget);
      // Ben has no check-in: "Just added", then the cadence.
      final context = tester.element(find.byType(RelationshipsPage));
      expect(
        find.text('${context.messages.relationshipJustAdded} · No cadence'),
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
    expect(
      find.text('Add the people you want to stay close to.'),
      findsOneWidget,
    );
  });

  /// Five people across the three bands, seen on Thursday 13 Aug 10:30:
  /// Anna lapsed (weekly, last contact 3 Aug → due Mon 10 Aug, 3 days over),
  /// Ben due within the week (weekly, contacted this morning → Thu 20 Aug),
  /// Cara on track (monthly, 1 Aug → 31 Aug), Dan not important, Eve
  /// important but dormant.
  List<RelationshipListItem> crew() => [
    item(
      'rel-dan',
      title: 'Dan',
      lastCheckInAt: DateTime(2026, 8, 12, 18),
      lastType: CheckInInteractionType.inPerson,
    ),
    item(
      'rel-cara',
      title: 'Cara',
      important: true,
      cadenceDays: 30,
      lastCheckInAt: DateTime(2026, 8, 1, 9),
    ),
    item(
      'rel-ben',
      title: 'Ben',
      important: true,
      cadenceDays: 7,
      lastCheckInAt: DateTime(2026, 8, 13, 9),
    ),
    item(
      'rel-anna',
      title: 'Anna',
      important: true,
      cadenceDays: 7,
      lastCheckInAt: DateTime(2026, 8, 3, 9),
    ),
    item(
      'rel-eve',
      title: 'Eve',
      important: true,
      cadenceDays: 7,
      status: RelationshipStatus.dormant(
        id: 'status-eve',
        createdAt: testDate,
        utcOffset: 0,
      ),
    ),
  ];

  testWidgets('bands the list Due · On track · Not enrolled with counts, '
      'lapsed first, and every pill tells the truth', (tester) async {
    when(
      () => mockRepository.getRelationshipsByRecency(),
    ).thenAnswer((_) async => crew());

    await withClock(Clock.fixed(testDate), () async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
    });

    expect(find.text('Due · 1'), findsOneWidget);
    expect(find.text('On track · 2'), findsOneWidget);
    expect(find.text('Not enrolled · 2'), findsOneWidget);

    // Never "Due Mon" for a lapse that happened last Monday (P5).
    expect(find.text('3 days over'), findsOneWidget);
    expect(find.text('Due Mon'), findsNothing);
    expect(find.text('Due Thu'), findsOneWidget);
    expect(find.text('On track'), findsOneWidget);
    expect(find.text('Not enrolled'), findsOneWidget);
    expect(find.text('Dormant'), findsOneWidget);

    double y(String name) => tester.getCenter(find.text(name)).dy;
    expect(y('Anna'), lessThan(y('Ben')));
    expect(y('Ben'), lessThan(y('Cara')));
    expect(y('Cara'), lessThan(y('Dan')));
    expect(y('Cara'), lessThan(y('Eve')));
  });

  testWidgets('the summary card counts the bands and names who lapses next', (
    tester,
  ) async {
    when(
      () => mockRepository.getRelationshipsByRecency(),
    ).thenAnswer((_) async => crew());

    await withClock(Clock.fixed(testDate), () async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
    });

    expect(find.byType(PeopleSummaryCard), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('/ 3 enrolled'), findsOneWidget);
    expect(find.text('Next due Ben · Thu 20 Aug'), findsOneWidget);
    expect(find.text('2 people not enrolled'), findsOneWidget);
  });

  testWidgets('a person who is not important reads Not enrolled, with no '
      'cadence claim', (tester) async {
    when(() => mockRepository.getRelationshipsByRecency()).thenAnswer(
      (_) async => [item('rel-1', title: 'Anna')],
    );

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Not enrolled · 1'), findsOneWidget);
    expect(find.text('Not enrolled'), findsOneWidget);
    expect(find.text('On track'), findsNothing);
    expect(find.byType(PeopleSummaryCard), findsOneWidget);
  });

  group('desktop split', () {
    late MockNavService navService;
    late ValueNotifier<String?> selected;
    late ValueNotifier<bool> chatOpen;
    late ValueNotifier<String?> checkInOpen;

    setUp(() {
      navService = MockNavService();
      selected = ValueNotifier<String?>(null);
      chatOpen = ValueNotifier<bool>(false);
      checkInOpen = ValueNotifier<String?>(null);
      when(
        () => navService.desktopRelationshipCheckInId,
      ).thenReturn(checkInOpen);
      when(() => navService.isDesktopMode).thenReturn(true);
      when(
        () => navService.desktopSelectedRelationshipId,
      ).thenReturn(selected);
      when(
        () => navService.desktopRelationshipChatOpen,
      ).thenReturn(chatOpen);
      final settingsDb = MockSettingsDb();
      when(
        () => settingsDb.itemsByKeys(any()),
      ).thenAnswer((_) async => <String, String?>{});
      when(() => settingsDb.itemByKey(any())).thenAnswer((_) async => null);
      when(
        () => settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);
      getIt
        ..registerSingleton<NavService>(navService)
        ..registerSingleton<SettingsDb>(settingsDb);
    });

    tearDown(() async {
      selected.dispose();
      chatOpen.dispose();
      checkInOpen.dispose();
      await getIt.unregister<NavService>();
      await getIt.unregister<SettingsDb>();
    });

    /// [paneWidth] is the width the People page gets inside the window —
    /// narrower than the window where the app's own sidebar takes a share.
    Future<void> pumpDesktop(
      WidgetTester tester, {
      double width = 1280,
      double? paneWidth,
    }) async {
      tester.view
        ..physicalSize = Size(width, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await withClock(Clock.fixed(testDate), () async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: paneWidth ?? width,
                child: const RelationshipsPage(),
              ),
            ),
            mediaQueryData: MediaQueryData(size: Size(width, 800)),
            overrides: [
              relationshipRepositoryProvider.overrideWithValue(mockRepository),
            ],
          ),
        );
        await tester.pumpAndSettle();
      });
    }

    testWidgets('with no selection the list pane sits beside the empty state, '
        'and adding a person is the labelled floating button', (tester) async {
      when(
        () => mockRepository.getRelationshipsByRecency(),
      ).thenAnswer((_) async => crew());

      await pumpDesktop(tester);

      expect(find.text('Anna'), findsOneWidget);
      final context = tester.element(find.byType(RelationshipsPage));
      expect(
        find.text(context.messages.relationshipsSelectPersonHint),
        findsOneWidget,
      );
      final fab = find.byKey(const ValueKey('people-add-person-fab'));
      expect(fab, findsOneWidget);
      // Worded like the task list's, so the plus says what it adds.
      expect(
        find.descendant(
          of: fab,
          matching: find.text(context.messages.relationshipCreateTitle),
        ),
        findsOneWidget,
      );
      // It floats in the list pane's bottom corner, not in the header.
      final listPane = tester.getRect(find.byType(CustomScrollView));
      final fabRect = tester.getRect(fab);
      expect(fabRect.right, lessThanOrEqualTo(listPane.right));
      expect(fabRect.center.dy, greaterThan(listPane.center.dy));
      expect(find.byIcon(LottiIcons.add), findsOneWidget);
      expect(find.byType(RelationshipDetailsPage), findsNothing);
    });

    testWidgets('the floating Add person button opens the create form', (
      tester,
    ) async {
      when(
        () => mockRepository.getRelationshipsByRecency(),
      ).thenAnswer((_) async => crew());

      await pumpDesktop(tester);
      await tester.tap(find.byKey(const ValueKey('people-add-person-fab')));
      await tester.pumpAndSettle();

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Status'), findsNothing);
    });

    testWidgets('an empty list keeps the floating button as its one add '
        'action', (tester) async {
      when(
        () => mockRepository.getRelationshipsByRecency(),
      ).thenAnswer((_) async => []);

      await pumpDesktop(tester);

      expect(
        find.byKey(const ValueKey('people-add-person-fab')),
        findsOneWidget,
      );
      expect(find.byIcon(LottiIcons.add), findsOneWidget);
    });

    testWidgets('dragging the divider widens the list pane', (tester) async {
      when(
        () => mockRepository.getRelationshipsByRecency(),
      ).thenAnswer((_) async => crew());

      await pumpDesktop(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RelationshipsPage)),
      );
      expect(
        container.read(paneWidthControllerProvider).listPaneWidth,
        defaultListPaneWidth,
      );

      await tester.drag(find.byType(ResizableDivider), const Offset(40, 0));
      await tester.pump();

      expect(
        container.read(paneWidthControllerProvider).listPaneWidth,
        defaultListPaneWidth + 40,
      );
      // Let the persist debounce fire so no timer leaks past the test.
      await tester.pump(persistDebounce);
    });

    testWidgets('with a person selected the list can fold away and come '
        'back through the show-list-pane button', (tester) async {
      when(
        () => mockRepository.getRelationshipsByRecency(),
      ).thenAnswer((_) async => crew());
      final anna = crew().firstWhere((i) => i.relationship.id == 'rel-anna');
      when(
        () => mockRepository.getRelationshipById('rel-anna'),
      ).thenAnswer((_) async => anna.relationship);
      when(
        () => mockRepository.getCheckInsForRelationship('rel-anna'),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepository.getLinkedTasks('rel-anna'),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepository.getEntriesForCheckIns(any()),
      ).thenAnswer((_) async => const {});
      selected.value = 'rel-anna';

      await pumpDesktop(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RelationshipsPage)),
      );
      // The split's controller is exposed to its descendants; the detail
      // page is one.
      ListDetailFocusTraversal.maybeOf(
        tester.element(find.byType(RelationshipDetailsPage)),
      )!.hideListPane();
      await tester.pumpAndSettle();
      expect(
        container.read(paneWidthControllerProvider).listPaneCollapsed,
        isTrue,
      );
      expect(find.byType(ResizableDivider), findsNothing);
      expect(
        find.byKey(const ValueKey('people-show-list-pane')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('people-show-list-pane')));
      await tester.pumpAndSettle();
      expect(
        container.read(paneWidthControllerProvider).listPaneCollapsed,
        isFalse,
      );
      expect(find.byType(ResizableDivider), findsOneWidget);
      // Let the persist debounce fire so no timer leaks past the test.
      await tester.pump(persistDebounce);
    });

    testWidgets('the selected person fills the detail pane and wears the '
        'selected wash on the list', (tester) async {
      when(
        () => mockRepository.getRelationshipsByRecency(),
      ).thenAnswer((_) async => crew());
      final anna = crew().firstWhere((i) => i.relationship.id == 'rel-anna');
      when(
        () => mockRepository.getRelationshipById('rel-anna'),
      ).thenAnswer((_) async => anna.relationship);
      when(
        () => mockRepository.getCheckInsForRelationship('rel-anna'),
      ).thenAnswer((_) async => [anna.lastCheckIn!]);
      when(
        () => mockRepository.getLinkedTasks('rel-anna'),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepository.getEntriesForCheckIns(any()),
      ).thenAnswer((_) async => const {});
      selected.value = 'rel-anna';

      await pumpDesktop(tester);

      expect(find.byType(RelationshipDetailsPage), findsOneWidget);
      // The page's own app bar names the person, so the name appears twice:
      // once on the list, once on the page.
      expect(find.text('Anna'), findsNWidgets(2));
      final selectedRow = tester.widget<PeopleListRow>(
        find.byKey(const ValueKey('people-row-rel-anna')),
      );
      final otherRow = tester.widget<PeopleListRow>(
        find.byKey(const ValueKey('people-row-rel-ben')),
      );
      expect(selectedRow.selected, isTrue);
      expect(otherRow.selected, isFalse);
    });

    testWidgets('a check-in takes over the detail pane beside the list, and '
        'back leads to the person', (tester) async {
      when(
        () => mockRepository.getRelationshipsByRecency(),
      ).thenAnswer((_) async => crew());
      final anna = crew().firstWhere((i) => i.relationship.id == 'rel-anna');
      final checkIn = anna.lastCheckIn!;
      when(
        () => mockRepository.getRelationshipById('rel-anna'),
      ).thenAnswer((_) async => anna.relationship);
      when(
        () => mockRepository.getCheckInsForRelationship('rel-anna'),
      ).thenAnswer((_) async => [checkIn]);
      when(
        () => mockRepository.getLinkedTasks('rel-anna'),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepository.getEntriesForCheckIns(any()),
      ).thenAnswer((_) async => const {});
      selected.value = 'rel-anna';
      checkInOpen.value = checkIn.meta.id;

      await pumpDesktop(tester);

      expect(find.byType(CheckInDetailView), findsOneWidget);
      expect(find.byType(RelationshipDetailsPage), findsNothing);
      expect(find.byKey(const ValueKey('people-row-rel-ben')), findsOneWidget);

      final navigated = <String>[];
      beamToNamedOverride = navigated.add;
      addTearDown(() => beamToNamedOverride = null);
      await tester.tap(find.byKey(const ValueKey('check-in-detail-back')));

      expect(navigated, ['/people/rel-anna']);
    });

    void stubAnna() {
      when(
        () => mockRepository.getRelationshipsByRecency(),
      ).thenAnswer((_) async => crew());
      final anna = crew().firstWhere((i) => i.relationship.id == 'rel-anna');
      when(
        () => mockRepository.getRelationshipById('rel-anna'),
      ).thenAnswer((_) async => anna.relationship);
      when(
        () => mockRepository.getCheckInsForRelationship('rel-anna'),
      ).thenAnswer((_) async => [anna.lastCheckIn!]);
      when(
        () => mockRepository.getLinkedTasks('rel-anna'),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepository.getEntriesForCheckIns(any()),
      ).thenAnswer((_) async => const {});
      selected.value = 'rel-anna';
      chatOpen.value = true;
    }

    final rowBen = find.byKey(const ValueKey('people-row-rel-ben'));

    // Design panel 2026-09-19: the chat sits beside the person's page, so
    // what the agent is asked about stays in view.
    testWidgets('on a wide window the chat opens as a sidebar beside the '
        'person page and the list, and the page stays mounted', (tester) async {
      stubAnna();
      await pumpDesktop(tester, width: 1600);

      expect(find.byType(RelationshipChatPane), findsOneWidget);
      final page = tester.getRect(find.byType(RelationshipDetailsPage));
      final chat = tester.getRect(find.byType(RelationshipChatPane));
      expect(chat.left, greaterThanOrEqualTo(page.right));
      expect(chat.width, defaultListPaneWidth);
      expect(rowBen, findsOneWidget, reason: 'room for all three');
      final pageState = tester.state(find.byType(RelationshipDetailsPage));

      // Close routes to the person, so the URL and the pane stay in step.
      final navigated = <String>[];
      beamToNamedOverride = navigated.add;
      addTearDown(() => beamToNamedOverride = null);
      expect(find.byKey(const ValueKey('person-chat-back')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('person-chat-close')));
      await tester.pump();
      expect(navigated, ['/people/rel-anna']);

      chatOpen.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(RelationshipChatPane), findsNothing);
      expect(
        tester.state(find.byType(RelationshipDetailsPage)),
        same(pageState),
        reason: 'closing the chat never rebuilds the page',
      );
    });

    // Codex review on #4357: beside the list, a laptop window would squeeze
    // the page to a strip; the list steps aside while the chat is open.
    testWidgets('where the list would squeeze the page, the list steps aside '
        'for the chat and returns when it closes', (tester) async {
      stubAnna();
      await pumpDesktop(tester);

      expect(find.byType(RelationshipDetailsPage), findsOneWidget);
      expect(find.byType(RelationshipChatPane), findsOneWidget);
      expect(rowBen, findsNothing);
      expect(
        tester.getSize(find.byType(RelationshipDetailsPage)).width,
        greaterThanOrEqualTo(defaultListPaneWidth),
      );

      chatOpen.value = false;
      await tester.pumpAndSettle();
      expect(rowBen, findsOneWidget, reason: 'the preference was untouched');
    });

    testWidgets('where even the pane alone cannot hold both, the chat takes '
        'the pane and leads back to the person', (tester) async {
      stubAnna();
      await pumpDesktop(tester, paneWidth: 800);

      expect(find.byType(RelationshipChatPane), findsOneWidget);
      expect(find.byType(RelationshipDetailsPage), findsNothing);
      expect(tester.takeException(), isNull);

      final navigated = <String>[];
      beamToNamedOverride = navigated.add;
      addTearDown(() => beamToNamedOverride = null);
      await tester.tap(find.byKey(const ValueKey('person-chat-back')));
      await tester.pump();
      expect(navigated, ['/people/rel-anna']);
    });
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
