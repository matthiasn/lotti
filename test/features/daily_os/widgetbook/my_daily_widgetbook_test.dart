import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/features/daily_os/widgetbook/my_daily_widgetbook.dart';
import 'package:lotti/features/design_system/components/avatars/design_system_avatar.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_calendar_picker.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });

  tearDown(() async {
    await tearDownTestGetIt();
  });

  group('buildMyDailyWidgetbookFolder', () {
    test('exposes My Daily as a top-level Widgetbook folder', () {
      final folder = buildMyDailyWidgetbookFolder();

      expect(folder.name, 'My Daily');
      expect(folder.children, hasLength(1));
      expect(folder.children!.single.name, 'My Daily');
    });
  });

  group('buildMyDailyWidgetbookComponent', () {
    test('exposes the expected use cases', () {
      final component = buildMyDailyWidgetbookComponent();

      expect(component.name, 'My Daily');
      expect(
        component.useCases.map((useCase) => useCase.name),
        [
          'Overview',
          'Ongoing Day',
          'Filter By Time Block',
          'Filtered',
        ],
      );
    });

    test('selects compact, regular, and expanded density tiers', () {
      expect(
        myDailyTimelineBlockDensity(
          tokens: dsTokensDark,
          height: dsTokensDark.spacing.step9,
          duration: const Duration(minutes: 30),
        ),
        MyDailyTimelineBlockDensity.compact,
      );
      expect(
        myDailyTimelineBlockDensity(
          tokens: dsTokensDark,
          height: dsTokensDark.spacing.step10,
          duration: const Duration(minutes: 60),
        ),
        MyDailyTimelineBlockDensity.regular,
      );
      expect(
        myDailyTimelineBlockDensity(
          tokens: dsTokensDark,
          height: dsTokensDark.spacing.step10,
          duration: const Duration(minutes: 95),
        ),
        MyDailyTimelineBlockDensity.expanded,
      );
    });

    testWidgets('shows loading before settling into the ongoing preview', (
      tester,
    ) async {
      final useCase = _useCase('Ongoing Day');

      await tester.pumpWidget(_buildWidgetbookHarness(useCase));

      expect(find.byKey(const Key('my-daily-loading')), findsOneWidget);
      _expectNoPendingExceptions(tester);

      await _settlePreview(tester);

      _expectNoPendingExceptions(tester);
      expect(find.byKey(const Key('my-daily-loading')), findsNothing);
      expect(find.byType(DesignSystemAvatar), findsOneWidget);
      expect(find.byType(DesignSystemCalendarDateCard), findsNWidgets(7));
      expect(find.text('Good morning.'), findsOneWidget);
      expect(find.text('Day Summary'), findsOneWidget);
      expect(find.text('Tap to expand'), findsOneWidget);
      expect(find.text('Go skiing with Matt'), findsOneWidget);
      expect(find.text('Lunch break'), findsOneWidget);
      expect(find.text('3:00-4:00pm'), findsNWidgets(2));
      expect(find.text('Hiking with Daniella'), findsOneWidget);
      expect(find.text('Meeting with Dammy'), findsOneWidget);
      expect(find.byKey(const Key('my-daily-filter-holiday')), findsNothing);

      final holidayOpacity = tester.widget<Opacity>(
        find.byKey(const Key('my-daily-category-opacity-holiday')),
      );

      expect(holidayOpacity.opacity, 1);
    });

    testWidgets('date strip drives the provider-backed header and now marker', (
      tester,
    ) async {
      final useCase = _useCase('Ongoing Day');

      await tester.pumpWidget(_buildWidgetbookHarness(useCase));
      await _settlePreview(tester);

      _expectNoPendingExceptions(tester);
      expect(find.byKey(const Key('my-daily-date-header')), findsOneWidget);
      expect(find.text('Tuesday, October 17'), findsOneWidget);
      expect(find.byKey(const Key('my-daily-now-indicator')), findsOneWidget);

      await tester.tap(find.byKey(const Key('my-daily-date-2023-10-19')));
      await _settlePreview(tester);

      _expectNoPendingExceptions(tester);
      expect(find.text('Thursday, October 19'), findsOneWidget);
      expect(find.byKey(const Key('my-daily-now-indicator')), findsNothing);
    });

    testWidgets('filter-by-time-block starts with the expected chips active', (
      tester,
    ) async {
      final useCase = _useCase('Filter By Time Block');

      await tester.pumpWidget(_buildWidgetbookHarness(useCase));
      await _settlePreview(tester);

      _expectNoPendingExceptions(tester);
      expect(find.byKey(const Key('my-daily-filter-holiday')), findsOneWidget);
      expect(
        find.byKey(const Key('my-daily-filter-lotti-tasks')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('my-daily-filter-hiking')), findsOneWidget);
      expect(find.text('Holiday'), findsAtLeastNWidgets(1));
      expect(find.text('Lotti Tasks'), findsAtLeastNWidgets(1));

      final holidayOpacity = tester.widget<Opacity>(
        find.byKey(const Key('my-daily-category-opacity-holiday')),
      );
      final tasksOpacity = tester.widget<Opacity>(
        find.byKey(const Key('my-daily-category-opacity-lotti-tasks')),
      );
      final hikingOpacity = tester.widget<Opacity>(
        find.byKey(const Key('my-daily-category-opacity-hiking')),
      );

      expect(holidayOpacity.opacity, 1);
      expect(tasksOpacity.opacity, 1);
      expect(hikingOpacity.opacity, 1);
    });

    testWidgets('filtered preview toggles category emphasis on and off', (
      tester,
    ) async {
      final useCase = _useCase('Filtered');

      await tester.pumpWidget(_buildWidgetbookHarness(useCase));
      await _settlePreview(tester);

      _expectNoPendingExceptions(tester);

      final initialTasksOpacity = tester.widget<Opacity>(
        find.byKey(const Key('my-daily-category-opacity-lotti-tasks')),
      );
      final initialHolidayOpacity = tester.widget<Opacity>(
        find.byKey(const Key('my-daily-category-opacity-holiday')),
      );
      final initialHikingOpacity = tester.widget<Opacity>(
        find.byKey(const Key('my-daily-category-opacity-hiking')),
      );

      expect(initialTasksOpacity.opacity, 0.22);
      expect(initialHolidayOpacity.opacity, 1);
      expect(initialHikingOpacity.opacity, 1);

      await tester.tap(find.byKey(const Key('my-daily-filter-holiday')));
      await _settlePreview(tester);

      _expectNoPendingExceptions(tester);
      final activatedHolidayOpacity = tester.widget<Opacity>(
        find.byKey(const Key('my-daily-category-opacity-holiday')),
      );

      expect(activatedHolidayOpacity.opacity, 0.22);

      await tester.tap(find.byKey(const Key('my-daily-filter-lotti-tasks')));
      await _settlePreview(tester);

      _expectNoPendingExceptions(tester);
      final dimmedTasksOpacity = tester.widget<Opacity>(
        find.byKey(const Key('my-daily-category-opacity-lotti-tasks')),
      );

      expect(dimmedTasksOpacity.opacity, 1);
    });

    testWidgets('uses compact cards and detailed long-block layouts onscreen', (
      tester,
    ) async {
      final useCase = _useCase('Ongoing Day');

      await tester.pumpWidget(_buildWidgetbookHarness(useCase));
      await _settlePreview(tester);

      _expectNoPendingExceptions(tester);
      expect(
        find.byKey(const Key('my-daily-block-layout-skiing-recap-compact')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('my-daily-block-layout-lunch-break-compact')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('my-daily-block-layout-skiing-expanded')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('my-daily-block-layout-hiking-regular')),
        findsOneWidget,
      );
      expect(find.text('Meeting with Dammy'), findsOneWidget);
    });
  });
}

WidgetbookUseCase _useCase(String name) {
  final component = buildMyDailyWidgetbookComponent();
  return component.useCases.singleWhere((useCase) => useCase.name == name);
}

Widget _buildWidgetbookHarness(WidgetbookUseCase useCase) {
  return makeTestableWidgetWithScaffold(
    Builder(builder: useCase.builder),
    theme: DesignSystemTheme.dark(),
  );
}

Future<void> _settlePreview(WidgetTester tester) async {
  await tester.pump();
  final element = find.byType(WidgetbookViewport).evaluate().single;
  final container = ProviderScope.containerOf(element);

  await container.read(dailyOsControllerProvider.future);
  await container.read(timeHistoryHeaderControllerProvider.future);

  await tester.pump();
}

void _expectNoPendingExceptions(WidgetTester tester) {
  expect(_takePendingExceptions(tester), isEmpty);
}

List<Object> _takePendingExceptions(WidgetTester tester) {
  final exceptions = <Object>[];
  Object? exception;

  while ((exception = tester.takeException()) != null) {
    exceptions.add(exception!);
  }

  return exceptions;
}
