import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/tasks/state/task_live_data_provider.dart';
import 'package:lotti/features/tasks/state/task_one_liner_provider.dart';
import 'package:lotti/features/tasks/ui/widgets/task_list_detail_showcase.dart';
import 'package:lotti/features/tasks/widgetbook/task_list_detail_mock_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  Widget wrap(
    ProviderContainer container, {
    required ThemeData theme,
  }) {
    return makeTestableWidget2(
      UncontrolledProviderScope(
        container: container,
        child: Theme(
          data: theme,
          child: const Scaffold(
            body: SizedBox(
              width: 1440,
              height: 900,
              child: TaskListDetailShowcase(),
            ),
          ),
        ),
      ),
      mediaQueryData: const MediaQueryData(size: Size(1440, 900)),
    );
  }

  group('TaskListDetailShowcase', () {
    late ProviderContainer container;

    setUp(() async {
      await setUpTestGetIt(
        additionalSetup: () {
          final mockTimeService = MockTimeService();
          when(mockTimeService.getStream).thenAnswer(
            (_) => const Stream.empty(),
          );
          when(() => mockTimeService.linkedFrom).thenReturn(null);
          getIt.registerSingleton<TimeService>(mockTimeService);
        },
      );
      container = ProviderContainer(
        overrides: [
          taskLiveDataProvider.overrideWith(
            // ignore: avoid_redundant_argument_values
            (ref, taskId) => Future.value(null),
          ),
          taskOneLinerProvider.overrideWith(
            // ignore: avoid_redundant_argument_values
            (ref, taskId) => Future.value(null),
          ),
          agentUpdateStreamProvider.overrideWith(
            (ref, agentId) => const Stream<Set<String>>.empty(),
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await tearDownTestGetIt();
    });

    testWidgets('renders desktop list and detail panes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrap(
          container,
          theme: DesignSystemTheme.dark(),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Tasks'), findsAtLeastNWidgets(2));
      expect(find.text('Payment confirmation'), findsAtLeastNWidgets(2));
      expect(find.text('AI Task Summary'), findsOneWidget);
      expect(find.text('Time Tracker'), findsOneWidget);
      expect(find.text('Audio Recordings'), findsOneWidget);
    });

    testWidgets('updates the detail pane when selecting a task', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrap(
          container,
          theme: DesignSystemTheme.dark(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('User Testing').first);
      await tester.pump();

      expect(
        container
            .read(taskListDetailShowcaseControllerProvider)
            .selectedTask
            ?.task
            .meta
            .id,
        'user-testing',
      );
      expect(find.text('User Testing'), findsAtLeastNWidgets(2));
    });

    testWidgets('applies the desktop priority filter', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrap(
          container,
          theme: DesignSystemTheme.dark(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.tune_rounded).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Apply filter'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('design-system-task-filter-priority-p1')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('design-system-task-filter-apply')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('User Testing'), findsNothing);
      expect(find.text('Payment confirmation'), findsAtLeastNWidgets(2));
      expect(find.text('Sprint Planning'), findsOneWidget);
    });
  });
}
