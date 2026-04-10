import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/tasks/state/task_live_data_provider.dart';
import 'package:lotti/features/tasks/state/task_one_liner_provider.dart';
import 'package:lotti/features/tasks/widgetbook/task_widgetbook.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
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
  });

  tearDown(tearDownTestGetIt);

  final showcaseOverrides = [
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
  ];

  group('buildTaskListDetailWidgetbookComponent', () {
    testWidgets('renders the desktop task list and detail showcase', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1700, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final component = buildTaskListDetailWidgetbookComponent();
      final useCase = component.useCases.firstWhere(
        (useCase) => useCase.name == 'Desktop',
      );

      expect(component.name, 'Task list & detail');
      expect(
        component.useCases.map((useCase) => useCase.name),
        ['Desktop', 'Mobile'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: showcaseOverrides,
          child: makeTestableWidget2(
            Theme(
              data: DesignSystemTheme.dark(),
              child: Scaffold(
                body: SizedBox(
                  width: 1440,
                  height: 900,
                  child: Builder(builder: useCase.builder),
                ),
              ),
            ),
            mediaQueryData: const MediaQueryData(size: Size(1600, 1000)),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Tasks'), findsAtLeastNWidgets(2));
      expect(find.text('Payment confirmation'), findsAtLeastNWidgets(2));
      expect(find.text('AI Task Summary'), findsOneWidget);
      expect(find.text('Audio Recordings'), findsOneWidget);
    });

    testWidgets('renders the mobile showcase in light mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final component = buildTaskListDetailWidgetbookComponent();
      final useCase = component.useCases.firstWhere(
        (useCase) => useCase.name == 'Mobile',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: showcaseOverrides,
          child: makeTestableWidget2(
            Theme(
              data: DesignSystemTheme.light(),
              child: Scaffold(
                body: SizedBox(
                  width: 920,
                  height: 920,
                  child: Builder(builder: useCase.builder),
                ),
              ),
            ),
            mediaQueryData: const MediaQueryData(size: Size(1100, 1000)),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Tasks'), findsAtLeastNWidgets(2));
      expect(find.text('AI Task Summary'), findsOneWidget);
    });
  });
}
