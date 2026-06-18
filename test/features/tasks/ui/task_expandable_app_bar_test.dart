import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/knowledge_graph_poc/state/task_graph_provider.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/task_knowledge_graph_page.dart';
import 'package:lotti/features/tasks/state/task_app_bar_controller.dart';
import 'package:lotti/features/tasks/ui/cover_art_background.dart';
import 'package:lotti/features/tasks/ui/task_expandable_app_bar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
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

    mockDocumentsDirectory = Directory.systemTemp.createTempSync(
      'task_expandable_app_bar_test_',
    );
    getIt.registerSingleton<Directory>(mockDocumentsDirectory);

    final mockEditorStateService = MockEditorStateService();
    final mockPersistenceLogic = MockPersistenceLogic();
    final mockJournalDb = MockJournalDb();
    final mockUpdateNotifications = MockUpdateNotifications();

    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());

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

  Widget buildTestWidget(
    Task task,
    String coverArtId, {
    double? initialOffset,
    bool enableGraph = false,
  }) {
    return ProviderScope(
      overrides: [
        configFlagProvider(
          enableKnowledgeGraphFlag,
        ).overrideWith((ref) => Stream<bool>.value(enableGraph)),
        // Harmless when the graph isn't opened; when it is, null data renders
        // the empty state so the pushed page builds without real graph
        // computation or getIt<LoggingService> (only the error listener uses
        // it).
        taskGraphProvider(task.id).overrideWith((ref) async => null),
        if (initialOffset != null)
          taskAppBarControllerProvider(id: task.id).overrideWith(
            () => _FixedOffsetTaskAppBarController(initialOffset),
          ),
      ],
      child: MaterialApp(
        theme: DesignSystemTheme.dark(),
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

  /// Pin `tester.view.physicalSize` and `devicePixelRatio` to a known
  /// mobile-width value before pumping so `isDesktopLayout(context)` reads
  /// `false` (width < 960) regardless of whatever view overrides another
  /// test file may have leaked into the binding in a `very_good test`
  /// (single-isolate) run. We override the *view* (not just the binding's
  /// surface size) because `tester.view.physicalSize` takes precedence
  /// over `setSurfaceSize`, and a leftover view override from an upstream
  /// test cannot otherwise be cleared.
  ///
  /// Tests that need the desktop layout call `tester.pumpWidget` directly
  /// and set their own `tester.view.physicalSize`.
  Future<void> pumpMobile(WidgetTester tester, Widget widget) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(widget);
  }

  group('TaskExpandableAppBar', () {
    testWidgets('renders SliverAppBar', (tester) async {
      final task = buildTask();

      await pumpMobile(tester, buildTestWidget(task, 'image-1'));
      await tester.pump();

      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('renders GlassBackButton', (tester) async {
      final task = buildTask();

      await pumpMobile(tester, buildTestWidget(task, 'image-1'));
      await tester.pump();

      expect(find.byType(GlassBackButton), findsOneWidget);
    });

    testWidgets('renders chevron_left icon in back button', (tester) async {
      final task = buildTask();

      await pumpMobile(tester, buildTestWidget(task, 'image-1'));
      await tester.pump();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });

    testWidgets(
      'with the knowledge-graph flag off renders only back and more menu',
      (tester) async {
        final task = buildTask();

        await pumpMobile(tester, buildTestWidget(task, 'image-1'));
        await tester.pump();

        // GlassBackButton uses GlassActionButton internally, plus one for the
        // more menu. The knowledge-graph hub button is gated behind the flag.
        expect(find.byType(GlassActionButton), findsNWidgets(2));
        expect(find.byIcon(Icons.hub_outlined), findsNothing);
      },
    );

    testWidgets(
      'with the knowledge-graph flag on renders the hub button too',
      (tester) async {
        final task = buildTask();

        await pumpMobile(
          tester,
          buildTestWidget(task, 'image-1', enableGraph: true),
        );
        await tester.pump();

        // Back + knowledge-graph hub + more menu.
        expect(find.byType(GlassActionButton), findsNWidgets(3));
        expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the knowledge-graph hub button navigates to the graph page',
      (tester) async {
        final task = buildTask();

        await pumpMobile(
          tester,
          buildTestWidget(task, 'image-1', enableGraph: true),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.hub_outlined));
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        expect(find.byType(TaskKnowledgeGraphPage), findsOneWidget);
      },
    );

    testWidgets('renders more_horiz icon', (tester) async {
      final task = buildTask();

      await pumpMobile(tester, buildTestWidget(task, 'image-1'));
      await tester.pump();

      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('contains CoverArtBackground', (tester) async {
      final task = buildTask();

      await pumpMobile(tester, buildTestWidget(task, 'image-1'));
      await tester.pump();

      expect(find.byType(CoverArtBackground), findsOneWidget);
    });

    testWidgets('CoverArtBackground receives correct imageId', (tester) async {
      final task = buildTask();

      await pumpMobile(tester, buildTestWidget(task, 'cover-123'));
      await tester.pump();

      final background = tester.widget<CoverArtBackground>(
        find.byType(CoverArtBackground),
      );
      expect(background.imageId, 'cover-123');
    });

    testWidgets('SliverAppBar is pinned', (tester) async {
      final task = buildTask();

      await pumpMobile(tester, buildTestWidget(task, 'image-1'));
      await tester.pump();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.pinned, isTrue);
    });

    testWidgets('SliverAppBar has correct toolbarHeight', (tester) async {
      final task = buildTask();

      await pumpMobile(tester, buildTestWidget(task, 'image-1'));
      await tester.pump();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.toolbarHeight, 40);
    });

    testWidgets('SliverAppBar has correct leadingWidth', (tester) async {
      final task = buildTask();

      await pumpMobile(tester, buildTestWidget(task, 'image-1'));
      await tester.pump();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.leadingWidth, 48);
    });

    testWidgets('does not automatically imply leading', (tester) async {
      final task = buildTask();

      await pumpMobile(tester, buildTestWidget(task, 'image-1'));
      await tester.pump();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.automaticallyImplyLeading, isFalse);
    });

    testWidgets('has expandedHeight based on available width', (tester) async {
      final task = buildTask();

      // Set a specific surface size so the SliverLayoutBuilder's
      // crossAxisExtent is deterministic.
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpMobile(tester, buildTestWidget(task, 'image-1'));
      await tester.pump();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      // 16:9 aspect ratio: 400 * 9 / 16 = 225
      expect(appBar.expandedHeight, 225);
    });

    testWidgets('contains FlexibleSpaceBar', (tester) async {
      final task = buildTask();

      await pumpMobile(tester, buildTestWidget(task, 'image-1'));
      await tester.pump();

      expect(find.byType(FlexibleSpaceBar), findsOneWidget);
    });

    testWidgets('back button icon is white', (tester) async {
      final task = buildTask();

      await pumpMobile(tester, buildTestWidget(task, 'image-1'));
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
      expect(icon.color, Colors.white);
    });

    testWidgets('more_horiz icon is white', (tester) async {
      final task = buildTask();

      await pumpMobile(tester, buildTestWidget(task, 'image-1'));
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.more_horiz));
      expect(icon.color, Colors.white);
    });

    testWidgets(
      'hides the compact title when the cover has not yet scrolled out',
      (tester) async {
        final task = buildTask();

        await tester.binding.setSurfaceSize(const Size(400, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await pumpMobile(
          tester,
          buildTestWidget(task, 'image-1', initialOffset: 0),
        );
        await tester.pumpAndSettle();

        // Test Task title is never shown in the app bar toolbar while the
        // cover is still in view.
        expect(find.text('Test Task'), findsNothing);
      },
    );

    testWidgets(
      'surfaces the compact title once offset passes 85% of expandedHeight',
      (tester) async {
        final task = buildTask();

        await tester.binding.setSurfaceSize(const Size(400, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // expandedHeight = 400 * 9/16 = 225 → threshold = 225 * 0.85 ≈ 191.25
        await pumpMobile(
          tester,
          buildTestWidget(task, 'image-1', initialOffset: 200),
        );
        await tester.pumpAndSettle();

        expect(find.text('Test Task'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the more menu opens the extended header modal',
      (tester) async {
        final task = buildTask();

        await pumpMobile(tester, buildTestWidget(task, 'image-1'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();

        // The modal surfaces the shared "entryActions" title — find it to
        // prove the modal opened without asserting on internal item wiring.
        expect(find.text('Actions'), findsOneWidget);
      },
    );
  });

  group('TaskExpandableAppBar desktop back-arrow visibility', () {
    late MockNavService mockNavService;
    late ValueNotifier<List<String>> stackNotifier;

    setUp(() {
      mockNavService = MockNavService();
      stackNotifier = ValueNotifier<List<String>>(<String>['task-base']);
      when(
        () => mockNavService.desktopTaskDetailStack,
      ).thenReturn(stackNotifier);
      when(() => mockNavService.popDesktopTaskDetail()).thenAnswer((_) {});
      getIt.registerSingleton<NavService>(mockNavService);
    });

    tearDown(() {
      stackNotifier.dispose();
    });

    testWidgets(
      'desktop with single-entry stack hides the GlassBackButton',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1280, 800)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final task = buildTask();
        await tester.pumpWidget(buildTestWidget(task, 'image-1'));
        await tester.pump();

        expect(find.byType(GlassBackButton), findsNothing);
      },
    );

    testWidgets(
      'desktop with multi-entry stack shows GlassBackButton and pops on tap',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1280, 800)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        stackNotifier.value = <String>['task-base', 'task-linked'];

        final task = buildTask(id: 'task-linked');
        await tester.pumpWidget(buildTestWidget(task, 'image-1'));
        await tester.pump();

        expect(find.byType(GlassBackButton), findsOneWidget);

        await tester.tap(find.byType(GlassBackButton));
        await tester.pump();

        verify(() => mockNavService.popDesktopTaskDetail()).called(1);
      },
    );
  });
}

class _FixedOffsetTaskAppBarController extends TaskAppBarController {
  _FixedOffsetTaskAppBarController(this._offset);

  final double _offset;

  @override
  Future<double> build({required String id}) async => _offset;
}
