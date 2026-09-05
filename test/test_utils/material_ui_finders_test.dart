import 'package:flutter/material.dart' as legacy;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../widget_test_utils.dart';
import 'material_ui_finders.dart';

void main() {
  for (final exclude in [false, true]) {
    testWidgets(
      'finds both tooltip libraries with excluded semantics $exclude',
      (
        tester,
      ) async {
        var modernTaps = 0;
        var legacyTaps = 0;
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            Row(
              children: [
                Tooltip(
                  message: 'Modern action',
                  excludeFromSemantics: exclude,
                  child: TextButton(
                    onPressed: () => modernTaps++,
                    child: const Text('M'),
                  ),
                ),
                legacy.Tooltip(
                  message: 'Legacy action',
                  excludeFromSemantics: exclude,
                  child: TextButton(
                    onPressed: () => legacyTaps++,
                    child: const Text('L'),
                  ),
                ),
              ],
            ),
          ),
        );
        expect(findMaterialTooltip('Modern action'), findsOneWidget);
        expect(findMaterialTooltip(RegExp('Legacy.*')), findsOneWidget);
        expect(findMaterialTooltip('Missing action'), findsNothing);
        await tester.tap(findMaterialTooltip('Modern action'));
        await tester.tap(findMaterialTooltip('Legacy action'));
        expect(modernTaps, 1);
        expect(legacyTaps, 1);
      },
    );
  }
}
