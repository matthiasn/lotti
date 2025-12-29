import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/labels/ui/widgets/label_selection_modal_utils.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('LabelSelectionStickyActionBar', () {
    testWidgets('renders cancel and apply buttons', (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LabelSelectionStickyActionBar(applyController: applyController),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);

      applyController.dispose();
    });

    testWidgets('apply button is disabled when applyController is null',
        (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LabelSelectionStickyActionBar(applyController: applyController),
        ),
      );
      await tester.pumpAndSettle();

      final filledButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Apply'),
      );
      expect(filledButton.onPressed, isNull);

      applyController.dispose();
    });

    testWidgets('apply button is enabled when applyController has function',
        (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(
        () async => true,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LabelSelectionStickyActionBar(applyController: applyController),
        ),
      );
      await tester.pumpAndSettle();

      final filledButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Apply'),
      );
      expect(filledButton.onPressed, isNotNull);

      applyController.dispose();
    });

    testWidgets('cancel button has OutlinedButton style', (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LabelSelectionStickyActionBar(applyController: applyController),
        ),
      );
      await tester.pumpAndSettle();

      // Cancel button should be an OutlinedButton
      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);

      applyController.dispose();
    });

    testWidgets('apply button has FilledButton style', (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LabelSelectionStickyActionBar(applyController: applyController),
        ),
      );
      await tester.pumpAndSettle();

      // Apply button should be a FilledButton
      expect(find.widgetWithText(FilledButton, 'Apply'), findsOneWidget);

      applyController.dispose();
    });

    testWidgets('apply button shows snackbar on failure', (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(
        () async => false,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LabelSelectionStickyActionBar(applyController: applyController),
        ),
      );
      await tester.pumpAndSettle();

      // Tap apply
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Snackbar should show error message
      expect(find.text('Failed to update labels'), findsOneWidget);

      applyController.dispose();
    });

    testWidgets('button state updates when controller value changes',
        (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LabelSelectionStickyActionBar(applyController: applyController),
        ),
      );
      await tester.pumpAndSettle();

      // Initially disabled
      var filledButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Apply'),
      );
      expect(filledButton.onPressed, isNull);

      // Update controller
      applyController.value = () async => true;
      await tester.pump();

      // Now enabled
      filledButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Apply'),
      );
      expect(filledButton.onPressed, isNotNull);

      applyController.dispose();
    });
  });
}
