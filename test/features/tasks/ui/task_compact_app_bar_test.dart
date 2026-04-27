import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
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
  Future<double> build({required String id}) async => _offset;
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
  }) {
    return ProviderScope(
      overrides: overrides,
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

  group('TaskCompactAppBar', () {
    testWidgets('renders SliverAppBar', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pumpAndSettle();

      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('renders back button with chevron_left icon', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });

    testWidgets('renders more_horiz action button', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('SliverAppBar is pinned', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pumpAndSettle();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.pinned, isTrue);
    });

    testWidgets('SliverAppBar has correct toolbarHeight', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pumpAndSettle();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.toolbarHeight, 45);
    });

    testWidgets('SliverAppBar has correct leadingWidth', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pumpAndSettle();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.leadingWidth, 100);
    });

    testWidgets('does not automatically imply leading', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pumpAndSettle();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.automaticallyImplyLeading, isFalse);
    });

    testWidgets('has no expandedHeight (compact)', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pumpAndSettle();

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
            taskAppBarControllerProvider(id: task.id).overrideWith(
              () => _FixedOffsetController(0),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
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
              taskAppBarControllerProvider(id: task.id).overrideWith(
                () => _FixedOffsetController(200),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
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
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.chevron_left), findsNothing);
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
        await tester.pumpAndSettle();

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
