import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/widgets/task_action_bar.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../helpers/path_provider.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

/// Stand-in audio recorder controller so widget tests pumping the task
/// details page (which now hosts [TaskActionBar], which watches
/// [audioRecorderControllerProvider]) don't try to boot the real
/// recorder repository — that depends on platform plugins not present
/// in the test runtime.
class _StubAudioRecorderController extends AudioRecorderController {
  @override
  AudioRecorderState build() => AudioRecorderState(
    status: AudioRecorderStatus.stopped,
    progress: Duration.zero,
    vu: -20,
    dBFS: -160,
    showIndicator: false,
    modalVisible: false,
  );
}

List<Override> _taskDetailsPageOverrides() => [
  audioRecorderControllerProvider.overrideWith(
    _StubAudioRecorderController.new,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockEntitiesCacheService = MockEntitiesCacheService();

  group('TaskDetailPage Widget Tests - ', () {
    setUpAll(() {
      setFakeDocumentsPath();
      registerFallbackValue(FakeMeasurementData());
    });

    setUp(() async {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);
      mockPersistenceLogic = MockPersistenceLogic();

      final mockTimeService = MockTimeService();
      final mockEditorStateService = MockEditorStateService();
      final mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(() => mockEntitiesCacheService.sortedCategories).thenAnswer(
        (_) => [categoryMindfulness],
      );
      when(
        () => mockEntitiesCacheService.sortedLabels,
      ).thenReturn(<LabelDefinition>[]);
      when(() => mockEntitiesCacheService.getLabelById(any())).thenReturn(null);

      when(
        () => mockJournalDb.getMeasurableDataTypeById(
          '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer((_) async => measurableWater);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(() => mockJournalDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          },
        ]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      when(
        () => mockJournalDb.getLinkedEntities(testTask.meta.id),
      ).thenAnswer(
        (_) async => [testTextEntry],
      );

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

      when(
        () => mockJournalDb.getMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer((_) async => []);

      // Ensure ThemingController dependencies are registered
      ensureThemingServicesRegistered();
    });
    tearDown(getIt.reset);

    testWidgets('Task Entry is rendered', (tester) async {
      when(
        () => mockJournalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TaskDetailsPage(taskId: testTask.id),
          overrides: _taskDetailsPageOverrides(),
        ),
      );

      await tester.pumpAndSettle();

      // TODO: test that entry text is rendered

      // test task displays progress bar (now in Labels row)
      final progressBarFinder = find.byType(LinearProgressIndicator);
      if (progressBarFinder.evaluate().isNotEmpty) {
        final progressBar =
            tester.firstWidget(progressBarFinder) as LinearProgressIndicator;
        expect(progressBar, isNotNull);
        expect(progressBar.value, 0.25);
      }

      // test task title is displayed once (inside the new desktop header).
      expect(find.text(testTask.data.title), findsOneWidget);

      // The legacy FAB has been replaced by the sticky TaskActionBar
      // pinned at the bottom of the page.
      expect(find.byType(TaskActionBar), findsOneWidget);

      // Background matches sidebar / Figma background/01.
      final scaffold = tester.widget<Scaffold>(
        find
            .descendant(
              of: find.byType(TaskDetailsPage),
              matching: find.byType(Scaffold),
            )
            .first,
      );
      final context = tester.element(find.byType(TaskDetailsPage));
      expect(
        scaffold.backgroundColor,
        context.designTokens.colors.background.level01,
      );
      // Scaffold no longer hosts a FAB; the action bar sits in the body
      // Stack so it stacks correctly with the AI overlay above it.
      expect(scaffold.floatingActionButton, isNull);
    });

    testWidgets(
      'wraps task scaffold in a nested ScaffoldMessenger on every platform '
      'so toasts float above the sticky action bar instead of the screen '
      'bottom edge',
      (tester) async {
        when(
          () => mockJournalDb.journalEntityById(testTask.meta.id),
        ).thenAnswer((_) async => testTask);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            TaskDetailsPage(taskId: testTask.id),
            overrides: _taskDetailsPageOverrides(),
          ),
        );
        await tester.pumpAndSettle();

        // The nested messenger is mounted inside the TaskDetailsPage
        // subtree, so a context resolving via ScaffoldMessenger.of from
        // within the page (e.g. from TaskActionBar) hits the nested one
        // and SnackBars float above the sticky action bar — not at the
        // screen / window bottom owned by the outer/root messenger.
        final nestedFinder = find.descendant(
          of: find.byType(TaskDetailsPage),
          matching: find.byType(ScaffoldMessenger),
        );
        expect(nestedFinder, findsOneWidget);

        final nestedMessengerState = tester.state<ScaffoldMessengerState>(
          nestedFinder,
        );
        final innerContext = tester.element(find.byType(TaskActionBar));
        expect(
          ScaffoldMessenger.of(innerContext),
          same(nestedMessengerState),
        );
      },
    );
  });

  group('TaskDetailsPage Auto-Scroll Tests - ', () {
    setUpAll(() {
      setFakeDocumentsPath();
      registerFallbackValue(FakeMeasurementData());
    });

    setUp(() async {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);
      mockPersistenceLogic = MockPersistenceLogic();

      final mockTimeService = MockTimeService();
      final mockEditorStateService = MockEditorStateService();
      final mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(() => mockEntitiesCacheService.sortedCategories).thenAnswer(
        (_) => [categoryMindfulness],
      );
      when(
        () => mockEntitiesCacheService.sortedLabels,
      ).thenReturn(<LabelDefinition>[]);
      when(() => mockEntitiesCacheService.getLabelById(any())).thenReturn(null);

      when(
        () => mockJournalDb.getMeasurableDataTypeById(
          '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer((_) async => measurableWater);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(() => mockJournalDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          },
        ]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      when(
        () => mockJournalDb.getLinkedEntities(testTask.meta.id),
      ).thenAnswer(
        (_) async => [testTextEntry],
      );

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

      when(
        () => mockJournalDb.getMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer((_) async => []);

      when(
        () => mockJournalDb.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => testTask);

      // Ensure ThemingController dependencies are registered
      ensureThemingServicesRegistered();
    });

    tearDown(getIt.reset);

    testWidgets('focus intent triggers scroll to entry', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TaskDetailsPage(taskId: testTask.id),
          overrides: _taskDetailsPageOverrides(),
        ),
      );

      // Allow scroll retry/backoff to complete and clear intent over multiple frames
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Publish focus intent
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TaskDetailsPage)),
      );

      container
          .read(taskFocusControllerProvider(id: testTask.id).notifier)
          .publishTaskFocus(
            entryId: testTextEntry.meta.id,
          );

      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 20 &&
            container.read(taskFocusControllerProvider(id: testTask.id)) !=
                null;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify intent was cleared after consumption
      final intent = container.read(
        taskFocusControllerProvider(id: testTask.id),
      );
      expect(intent, isNull);
    });

    testWidgets('pre-existing intent handled on page build', (tester) async {
      // Create a container and publish intent before building the page
      final container = ProviderContainer(
        overrides: _taskDetailsPageOverrides(),
      );

      container
          .read(taskFocusControllerProvider(id: testTask.id).notifier)
          .publishTaskFocus(
            entryId: testTextEntry.meta.id,
          );

      // Verify intent exists
      final intentBefore = container.read(
        taskFocusControllerProvider(id: testTask.id),
      );
      expect(intentBefore, isNotNull);
      expect(intentBefore!.entryId, equals(testTextEntry.meta.id));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(
            TaskDetailsPage(taskId: testTask.id),
          ),
        ),
      );

      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 20 &&
            container.read(taskFocusControllerProvider(id: testTask.id)) !=
                null;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify intent was cleared after handling
      final intentAfter = container.read(
        taskFocusControllerProvider(id: testTask.id),
      );
      expect(intentAfter, isNull);

      container.dispose();
    });
  });
}
