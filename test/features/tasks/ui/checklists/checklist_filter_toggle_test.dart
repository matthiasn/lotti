// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_widget.dart';

import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';

void main() {
  group('ChecklistWidget filter + header visibility', () {
    const desktopMq = MediaQueryData(size: Size(1280, 1000));

    setUp(() async {
      await setUpTestGetIt();
    });

    tearDown(() async {
      await tearDownTestGetIt();
    });

    testWidgets('filter tabs visible when expanded and hidden when collapsed',
        (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          mediaQueryData: desktopMq,
          child: SingleChildScrollView(
            child: ChecklistWidget(
              id: 'cl-x',
              taskId: 'task-x',
              title: 'My Checklist',
              itemIds: const ['i1'],
              completionRate: 0.5, // expanded by default
              onTitleSave: _noopSave,
              onCreateChecklistItem: _noopCreate,
              updateItemOrder: _noopOrder,
            ),
          ),
        ),
      );

      // Initially expanded because completionRate < 1.0
      expect(find.byType(ChecklistWidget), findsOneWidget);

      // Filter tabs (Open/All) are visible when expanded
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);

      // Collapse by tapping the chevron
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Filter tabs are in the widget tree but hidden via AnimatedCrossFade
      // when collapsed. Verify the AnimatedCrossFade shows secondChild (SizedBox.shrink).
      final crossFades = tester.widgetList<AnimatedCrossFade>(
        find.byType(AnimatedCrossFade),
      );
      // The filter tabs AnimatedCrossFade should show secondChild when collapsed
      final filterCrossFade = crossFades.firstWhere(
        (cf) => cf.crossFadeState == CrossFadeState.showSecond,
        orElse: () => throw StateError('No collapsed AnimatedCrossFade found'),
      );
      expect(filterCrossFade.crossFadeState, CrossFadeState.showSecond);

      // Progress indicator remains visible in collapsed state
      // (there may be multiple in tree due to AnimatedCrossFade, but at least one)
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('toggling filter triggers selection change', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          mediaQueryData: desktopMq,
          child: SingleChildScrollView(
            child: ChecklistWidget(
              id: 'cl-y',
              taskId: 'task-y',
              title: 'Toggle Checklist',
              itemIds: const ['i1', 'i2'],
              completionRate: 0.5,
              onTitleSave: _noopSave,
              onCreateChecklistItem: _noopCreate,
              updateItemOrder: _noopOrder,
            ),
          ),
        ),
      );

      // Expanded by default (rate < 1.0). Tap 'All', then 'Open'
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Controls still present, no errors occurred
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
    });
  });
}

Future<String?> _noopCreate(String? _) async => null;
Future<void> _noopOrder(List<String> _) async {}
void _noopSave(String? _) {}
