// ignore_for_file: avoid_redundant_argument_values

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/journal_app_bar.dart';
import 'package:lotti/features/tasks/ui/task_app_bar.dart';
import 'package:lotti/features/tasks/ui/task_compact_app_bar.dart';
import 'package:lotti/features/tasks/ui/task_expandable_app_bar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_entry_controller.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documentsDir;

  setUp(() async {
    // The cover image resolves its file against the documents directory;
    // an empty temp dir means the cover renders its missing-file state.
    documentsDir = Directory.systemTemp.createTempSync('task_app_bar_test');
    await setUpTestGetIt(
      additionalSetup: () {
        final mockCache = MockEntitiesCacheService();
        when(() => mockCache.getCategoryById(any())).thenReturn(null);
        getIt
          ..registerSingleton<Directory>(documentsDir)
          ..registerSingleton<TimeService>(TimeService())
          ..registerSingleton<EntitiesCacheService>(mockCache)
          // EntryController resolves the editor-state service in a field
          // initializer; without it the overridden controller fails to
          // build and every test silently falls back to the journal bar.
          ..registerSingleton<EditorStateService>(MockEditorStateService());
      },
    );
  });

  tearDown(() async {
    await tearDownTestGetIt();
    documentsDir.deleteSync(recursive: true);
  });

  Task buildTask({String? coverArtId}) {
    final now = DateTime(2025, 12, 31, 12);
    return Task(
      meta: Metadata(
        id: 'task-1',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: now,
          utcOffset: 0,
        ),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
        title: 'Test Task',
        coverArtId: coverArtId,
      ),
    );
  }

  JournalImage buildImage({String id = 'image-1'}) {
    final now = DateTime(2025, 12, 31, 12);
    return JournalImage(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: ImageData(
        imageId: 'img-uuid',
        imageFile: 'test.jpg',
        imageDirectory: '/test/dir',
        capturedAt: now,
      ),
    );
  }

  Widget buildTestWidget({
    required Widget child,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        builder: LegacyMaterialBridge.builder,
        theme: DesignSystemTheme.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [child],
          ),
        ),
      ),
    );
  }

  group('TaskSliverAppBar', () {
    testWidgets('renders SliverAppBar for task without cover art', (
      tester,
    ) async {
      final task = buildTask();

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [createEntryControllerOverride(task)],
          child: const TaskSliverAppBar(taskId: 'task-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TaskCompactAppBar), findsOneWidget);
      expect(find.byType(TaskExpandableAppBar), findsNothing);
    });

    testWidgets('has back button with chevron_left icon', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [createEntryControllerOverride(task)],
          child: const TaskSliverAppBar(taskId: 'task-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LottiIcons.chevronLeft), findsOneWidget);
    });

    testWidgets('uses JournalSliverAppBar for non-Task entry', (tester) async {
      final image = buildImage(id: 'not-a-task');

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [createEntryControllerOverride(image)],
          child: const TaskSliverAppBar(taskId: 'not-a-task'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(JournalSliverAppBar), findsOneWidget);
      expect(find.byType(TaskCompactAppBar), findsNothing);
    });

    testWidgets('uses JournalSliverAppBar when entry is null', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const TaskSliverAppBar(taskId: 'nonexistent'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(JournalSliverAppBar), findsOneWidget);
    });

    testWidgets('renders expandable app bar when task has cover art', (
      tester,
    ) async {
      final task = buildTask(coverArtId: 'image-1');
      final image = buildImage(id: 'image-1');

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            createEntryControllerOverride(task),
            createEntryControllerOverride(image),
          ],
          child: const TaskSliverAppBar(taskId: 'task-1'),
        ),
      );
      await tester.pumpAndSettle();

      final expandable = tester.widget<TaskExpandableAppBar>(
        find.byType(TaskExpandableAppBar),
      );
      expect(expandable.coverArtId, 'image-1');
      expect(expandable.task.id, 'task-1');
      expect(find.byType(TaskCompactAppBar), findsNothing);
    });

    testWidgets('expandable app bar has chevron_left icon for back button', (
      tester,
    ) async {
      final task = buildTask(coverArtId: 'image-1');
      final image = buildImage(id: 'image-1');

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            createEntryControllerOverride(task),
            createEntryControllerOverride(image),
          ],
          child: const TaskSliverAppBar(taskId: 'task-1'),
        ),
      );
      await tester.pumpAndSettle();

      // App bar should have chevron_left icon for back navigation
      expect(find.byIcon(LottiIcons.chevronLeft), findsOneWidget);
    });

    testWidgets('task with cover art renders SliverAppBar correctly', (
      tester,
    ) async {
      final task = buildTask(coverArtId: 'image-1');
      final image = buildImage(id: 'image-1');

      // Set a specific screen size for consistent testing
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            createEntryControllerOverride(task),
            createEntryControllerOverride(image),
          ],
          child: const TaskSliverAppBar(taskId: 'task-1'),
        ),
      );
      await tester.pumpAndSettle();

      // The expanded height follows the 16:9 cover at the 400px width.
      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.expandedHeight, 400 * 9 / 16);

      // Reset surface size
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('task without cover art renders compact SliverAppBar', (
      tester,
    ) async {
      final task = buildTask();

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [createEntryControllerOverride(task)],
          child: const TaskSliverAppBar(taskId: 'task-1'),
        ),
      );
      await tester.pumpAndSettle();

      // Compact app bar has no expanded cover region.
      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.expandedHeight, isNull);
      // Should still have back button
      expect(find.byIcon(LottiIcons.chevronLeft), findsOneWidget);
    });
  });
}
