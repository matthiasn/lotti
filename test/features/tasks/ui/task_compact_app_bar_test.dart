import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph/state/task_graph_provider.dart';
import 'package:lotti/features/knowledge_graph/ui/task_knowledge_graph_page.dart';
import 'package:lotti/features/tasks/state/task_app_bar_controller.dart';
import 'package:lotti/features/tasks/ui/task_compact_app_bar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/app_bar/glass_back_button.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

/// Test-only TaskAppBarController that emits a pinned scroll offset so the
/// persistent-title threshold check can be exercised deterministically.
class _FixedOffsetController extends TaskAppBarController {
  _FixedOffsetController(this._offset);

  final double _offset;

  @override
  Future<double> build() async => _offset;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Task buildTask({String id = 'task-1'}) {
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
      ),
    );
  }

  Widget buildTestWidget(
    Task task, {
    List<Override> overrides = const [],
    bool showGraphEntryPoint = true,
  }) {
    return ProviderScope(
      overrides: [
        knowledgeGraphEntryPointEnabledProvider.overrideWithValue(
          showGraphEntryPoint,
        ),
        ...overrides,
      ],
      child: MaterialApp(
        theme: DesignSystemTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              TaskCompactAppBar(task: task),
              const SliverToBoxAdapter(child: SizedBox(height: 1200)),
            ],
          ),
        ),
      ),
    );
  }

  /// Widens the surface past `kDesktopBreakpoint` (960). The knowledge-graph
  /// entry point is desktop-only — the graph is a pan-and-zoom canvas a
  /// phone-width window cannot render usefully — so any test that expects the
  /// hub glyph has to say which window it is in.
  ///
  /// Desktop also swaps the leading widget for `TaskDetailDesktopLeading`,
  /// which resolves `NavService` from getIt, so the stub goes in here too.
  void useDesktopSurface(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final nav = MockNavService();
    when(
      () => nav.desktopTaskDetailStack,
    ).thenReturn(ValueNotifier<List<String>>(<String>['task-1']));
    if (getIt.isRegistered<NavService>()) {
      getIt.unregister<NavService>();
    }
    getIt.registerSingleton<NavService>(nav);
    addTearDown(() {
      if (getIt.isRegistered<NavService>()) getIt.unregister<NavService>();
    });
  }

  group('TaskCompactAppBar', () {
    testWidgets('renders SliverAppBar', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('renders back button with chevron_left icon', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(LottiIcons.chevronLeft), findsOneWidget);
    });

    testWidgets('renders more_horiz action button', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(LottiIcons.more), findsOneWidget);
    });

    testWidgets('nested task context can hide the graph entry point', (
      tester,
    ) async {
      final task = buildTask();

      await tester.pumpWidget(
        buildTestWidget(task, showGraphEntryPoint: false),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(LottiIcons.hub), findsNothing);
    });

    testWidgets(
      'a phone-width window drops the hub glyph but keeps the overflow — the '
      'graph canvas is unusable at that width and the bar has two slots',
      (tester) async {
        final task = buildTask();
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildTestWidget(task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byIcon(LottiIcons.hub), findsNothing);
        expect(find.byIcon(LottiIcons.more), findsOneWidget);
      },
    );

    testWidgets(
      'both toolbar glyphs sit at medium emphasis, not the divider colour '
      'that made them near-invisible against the app bar',
      (tester) async {
        final task = buildTask();
        useDesktopSurface(tester);

        await tester.pumpWidget(buildTestWidget(task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final context = tester.element(find.byIcon(LottiIcons.more));
        final tokens = context.designTokens;
        for (final glyph in [LottiIcons.more, LottiIcons.hub]) {
          expect(
            tester.widget<Icon>(find.byIcon(glyph)).color,
            tokens.colors.text.mediumEmphasis,
            reason: 'toolbar glyphs must be legible against the app bar',
          );
          expect(
            tester.widget<Icon>(find.byIcon(glyph)).color,
            isNot(Theme.of(context).colorScheme.outline),
          );
        }
      },
    );

    testWidgets('shows the knowledge-graph hub button on desktop windows', (
      tester,
    ) async {
      final task = buildTask();
      useDesktopSurface(tester);

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(LottiIcons.hub), findsOneWidget);
    });

    testWidgets(
      'tapping the knowledge-graph hub button navigates to the graph page',
      (tester) async {
        final task = buildTask();
        useDesktopSurface(tester);

        await tester.pumpWidget(
          buildTestWidget(
            task,
            overrides: [
              // Null graph data renders the empty state, so the pushed page
              // builds without touching getIt<LoggingService> (only used in
              // the error listener) or any real graph computation.
              taskGraphProvider(task.id).overrideWith((ref) async => null),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byIcon(LottiIcons.hub));
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        expect(find.byType(TaskKnowledgeGraphPage), findsOneWidget);
      },
    );

    testWidgets('SliverAppBar is pinned', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.pinned, isTrue);
    });

    testWidgets('SliverAppBar has correct toolbarHeight', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.toolbarHeight, 45);
    });

    testWidgets('SliverAppBar has correct leadingWidth', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.leadingWidth, 100);
    });

    testWidgets('does not automatically imply leading', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.automaticallyImplyLeading, isFalse);
    });

    testWidgets('has no expandedHeight (compact)', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.expandedHeight, isNull);
    });

    testWidgets('hides the persistent title when scroll offset is near 0', (
      tester,
    ) async {
      final task = buildTask();
      await tester.pumpWidget(
        buildTestWidget(
          task,
          overrides: [
            taskAppBarControllerProvider(task.id).overrideWith(
              () => _FixedOffsetController(0),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Test Task'), findsNothing);
    });

    testWidgets(
      'shows the task title once scroll offset passes the threshold',
      (tester) async {
        final task = buildTask();
        await tester.pumpWidget(
          buildTestWidget(
            task,
            overrides: [
              taskAppBarControllerProvider(task.id).overrideWith(
                () => _FixedOffsetController(200),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Test Task'), findsOneWidget);
      },
    );
  });

  group('TaskCompactAppBar desktop back-arrow visibility', () {
    late MockNavService mockNavService;
    late ValueNotifier<List<String>> stackNotifier;

    setUp(() {
      mockNavService = MockNavService();
      stackNotifier = ValueNotifier<List<String>>(<String>['task-base']);
      when(
        () => mockNavService.desktopTaskDetailStack,
      ).thenReturn(stackNotifier);
      when(() => mockNavService.popDesktopTaskDetail()).thenAnswer((_) {});
      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
      getIt
        ..allowReassignment = true
        ..registerSingleton<NavService>(mockNavService);
    });

    tearDown(() {
      stackNotifier.dispose();
      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
    });

    testWidgets(
      'desktop with single-entry stack hides the back arrow',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1280, 800)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final task = buildTask();
        await tester.pumpWidget(buildTestWidget(task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byIcon(LottiIcons.chevronLeft), findsNothing);
      },
    );

    testWidgets(
      'desktop with multi-entry stack shows a glass back button '
      'and pops on tap',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1280, 800)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        stackNotifier.value = <String>['task-base', 'task-linked'];

        final task = buildTask(id: 'task-linked');
        await tester.pumpWidget(buildTestWidget(task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Compact bar uses the same GlassBackButton style as the
        // expandable bar on desktop pop, so the affordance stays
        // visually consistent across linked-task navigation.
        expect(find.byType(GlassBackButton), findsOneWidget);

        await tester.tap(find.byType(GlassBackButton));
        await tester.pump();

        verify(() => mockNavService.popDesktopTaskDetail()).called(1);
        verifyNever(() => mockNavService.beamBack(data: any(named: 'data')));
      },
    );
  });
}
