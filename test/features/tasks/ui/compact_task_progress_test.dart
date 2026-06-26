import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/compact_task_progress.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _FixedProgressController extends TaskProgressController {
  _FixedProgressController({
    required this.progress,
    required this.estimate,
  });

  final Duration progress;
  final Duration estimate;

  @override
  Future<TaskProgressState?> build() async {
    return TaskProgressState(progress: progress, estimate: estimate);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool originalIsDesktop;
  late bool originalIsMobile;

  setUpAll(() {
    // Scoped mock instead of a real TimeService (fake-time policy).
    final mockTimeService = MockTimeService();
    when(mockTimeService.getStream).thenAnswer((_) => const Stream.empty());
    when(() => mockTimeService.linkedFrom).thenReturn(null);
    when(mockTimeService.getCurrent).thenReturn(null);
    getIt
      ..pushNewScope()
      ..registerSingleton<TimeService>(mockTimeService);
  });

  tearDownAll(() async {
    await getIt.popScope();
  });

  setUp(() {
    // Capture original platform flags
    originalIsDesktop = platform.isDesktop;
    originalIsMobile = platform.isMobile;
  });

  tearDown(() {
    // Restore platform flags after each test to prevent cross-test pollution
    platform.isDesktop = originalIsDesktop;
    platform.isMobile = originalIsMobile;
  });

  Future<Widget> buildWithProgress({
    required String taskId,
    required Duration progress,
    required Duration estimate,
    ThemeData? theme,
  }) async {
    return ProviderScope(
      overrides: [
        taskProgressControllerProvider(taskId).overrideWith(
          () => _FixedProgressController(
            progress: progress,
            estimate: estimate,
          ),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: CompactTaskProgress(taskId: taskId),
          ),
        ),
      ),
    );
  }

  testWidgets('renders progress bar when task has estimate', (tester) async {
    const taskId = 'task-1';
    platform.isDesktop = false;
    platform.isMobile = true;

    final widget = await buildWithProgress(
      taskId: taskId,
      progress: const Duration(minutes: 30),
      estimate: const Duration(hours: 1),
    );
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('shows HH:MM text on desktop when isDesktop=true', (
    tester,
  ) async {
    const taskId = 'task-2';
    platform.isDesktop = true;
    platform.isMobile = false;

    final widget = await buildWithProgress(
      taskId: taskId,
      progress: const Duration(minutes: 30),
      estimate: const Duration(hours: 1),
    );
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final textFinder = find.descendant(
      of: find.byType(CompactTaskProgress),
      matching: find.byType(Text),
    );
    expect(textFinder, findsOneWidget);
    expect(tester.widget<Text>(textFinder).data, '00:30 / 01:00');
  });

  testWidgets('hides time text on mobile when isDesktop=false', (tester) async {
    const taskId = 'task-3';
    platform.isDesktop = false;
    platform.isMobile = true;

    final widget = await buildWithProgress(
      taskId: taskId,
      progress: const Duration(minutes: 30),
      estimate: const Duration(hours: 1),
    );
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final textFinder = find.descendant(
      of: find.byType(CompactTaskProgress),
      matching: find.byType(Text),
    );
    expect(textFinder, findsNothing);
  });

  testWidgets(
    'shows time text on mobile when showTimeText is true (header context)',
    (tester) async {
      const taskId = 'task-3b';
      platform.isDesktop = false;
      platform.isMobile = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskProgressControllerProvider(taskId).overrideWith(
              () => _FixedProgressController(
                progress: const Duration(minutes: 45),
                estimate: const Duration(hours: 1),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CompactTaskProgress(
                  taskId: taskId,
                  showTimeText: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final textFinder = find.descendant(
        of: find.byType(CompactTaskProgress),
        matching: find.byType(Text),
      );
      expect(textFinder, findsOneWidget);
    },
  );

  testWidgets('progress percentage is 50% for half duration', (tester) async {
    const taskId = 'task-4a';
    platform.isDesktop = false;
    platform.isMobile = true;

    final widget = await buildWithProgress(
      taskId: taskId,
      progress: const Duration(minutes: 30),
      estimate: const Duration(hours: 1),
    );
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, closeTo(0.5, 0.001));
  });

  testWidgets('progress percentage is 100% at or above estimate', (
    tester,
  ) async {
    const taskId = 'task-4b';
    platform.isDesktop = false;
    platform.isMobile = true;

    final widget = await buildWithProgress(
      taskId: taskId,
      progress: const Duration(hours: 1),
      estimate: const Duration(hours: 1),
    );
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, closeTo(1.0, 0.001));
  });

  testWidgets('progress percentage clamps at 100% when over estimate', (
    tester,
  ) async {
    const taskId = 'task-4c';
    platform.isDesktop = false;
    platform.isMobile = true;

    final widget = await buildWithProgress(
      taskId: taskId,
      progress: const Duration(hours: 2),
      estimate: const Duration(hours: 1),
    );
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, closeTo(1.0, 0.001));
  });

  testWidgets('renders nothing when estimate is zero', (tester) async {
    const taskId = 'task-5';
    platform.isDesktop = true;
    platform.isMobile = false;

    final widget = await buildWithProgress(
      taskId: taskId,
      progress: const Duration(minutes: 10),
      estimate: Duration.zero,
    );
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Only the outer widget exists; no progress bar is rendered.
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('uses tabular figures style for time text', (tester) async {
    const taskId = 'task-6';
    platform.isDesktop = true;
    platform.isMobile = false;

    final widget = await buildWithProgress(
      taskId: taskId,
      progress: const Duration(minutes: 41),
      estimate: const Duration(hours: 1, minutes: 50),
    );
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final textFinder = find.descendant(
      of: find.byType(CompactTaskProgress),
      matching: find.byType(Text),
    );
    final text = tester.widget<Text>(textFinder);
    final features = text.style?.fontFeatures ?? const <FontFeature>[];
    expect(features.any((f) => f.feature == 'tnum'), isTrue);
  });

  testWidgets('falls back to monoTabularStyle when titleSmall is null', (
    tester,
  ) async {
    const taskId = 'task-7';
    platform.isDesktop = true;
    platform.isMobile = false;

    final widget = await buildWithProgress(
      taskId: taskId,
      progress: const Duration(minutes: 30),
      estimate: const Duration(hours: 1),
      theme: ThemeData(textTheme: const TextTheme()),
    );
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final textFinder = find.descendant(
      of: find.byType(CompactTaskProgress),
      matching: find.byType(Text),
    );
    final text = tester.widget<Text>(textFinder);
    expect(text.style, isNotNull);
  });

  // Merged from the former *_timer_text_test.dart orphan (one
  // test file per source file).
  testWidgets('CompactTaskProgress text width is stable', (tester) async {
    const taskId = 'task-1';

    TaskProgressController makeController(
      Duration progress,
      Duration estimate,
    ) {
      return _FixedTimerTextProgressController(
        progress: progress,
        estimate: estimate,
      );
    }

    Future<void> pumpWith(
      Duration progress,
      Duration estimate,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskProgressControllerProvider(taskId).overrideWith(
              () => makeController(progress, estimate),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CompactTaskProgress(taskId: taskId),
              ),
            ),
          ),
        ),
      );
      // Async controller resolution + rebuild (no real animations to settle).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    const estimate = Duration(hours: 1, minutes: 50);
    await pumpWith(const Duration(minutes: 41), estimate);
    expect(find.byType(CompactTaskProgress), findsOneWidget);
    final textFinder = find.descendant(
      of: find.byType(CompactTaskProgress),
      matching: find.byType(Text),
    );
    expect(textFinder, findsOneWidget);
    final width1 = tester.getSize(textFinder).width;

    await pumpWith(const Duration(minutes: 48), estimate);
    final width2 = tester.getSize(textFinder).width;

    expect(width1, equals(width2));
  });
}

class _FixedTimerTextProgressController extends TaskProgressController {
  _FixedTimerTextProgressController({
    required this.progress,
    required this.estimate,
  });

  final Duration progress;
  final Duration estimate;

  @override
  Future<TaskProgressState?> build() async {
    return TaskProgressState(progress: progress, estimate: estimate);
  }
}
