import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_widget.dart';
import '../../../../test_helper.dart';

void main() {
  group('ChecklistWidget filter + header visibility', () {
    const desktopMq = MediaQueryData(size: Size(1280, 1000));

    testWidgets(
        'segmented control visible when expanded and hidden when collapsed',
        (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(
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
      expect(find.byType(ExpansionTile), findsOneWidget);
      // Segmented control (Open/All) is visible when expanded
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);

      // Collapse; controls should hide
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsNothing);
      expect(find.text('All'), findsNothing);
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);

      // Progress indicator remains visible in collapsed subtitle line
      // (indicates subtitle is still shown while collapsed)
      // Note: We don't import the internal type; just look for a progress indicator widget.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

Future<String?> _noopCreate(String? _) async => null;
Future<void> _noopOrder(List<String> _) async {}
void _noopSave(String? _) {}
