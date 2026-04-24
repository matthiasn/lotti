import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/ui/detail/disable_v2_button.dart';
import 'package:lotti/features/settings_v2/ui/detail/empty_root.dart';

import '../../../../widget_test_utils.dart';

Future<void> _pumpEmptyRoot(WidgetTester tester) async {
  await setUpTestGetIt();
  addTearDown(tearDownTestGetIt);
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      const Material(
        child: SizedBox(width: 600, height: 600, child: EmptyRoot()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('EmptyRoot — content', () {
    testWidgets('renders the "Settings" heading', (tester) async {
      await _pumpEmptyRoot(tester);
      // The app-bar label ('Settings') is the canonical heading.
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('renders the "Pick a section" empty-state copy', (
      tester,
    ) async {
      await _pumpEmptyRoot(tester);
      expect(find.text('Pick a section on the left to begin.'), findsOneWidget);
    });

    testWidgets('renders the gear empty-state glyph', (tester) async {
      await _pumpEmptyRoot(tester);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });
  });

  group('EmptyRoot — escape hatch', () {
    testWidgets('always renders the DisableV2Button', (tester) async {
      await _pumpEmptyRoot(tester);
      expect(find.byType(DisableV2Button), findsOneWidget);
    });
  });
}
