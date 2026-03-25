import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_task_filter_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemTaskFilterWidgetbookComponent', () {
    testWidgets('renders the task filter overview page', (tester) async {
      final component = buildDesignSystemTaskFilterWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Task filter modal');
      expect(useCase.name, 'Overview');
      await tester.binding.setSurfaceSize(const Size(1100, 1900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(
              body: SizedBox(
                width: 900,
                height: 1800,
                child: Builder(builder: useCase.builder),
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(1100, 1900)),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Mobile Preview'), findsOneWidget);
      expect(find.text('Apply filter'), findsOneWidget);
      expect(find.text('AI Coding'), findsOneWidget);
      expect(find.text('Agents'), findsOneWidget);
      expect(_serializedState(tester), contains('"selectedPriorityId": "p2"'));
    });

    testWidgets('updates serialized state through widget callbacks', (
      tester,
    ) async {
      final useCase =
          buildDesignSystemTaskFilterWidgetbookComponent().useCases.single;
      await tester.binding.setSurfaceSize(const Size(1100, 1900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(
              body: SizedBox(
                width: 900,
                height: 1800,
                child: Builder(builder: useCase.builder),
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(1100, 1900)),
        ),
      );
      await tester.pump();

      expect(_serializedState(tester), contains('"selectedPriorityId": "p2"'));
      expect(find.text('7'), findsOneWidget);

      final clearButton = find.byKey(
        const ValueKey('design-system-task-filter-clear'),
      );
      await tester.ensureVisible(clearButton);
      await tester.tap(clearButton);
      await tester.pump();

      expect(_serializedState(tester), contains('"selectedPriorityId": "all"'));
      expect(find.text('0'), findsOneWidget);

      final applyButton = find.byKey(
        const ValueKey('design-system-task-filter-apply'),
      );
      await tester.ensureVisible(applyButton);
      await tester.tap(applyButton);
      await tester.pump();

      expect(_serializedState(tester), contains('"selectedPriorityId": "all"'));
      expect(find.text('0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

String _serializedState(WidgetTester tester) {
  final statePanel = tester.widget<SelectableText>(find.byType(SelectableText));
  return statePanel.data ?? '';
}
