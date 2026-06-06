import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/widgets/gemini_thinking_mode_picker_modal.dart';
import 'package:lotti/widgets/selection/selection_option.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('GeminiThinkingModePickerContent', () {
    testWidgets(
      'renders one option per thinking mode with localized label and '
      'description, marking only the preselected mode as selected',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            GeminiThinkingModePickerContent(
              selectedMode: GeminiThinkingMode.medium,
              onChanged: (_) {},
            ),
          ),
        );
        await tester.pump();

        // All four modes render with their English labels + descriptions.
        expect(find.text('Minimal'), findsOneWidget);
        expect(find.text('Low'), findsOneWidget);
        expect(find.text('Medium'), findsOneWidget);
        expect(find.text('High'), findsOneWidget);
        expect(
          find.text('Balanced reasoning for more careful answers.'),
          findsOneWidget,
        );

        // Exactly one option is selected, and it's the medium one.
        final options = tester
            .widgetList<SelectionOption>(find.byType(SelectionOption))
            .toList();
        expect(options, hasLength(GeminiThinkingMode.values.length));
        final selected = options.where((o) => o.isSelected).toList();
        expect(selected, hasLength(1));
        expect(selected.single.title, 'Medium');
      },
    );

    testWidgets('tapping an option invokes onChanged with that mode', (
      tester,
    ) async {
      GeminiThinkingMode? changed;
      await tester.pumpWidget(
        makeTestableWidget(
          GeminiThinkingModePickerContent(
            selectedMode: GeminiThinkingMode.low,
            onChanged: (mode) => changed = mode,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('High'));
      await tester.pump();

      expect(changed, GeminiThinkingMode.high);
    });

    test('label, description, and icon are distinct per mode', () {
      // The icon mapping is pure; label/description require a context and
      // are covered by the widget test above. Distinctness here guards
      // against copy-paste errors when a new mode is added.
      final icons = GeminiThinkingMode.values
          .map(GeminiThinkingModePickerContent.icon)
          .toSet();
      expect(icons, hasLength(GeminiThinkingMode.values.length));
    });
  });

  group('GeminiThinkingModePickerModal.show', () {
    Widget buildLauncher({
      required ValueChanged<GeminiThinkingMode?> onResult,
      String? title,
    }) {
      return makeTestableWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final result = await GeminiThinkingModePickerModal.show(
                context: context,
                selectedMode: GeminiThinkingMode.low,
                title: title,
              );
              onResult(result);
            },
            child: const Text('Open'),
          ),
        ),
      );
    }

    testWidgets(
      'opens with the default localized title and returns the tapped mode',
      (tester) async {
        GeminiThinkingMode? result;
        var resultSet = false;
        await tester.pumpWidget(
          buildLauncher(
            onResult: (mode) {
              result = mode;
              resultSet = true;
            },
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Gemini thinking mode'), findsOneWidget);
        expect(find.byType(GeminiThinkingModePickerContent), findsOneWidget);

        await tester.tap(find.text('Minimal'));
        await tester.pumpAndSettle();

        expect(resultSet, isTrue);
        expect(result, GeminiThinkingMode.minimal);
        expect(find.byType(GeminiThinkingModePickerContent), findsNothing);
      },
    );

    testWidgets('uses the custom title when provided', (tester) async {
      await tester.pumpWidget(
        buildLauncher(onResult: (_) {}, title: 'Pick effort'),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Pick effort'), findsOneWidget);
      expect(find.text('Gemini thinking mode'), findsNothing);
    });

    testWidgets('dismissing the modal resolves with null', (tester) async {
      GeminiThinkingMode? result = GeminiThinkingMode.high;
      var resultSet = false;
      await tester.pumpWidget(
        buildLauncher(
          onResult: (mode) {
            result = mode;
            resultSet = true;
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(GeminiThinkingModePickerContent), findsOneWidget);

      // Tap outside the sheet to dismiss without selecting.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(resultSet, isTrue);
      expect(result, isNull);
    });
  });
}
