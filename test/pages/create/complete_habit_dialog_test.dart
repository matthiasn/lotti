import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/create/complete_habit_dialog.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();
  final mockEntitiesCacheService = MockEntitiesCacheService();

  group('HabitDialog Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeHabitCompletionData());
    });

    setUp(() async {
      mockJournalDb = mockJournalDbWithHabits([
        habitFlossing,
      ]);
      mockPersistenceLogic = MockPersistenceLogic();

      when(
        () => mockEntitiesCacheService.getHabitById(habitFlossing.id),
      ).thenAnswer((_) => habitFlossing);

      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(mockJournalDb)
            ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
            ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
        },
      );
    });
    tearDown(tearDownTestGetIt);

    Future<void> pumpHabitDialog(WidgetTester tester) async {
      final delegate = BeamerDelegate(
        locationBuilder: RoutesLocationBuilder(
          routes: {
            '/': (context, state, data) => Container(),
          },
        ).call,
      );

      await tester.pumpWidget(
        makeTestableWidget(
          BeamerProvider(
            routerDelegate: delegate,
            child: Material(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 800,
                  maxWidth: 800,
                ),
                child: HabitDialog(
                  habitId: habitFlossing.id,
                  themeData: ThemeData(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('Habit completion can be recorded', (tester) async {
      when(
        () => mockPersistenceLogic.createHabitCompletionEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: habitFlossing,
        ),
      ).thenAnswer((_) async => null);

      await pumpHabitDialog(tester);

      expect(find.text(habitFlossing.name), findsOneWidget);

      final commentFieldFinder = find.byKey(const Key('habit_comment_field'));
      final saveButtonFinder = find.byKey(const Key('habit_save'));

      expect(commentFieldFinder, findsOneWidget);
      expect(saveButtonFinder, findsOneWidget);

      await tester.tap(saveButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The save actually persisted a SUCCESS completion (mirrors the
      // Fail/Skip tests instead of stopping at the tap).
      final captured = verify(
        () => mockPersistenceLogic.createHabitCompletionEntry(
          data: captureAny(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: habitFlossing,
        ),
      ).captured;
      final completion = captured.single as HabitCompletionData;
      expect(completion.completionType, HabitCompletionType.success);
    });

    testWidgets('Fail button records a failed completion', (tester) async {
      when(
        () => mockPersistenceLogic.createHabitCompletionEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: habitFlossing,
        ),
      ).thenAnswer((_) async => null);

      await pumpHabitDialog(tester);

      await tester.tap(find.byKey(const Key('habit_fail')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final captured = verify(
        () => mockPersistenceLogic.createHabitCompletionEntry(
          data: captureAny(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: habitFlossing,
        ),
      ).captured;

      final completion = captured.single as HabitCompletionData;
      expect(completion.completionType, HabitCompletionType.fail);
    });

    testWidgets('Skip button records a skipped completion', (tester) async {
      when(
        () => mockPersistenceLogic.createHabitCompletionEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: habitFlossing,
        ),
      ).thenAnswer((_) async => null);

      await pumpHabitDialog(tester);

      await tester.tap(find.byKey(const Key('habit_skip')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final captured = verify(
        () => mockPersistenceLogic.createHabitCompletionEntry(
          data: captureAny(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: habitFlossing,
        ),
      ).captured;

      final completion = captured.single as HabitCompletionData;
      expect(completion.completionType, HabitCompletionType.skip);
    });

    testWidgets('Shows dashboard preview when habit has dashboard id', (
      tester,
    ) async {
      final habitWithDashboard = habitFlossing.copyWith(dashboardId: 'dash-1');

      when(
        () => mockEntitiesCacheService.getHabitById(habitFlossing.id),
      ).thenAnswer((_) => habitWithDashboard);

      when(
        () => mockEntitiesCacheService.getDashboardById(any()),
      ).thenReturn(null);

      when(
        () => mockPersistenceLogic.createHabitCompletionEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: habitWithDashboard,
        ),
      ).thenAnswer((_) async => null);

      await pumpHabitDialog(tester);

      expect(find.byType(SingleChildScrollView).evaluate().length, 2);
    });

    testWidgets(
      'desktop registers the Cmd+S hotkey on init and unregisters on '
      'dispose',
      (tester) async {
        // Platform globals are mutable for tests; restore afterwards.
        final wasDesktop = isDesktop;
        isDesktop = true;
        addTearDown(() => isDesktop = wasDesktop);

        when(
          () => mockPersistenceLogic.createHabitCompletionEntry(
            data: any(named: 'data'),
            comment: any(named: 'comment'),
            habitDefinition: habitFlossing,
          ),
        ).thenAnswer((_) async => null);

        await pumpHabitDialog(tester);

        // In-app scoped hotkeys register into the manager's in-memory list
        // (no platform channel involved for HotKeyScope.inapp).
        expect(hotKeyManager.registeredHotKeyList, isNotEmpty);

        // Tear the dialog down — dispose must unregister the hotkey.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(hotKeyManager.registeredHotKeyList, isEmpty);
      },
    );

    testWidgets('Close button dismisses the dialog', (tester) async {
      await pumpHabitDialog(tester);

      final closeButton = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'close habit completion',
      );
      expect(closeButton, findsOneWidget);

      await tester.ensureVisible(closeButton);
      await tester.tap(closeButton);
      // The route-pop transition must fully complete before the dialog
      // leaves the tree — keep the unbounded settle here.
      await tester.pumpAndSettle();

      // After Navigator.pop the HabitDialog is no longer in the tree.
      expect(find.byType(HabitDialog), findsNothing);
    });

    testWidgets(
      'dateString from a past date sets _started to end of that day (lines 81-83, 88)',
      (tester) async {
        final delegate = BeamerDelegate(
          locationBuilder: RoutesLocationBuilder(
            routes: {'/': (context, state, data) => Container()},
          ).call,
        );

        // Use a fixed past date — different from today — to trigger the endOfDay branch.
        const pastDate = '2024-01-15';

        await tester.pumpWidget(
          makeTestableWidget(
            BeamerProvider(
              routerDelegate: delegate,
              child: Material(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 800,
                    maxWidth: 800,
                  ),
                  child: HabitDialog(
                    habitId: habitFlossing.id,
                    dateString: pastDate,
                    themeData: ThemeData(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The DateTimeField should display a time of 23:59 — confirming endOfDay()
        // was called and _started was set to the end of the supplied dateString.
        expect(
          find.textContaining('23:59'),
          findsAtLeastNWidgets(1),
        );
      },
    );

    testWidgets(
      'Success save with comment persists the note in the completion entry',
      (tester) async {
        when(
          () => mockPersistenceLogic.createHabitCompletionEntry(
            data: any(named: 'data'),
            comment: any(named: 'comment'),
            habitDefinition: habitFlossing,
          ),
        ).thenAnswer((_) async => null);

        await pumpHabitDialog(tester);

        await tester.enterText(
          find.byKey(const Key('habit_comment_field')),
          'Great job today',
        );

        await tester.tap(find.byKey(const Key('habit_save')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final captured = verify(
          () => mockPersistenceLogic.createHabitCompletionEntry(
            data: captureAny(named: 'data'),
            comment: captureAny(named: 'comment'),
            habitDefinition: habitFlossing,
          ),
        ).captured;

        // captured is [data, comment] interleaved per call
        expect(captured[1], 'Great job today');
        final completion = captured[0] as HabitCompletionData;
        expect(completion.completionType, HabitCompletionType.success);
      },
    );

    testWidgets(
      'setDateTime callback updates _started and sets _startReset (lines 219-222)',
      (tester) async {
        when(
          () => mockPersistenceLogic.createHabitCompletionEntry(
            data: any(named: 'data'),
            comment: any(named: 'comment'),
            habitDefinition: habitFlossing,
          ),
        ).thenAnswer((_) async => null);

        await pumpHabitDialog(tester);

        // Retrieve the DateTimeField and call its setDateTime directly.
        final dateTimeField = tester.widget<DateTimeField>(
          find.byType(DateTimeField),
        );

        // Invoke the callback with a known date — this exercises lines 219-222.
        final newDate = DateTime(2024, 6, 1, 9, 30);
        dateTimeField.setDateTime(newDate);
        await tester.pump();

        // After the callback, the DateTimeField should display the new date.
        expect(find.textContaining('09:30'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets('Returns SizedBox.shrink when habit definition is not found', (
      tester,
    ) async {
      when(
        () => mockEntitiesCacheService.getHabitById(habitFlossing.id),
      ).thenAnswer((_) => null);

      final delegate = BeamerDelegate(
        locationBuilder: RoutesLocationBuilder(
          routes: {'/': (context, state, data) => Container()},
        ).call,
      );

      await tester.pumpWidget(
        makeTestableWidget(
          BeamerProvider(
            routerDelegate: delegate,
            child: Material(
              child: HabitDialog(
                habitId: habitFlossing.id,
                themeData: ThemeData(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // When habitDefinition is null, the widget returns SizedBox.shrink()
      // so none of the dialog content should be present.
      expect(find.byKey(const Key('habit_save')), findsNothing);
      expect(find.byKey(const Key('habit_fail')), findsNothing);
    });
  });

  group('HabitDescription Widget Tests - ', () {
    late MockUrlLauncher mockUrlLauncher;
    late UrlLauncherPlatform originalPlatform;
    final mockEntitiesCacheService = MockEntitiesCacheService();

    setUp(() async {
      originalPlatform = UrlLauncherPlatform.instance;
      mockUrlLauncher = MockUrlLauncher();
      UrlLauncherPlatform.instance = mockUrlLauncher;
      registerFallbackValue(FakeLaunchOptions());

      // setUpTestGetIt registers LoggingService/DomainLogger already.
      await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<EntitiesCacheService>(
            mockEntitiesCacheService,
          );
        },
      );
    });

    tearDown(() async {
      UrlLauncherPlatform.instance = originalPlatform;
      await tearDownTestGetIt();
    });

    Future<void> pumpDescription(WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: HabitDescription(habitFlossing),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('renders habit description text', (tester) async {
      await pumpDescription(tester);
      expect(find.textContaining(habitFlossing.description), findsOneWidget);
    });

    testWidgets(
      'onOpen launches a valid URL via url_launcher (lines 321-325)',
      (tester) async {
        when(
          () => mockUrlLauncher.canLaunch(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockUrlLauncher.launchUrl(any(), any()),
        ).thenAnswer((_) async => true);

        // Use a habit whose description contains a hyperlink.
        final habitWithLink = habitFlossing.copyWith(
          description: 'Visit https://example.com for info',
        );
        when(
          () => mockEntitiesCacheService.getHabitById(habitFlossing.id),
        ).thenAnswer((_) => habitWithLink);

        await tester.pumpWidget(
          makeTestableWidget(
            Material(
              child: HabitDescription(habitWithLink),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Find the Linkify widget and invoke its onOpen callback directly
        // to exercise the canLaunchUrl → launchUrl branch.
        final linkify = tester.widget<Linkify>(find.byType(Linkify));
        expect(linkify.onOpen, isNotNull);
        linkify.onOpen!(LinkableElement('example', 'https://example.com'));
        await tester.pump();

        verify(
          () => mockUrlLauncher.launchUrl('https://example.com', any()),
        ).called(1);
      },
    );

    testWidgets(
      'onOpen logs warning when URL cannot be launched (lines 327-334)',
      (tester) async {
        when(
          () => mockUrlLauncher.canLaunch(any()),
        ).thenAnswer((_) async => false);

        final habitWithLink = habitFlossing.copyWith(
          description: 'Visit https://bad.url for info',
        );
        when(
          () => mockEntitiesCacheService.getHabitById(habitFlossing.id),
        ).thenAnswer((_) => habitWithLink);

        await tester.pumpWidget(
          makeTestableWidget(
            Material(
              child: HabitDescription(habitWithLink),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final linkify = tester.widget<Linkify>(find.byType(Linkify));
        expect(linkify.onOpen, isNotNull);

        // Should not throw even when canLaunchUrl returns false.
        await expectLater(
          () async => linkify.onOpen!(
            LinkableElement('bad', 'https://bad.url'),
          ),
          returnsNormally,
        );

        // launchUrl must NOT have been called.
        verifyNever(() => mockUrlLauncher.launchUrl(any(), any()));
      },
    );
  });
}
