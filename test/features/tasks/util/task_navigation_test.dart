import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/features/tasks/util/task_navigation.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

class _PushTrackingObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }
}

void main() {
  late MockNavService mockNavService;

  setUp(() async {
    mockNavService = MockNavService();
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<NavService>(mockNavService);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  /// Pumps a button that calls [openLinkedTaskDetail] on a surface of
  /// [width] logical pixels, returning the navigator observer.
  Future<_PushTrackingObserver> pumpLauncher(
    WidgetTester tester, {
    required double width,
    bool focusSuggestions = false,
    ProviderContainer? container,
  }) async {
    final observer = _PushTrackingObserver();
    final app = MaterialApp(
      navigatorObservers: [observer],
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => openLinkedTaskDetail(
              context: context,
              taskId: 'task-9',
              focusSuggestions: focusSuggestions,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      container != null
          ? UncontrolledProviderScope(container: container, child: app)
          : ProviderScope(child: app),
    );
    // Clear the initial route push so assertions only see ours.
    observer.pushedRoutes.clear();
    return observer;
  }

  group('openLinkedTaskDetail', () {
    testWidgets('desktop widths push onto the NavService detail stack', (
      tester,
    ) async {
      final observer = await pumpLauncher(tester, width: 1280);

      await tester.tap(find.text('open'));

      verify(() => mockNavService.pushDesktopTaskDetail('task-9')).called(1);
      // No navigator route was pushed — the list pane stays visible.
      expect(observer.pushedRoutes, isEmpty);
    });

    testWidgets('mobile widths push a MaterialPageRoute instead', (
      tester,
    ) async {
      final observer = await pumpLauncher(tester, width: 400);

      await tester.tap(find.text('open'));

      verifyNever(() => mockNavService.pushDesktopTaskDetail(any()));
      expect(
        observer.pushedRoutes.whereType<MaterialPageRoute<void>>(),
        hasLength(1),
      );

      // Pop before the pushed route ever builds: TaskDetailsPage needs the
      // full app environment, which is out of scope for a routing test.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
    });

    testWidgets('focusSuggestions publishes a focus intent before navigating', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(
        taskFocusControllerProvider(id: 'task-9'),
        (_, _) {},
      );
      addTearDown(sub.close);

      await pumpLauncher(
        tester,
        width: 1280,
        focusSuggestions: true,
        container: container,
      );

      await tester.tap(find.text('open'));

      final intent = container.read(taskFocusControllerProvider(id: 'task-9'));
      expect(intent, isNotNull);
      expect(intent!.taskId, 'task-9');
      verify(() => mockNavService.pushDesktopTaskDetail('task-9')).called(1);
    });
  });
}
