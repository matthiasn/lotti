import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/ui/cover_art_background.dart';
import 'package:lotti/features/tasks/ui/task_expandable_app_bar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';
import 'package:lotti/widgets/app_bar/glass_back_button.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockDocumentsDirectory;

  setUp(() async {
    await getIt.reset();
    getIt.allowReassignment = true;

    mockDocumentsDirectory =
        Directory.systemTemp.createTempSync('task_expandable_app_bar_test_');
    getIt.registerSingleton<Directory>(mockDocumentsDirectory);

    final mockEditorStateService = MockEditorStateService();
    final mockPersistenceLogic = MockPersistenceLogic();
    final mockJournalDb = MockJournalDb();
    final mockUpdateNotifications = MockUpdateNotifications();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => const Stream<Set<String>>.empty());

    getIt
      ..registerSingleton<EditorStateService>(mockEditorStateService)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDown(() async {
    await getIt.reset();
    try {
      mockDocumentsDirectory.deleteSync(recursive: true);
    } catch (_) {}
  });

  Task buildTask({String id = 'task-1', String? coverArtId = 'image-1'}) {
    final now = DateTime(2025, 12, 31, 12);
    return Task(
      meta: Metadata(
        id: id,
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

  Widget buildTestWidget(Task task, String coverArtId) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              TaskExpandableAppBar(task: task, coverArtId: coverArtId),
            ],
          ),
        ),
      ),
    );
  }

  group('TaskExpandableAppBar', () {
    testWidgets('renders SliverAppBar', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task, 'image-1'));
      await tester.pump();

      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('renders GlassBackButton', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task, 'image-1'));
      await tester.pump();

      expect(find.byType(GlassBackButton), findsOneWidget);
    });

    testWidgets('renders chevron_left icon in back button', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task, 'image-1'));
      await tester.pump();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });

    testWidgets('renders GlassActionButtons for back and more menu',
        (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task, 'image-1'));
      await tester.pump();

      // GlassBackButton uses GlassActionButton internally, plus one for more menu
      expect(find.byType(GlassActionButton), findsNWidgets(2));
    });

    testWidgets('renders more_horiz icon', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task, 'image-1'));
      await tester.pump();

      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('contains CoverArtBackground', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task, 'image-1'));
      await tester.pump();

      expect(find.byType(CoverArtBackground), findsOneWidget);
    });

    testWidgets('CoverArtBackground receives correct imageId', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task, 'cover-123'));
      await tester.pump();

      final background = tester.widget<CoverArtBackground>(
        find.byType(CoverArtBackground),
      );
      expect(background.imageId, 'cover-123');
    });

    testWidgets('SliverAppBar is pinned', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task, 'image-1'));
      await tester.pump();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.pinned, isTrue);
    });

    testWidgets('SliverAppBar has correct toolbarHeight', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task, 'image-1'));
      await tester.pump();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.toolbarHeight, 40);
    });

    testWidgets('SliverAppBar has correct leadingWidth', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task, 'image-1'));
      await tester.pump();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.leadingWidth, 48);
    });

    testWidgets('does not automatically imply leading', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task, 'image-1'));
      await tester.pump();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.automaticallyImplyLeading, isFalse);
    });

    testWidgets('has expandedHeight based on screen width', (tester) async {
      final task = buildTask();

      // Use MediaQuery override to set a specific screen size
      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: CustomScrollView(
                  slivers: [
                    TaskExpandableAppBar(task: task, coverArtId: 'image-1'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      // 2:1 aspect ratio: 400 / 2 = 200
      expect(appBar.expandedHeight, 200);
    });

    testWidgets('contains FlexibleSpaceBar', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task, 'image-1'));
      await tester.pump();

      expect(find.byType(FlexibleSpaceBar), findsOneWidget);
    });

    testWidgets('back button icon is white', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task, 'image-1'));
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
      expect(icon.color, Colors.white);
    });

    testWidgets('more_horiz icon is white', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task, 'image-1'));
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.more_horiz));
      expect(icon.color, Colors.white);
    });
  });
}
