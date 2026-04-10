import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/tasks/state/task_live_data_provider.dart';
import 'package:lotti/features/tasks/state/task_one_liner_provider.dart';
import 'package:lotti/features/tasks/ui/widgets/task_list_pane.dart';
import 'package:lotti/features/tasks/ui/widgets/task_mobile_list_detail_showcase.dart';
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
    required Size viewportSize,
  }) {
    return makeTestableWidget2(
      UncontrolledProviderScope(
        container: container,
        child: Theme(
          data: theme,
          child: Scaffold(
            body: SizedBox(
              width: viewportSize.width,
              height: viewportSize.height,
              child: const TaskMobileListDetailShowcase(),
            ),
          ),
        ),
      ),
      mediaQueryData: MediaQueryData(
        size: viewportSize,
        padding: phoneMediaQueryData.padding,
      ),
    );
  }

  group('TaskMobileListDetailShowcase', () {
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

    testWidgets('renders split list/detail layout and syncs selection', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(920, 920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrap(
          container,
          theme: DesignSystemTheme.dark(),
          viewportSize: const Size(920, 920),
        ),
      );
      await tester.pump();

      expect(find.text('Payment confirmation'), findsAtLeastNWidgets(2));
      expect(find.text('AI Task Summary'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('AI Task Summary')).style?.fontSize,
        14,
      );
      expect(
        tester.widget<Text>(find.text('AI Task Summary')).style?.fontWeight,
        FontWeight.w600,
      );
      expect(tester.widget<Text>(find.text('Today')).style?.fontSize, 14);
      expect(
        tester.widget<Text>(find.text('Today')).style?.fontWeight,
        FontWeight.w400,
      );
      expect(tester.widget<Text>(find.text('3 tasks')).style?.fontSize, 14);
      expect(
        tester.widget<Text>(find.text('3 tasks')).style?.fontWeight,
        FontWeight.w400,
      );
      expect(tester.widget<Text>(find.text('Read more')).style?.fontSize, 14);
      expect(
        tester.widget<Text>(find.text('User Testing').first).style,
        isNotNull,
      );
      expect(
        tester.widget<Text>(find.text('User Testing').first).style?.fontSize,
        14,
      );
      expect(
        tester.widget<Text>(find.text('User Testing').first).style?.fontWeight,
        FontWeight.w600,
      );
      expect(
        tester
            .widget<TaskListSectionsList>(find.byType(TaskListSectionsList))
            .bottomPadding,
        184,
      );
      expect(find.text('My Daily'), findsOneWidget);

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

    testWidgets('keeps selection when compact layout navigates back', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrap(
          container,
          theme: DesignSystemTheme.dark(),
          viewportSize: const Size(430, 920),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('User Testing').first);
      await tester.pump();

      expect(find.text('Back'), findsOneWidget);
      expect(find.text('My Daily'), findsNothing);
      expect(
        container
            .read(taskListDetailShowcaseControllerProvider)
            .selectedTask
            ?.task
            .meta
            .id,
        'user-testing',
      );

      await tester.tap(find.text('Back'));
      await tester.pump();

      expect(find.text('Tasks'), findsAtLeastNWidgets(2));
      expect(
        container
            .read(taskListDetailShowcaseControllerProvider)
            .selectedTask
            ?.task
            .meta
            .id,
        'user-testing',
      );
    });

    testWidgets('opens the mobile task filter sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrap(
          container,
          theme: DesignSystemTheme.dark(),
          viewportSize: const Size(430, 920),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.tune_rounded).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Apply filter'), findsOneWidget);
    });
  });
}
