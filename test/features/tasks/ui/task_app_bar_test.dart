import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/task_app_bar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_entry_controller.dart';
import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await getIt.reset();
    getIt.allowReassignment = true;

    getIt.registerSingleton<TimeService>(TimeService());

    final mockCache = MockEntitiesCacheService();
    when(() => mockCache.getCategoryById(any())).thenReturn(null);
    getIt.registerSingleton<EntitiesCacheService>(mockCache);

    final mockNotifications = MockUpdateNotifications();
    when(() => mockNotifications.updateStream)
        .thenAnswer((_) => const Stream.empty());
    getIt.registerSingleton<UpdateNotifications>(mockNotifications);
  });

  tearDown(() async {
    await getIt.reset();
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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
    testWidgets('renders SliverAppBar for task without cover art',
        (tester) async {
      final task = buildTask();

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [createEntryControllerOverride(task)],
          child: const TaskSliverAppBar(taskId: 'task-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SliverAppBar), findsOneWidget);
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

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
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

      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('uses JournalSliverAppBar when entry is null', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const TaskSliverAppBar(taskId: 'nonexistent'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SliverAppBar), findsOneWidget);
    });
  });
}
