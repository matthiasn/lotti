import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_search_bar.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('AiSettingsSearchBar', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    Widget build({
      bool isCompact = false,
      ValueChanged<String>? onChanged,
      VoidCallback? onClear,
    }) {
      return makeTestableWidgetWithScaffold(
        AiSettingsSearchBar(
          controller: controller,
          hintText: 'Search providers, models, profiles...',
          isCompact: isCompact,
          onChanged: onChanged,
          onClear: onClear,
        ),
      );
    }

    DesignSystemSearch search(WidgetTester tester) =>
        tester.widget<DesignSystemSearch>(find.byType(DesignSystemSearch));

    testWidgets('renders the design-system search with the supplied hint', (
      tester,
    ) async {
      await tester.pumpWidget(build());

      expect(find.byType(DesignSystemSearch), findsOneWidget);
      expect(search(tester).hintText, 'Search providers, models, profiles...');
      // Default (non-compact) maps to the medium size variant.
      expect(search(tester).size, DesignSystemSearchSize.medium);
    });

    testWidgets('isCompact maps to the small size variant', (tester) async {
      await tester.pumpWidget(build(isCompact: true));

      expect(search(tester).size, DesignSystemSearchSize.small);
    });

    testWidgets('typing drives the controller and reports onChanged', (
      tester,
    ) async {
      var last = '';
      await tester.pumpWidget(build(onChanged: (v) => last = v));

      await tester.enterText(find.byType(TextField), 'anthropic');
      await tester.pump();

      expect(controller.text, 'anthropic');
      expect(last, 'anthropic');
    });

    testWidgets('clear affordance clears the field and fires onClear', (
      tester,
    ) async {
      var cleared = 0;
      await tester.pumpWidget(build(onClear: () => cleared++));

      await tester.enterText(find.byType(TextField), 'anthropic');
      await tester.pump();

      // The clear affordance only appears once the field has text.
      await tester.tap(find.byIcon(Icons.cancel_rounded));
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(cleared, 1);
    });
  });
}
