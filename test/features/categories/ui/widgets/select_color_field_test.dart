import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/ui/widgets/select_color_field.dart';

import '../../../../test_helper.dart';

void main() {
  Widget createTestWidget({
    required void Function(Color) onColorChanged,
    String? initialColor,
  }) {
    return createTestApp(
      SelectColorField(
        hexColor: initialColor,
        onColorChanged: onColorChanged,
      ),
    );
  }

  testWidgets('displays initial color', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        initialColor: '#FF0000',
        onColorChanged: (_) {},
      ),
    );

    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    expect(find.text('#FF0000'), findsOneWidget);
  });

  testWidgets('shows error for invalid hex color', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        initialColor: '#FF0000',
        onColorChanged: (_) {},
      ),
    );

    // Enter invalid hex color
    await tester.enterText(find.byType(TextField), 'invalid');
    await tester.pump();

    // Verify error message is shown
    expect(find.text('Enter Hex color or pick'), findsOneWidget);
  });

  testWidgets('validates correct hex color format', (tester) async {
    var colorChanged = false;
    await tester.pumpWidget(
      createTestWidget(
        initialColor: '#FF0000',
        onColorChanged: (_) => colorChanged = true,
      ),
    );

    // Enter valid hex color
    await tester.enterText(find.byType(TextField), '#00FF00');
    await tester.pump();

    expect(find.text('#00FF00'), findsOneWidget);
    expect(colorChanged, true);
  });

  testWidgets('shows color picker on icon button tap', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        initialColor: '#FF0000',
        onColorChanged: (_) {},
      ),
    );

    // Find and tap the color picker icon
    final iconButton = find.byIcon(Icons.color_lens_outlined);
    expect(iconButton, findsOneWidget);
    await tester.tap(iconButton);
    await tester.pumpAndSettle();

    // Verify color picker is shown
    expect(find.byType(ColorPicker), findsOneWidget);
  });

  testWidgets('shows hint text when no color selected', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        onColorChanged: (_) {},
      ),
    );

    // Verify hint text is shown
    expect(find.text('Enter Hex color or pick'), findsOneWidget);
  });

  testWidgets('shows label when valid color is set', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        initialColor: '#FF0000',
        onColorChanged: (_) {},
      ),
    );

    // Verify label is shown
    expect(find.text('Color:'), findsOneWidget);
    // Verify initial color is shown
    expect(find.text('#FF0000'), findsOneWidget);
  });
}
