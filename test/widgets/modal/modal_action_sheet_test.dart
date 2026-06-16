import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';

import '../../widget_test_utils.dart';

/// Pumps a launcher screen with a single button that, when tapped, calls
/// [showModalActionSheet] with the supplied parameters and records the value
/// the future completes with into the returned list.
Future<List<T?>> _openSheet<T>(
  WidgetTester tester, {
  String? title,
  String? message,
  List<ModalSheetAction<T>> actions = const [],
  String? cancelLabel,
}) async {
  final result = <T?>[];

  await tester.pumpWidget(
    makeTestableWidget(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              final value = await showModalActionSheet<T>(
                context: context,
                title: title,
                message: message,
                actions: actions,
                cancelLabel: cancelLabel,
              );
              result.add(value);
            },
            child: const Text('open'),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  return result;
}

/// Resolves the [DesignSystemButton] rendering [label].
DesignSystemButton _buttonWithLabel(WidgetTester tester, String label) {
  return tester.widget<DesignSystemButton>(
    find.widgetWithText(DesignSystemButton, label),
  );
}

void main() {
  group('showModalActionSheet', () {
    testWidgets('renders title and message text', (tester) async {
      await _openSheet<String>(
        tester,
        title: 'My Title',
        message: 'My descriptive message',
        actions: const [ModalSheetAction(label: 'Action', key: 'a')],
      );

      expect(find.text('My Title'), findsOneWidget);
      expect(find.text('My descriptive message'), findsOneWidget);
    });

    testWidgets('omits message when null', (tester) async {
      await _openSheet<String>(
        tester,
        title: 'Only Title',
        actions: const [ModalSheetAction(label: 'Action', key: 'a')],
      );

      expect(find.text('Only Title'), findsOneWidget);
      // No message text rendered; only the title and the single action button.
      expect(find.byType(DesignSystemButton), findsOneWidget);
    });

    testWidgets('tapping an action pops with its key and dismisses the sheet', (
      tester,
    ) async {
      final result = await _openSheet<String>(
        tester,
        message: 'Pick one',
        actions: const [
          ModalSheetAction(label: 'First', key: 'first'),
          ModalSheetAction(label: 'Second', key: 'second'),
        ],
      );

      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();

      // Future completed with the tapped action's key.
      expect(result, <String?>['second']);
      // Sheet content is gone.
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsNothing);
      expect(find.text('Pick one'), findsNothing);
    });

    testWidgets('destructive action renders with the dangerTertiary variant, '
        'normal with tertiary', (tester) async {
      await _openSheet<String>(
        tester,
        actions: const [
          ModalSheetAction(label: 'Keep', key: 'keep'),
          ModalSheetAction(
            label: 'Delete',
            key: 'delete',
            isDestructiveAction: true,
          ),
        ],
      );

      expect(
        _buttonWithLabel(tester, 'Delete').variant,
        DesignSystemButtonVariant.dangerTertiary,
      );
      expect(
        _buttonWithLabel(tester, 'Keep').variant,
        DesignSystemButtonVariant.tertiary,
      );
    });

    testWidgets('cancel button dismisses the sheet and returns null', (
      tester,
    ) async {
      final result = await _openSheet<String>(
        tester,
        message: 'Confirm something',
        actions: const [ModalSheetAction(label: 'Proceed', key: 'go')],
        cancelLabel: 'Cancel',
      );

      // Cancel button is rendered alongside the action.
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Proceed'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dismissed via Navigator.pop(context) with no key -> null result.
      expect(result, <String?>[null]);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Proceed'), findsNothing);
      expect(find.text('Confirm something'), findsNothing);
    });

    testWidgets('omits cancel button when cancelLabel is null', (tester) async {
      await _openSheet<String>(
        tester,
        actions: const [ModalSheetAction(label: 'OnlyAction', key: 'x')],
      );

      expect(find.text('OnlyAction'), findsOneWidget);
      // Only the single action button is present, no cancel button.
      expect(find.byType(DesignSystemButton), findsOneWidget);
    });
  });
}
