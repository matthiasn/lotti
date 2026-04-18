import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/tasks/ui/tasks_trailing_badge.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('TasksTrailingBadge', () {
    late TestGetItMocks mocks;

    setUp(() async {
      mocks = await setUpTestGetIt();
    });

    tearDown(tearDownTestGetIt);

    testWidgets('renders a danger-tone number badge when count > 0', (
      tester,
    ) async {
      when(mocks.journalDb.getTasksCount).thenAnswer((_) async => 7);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const TasksTrailingBadge()),
      );
      await tester.pumpAndSettle();

      expect(find.text('7'), findsOneWidget);
      final badge = tester.widget<DesignSystemBadge>(
        find.byType(DesignSystemBadge),
      );
      expect(badge.tone, DesignSystemBadgeTone.danger);
    });

    testWidgets('renders nothing when count is 0', (tester) async {
      when(mocks.journalDb.getTasksCount).thenAnswer((_) async => 0);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const TasksTrailingBadge()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesignSystemBadge), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('renders nothing while the count is still loading', (
      tester,
    ) async {
      // Never-completing future keeps the provider in loading state.
      when(mocks.journalDb.getTasksCount).thenAnswer(
        (_) => Completer<int>().future,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const TasksTrailingBadge()),
      );
      await tester.pump();

      expect(find.byType(DesignSystemBadge), findsNothing);
    });
  });
}
