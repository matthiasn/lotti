import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_search_bar.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_header_bar.dart';

import '../../../../../../widget_test_utils.dart';

void main() {
  group('AiSettingsHeaderBar', () {
    testWidgets(
      'renders an AiSettingsSearchBar (the existing app-wide search '
      'component) and nothing else — no subtitle paragraph, no '
      'inline Add CTA',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            SizedBox(
              width: 900,
              child: AiSettingsHeaderBar(
                searchController: controller,
                onSearchClear: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(AiSettingsSearchBar), findsOneWidget);
        // The legacy v3 prototype shipped a "Configure AI providers, "
        // subtitle paragraph + an inline Add CTA; both are gone now —
        // guard against regressions that re-add either.
        expect(find.textContaining('Configure AI providers'), findsNothing);
        expect(find.text('Add provider'), findsNothing);
        expect(find.text('Add model'), findsNothing);
        expect(find.text('Add Profile'), findsNothing);
      },
    );

    testWidgets(
      'typing in the search field drives the supplied controller; '
      'tapping the clear affordance fires onSearchClear',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        var clears = 0;
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            SizedBox(
              width: 900,
              child: AiSettingsHeaderBar(
                searchController: controller,
                onSearchClear: () => clears++,
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'anthropic');
        await tester.pump();
        expect(controller.text, equals('anthropic'));

        // DesignSystemSearch exposes the clear affordance once the field
        // has text. Tap it and assert the page callback fires.
        await tester.tap(find.byIcon(Icons.cancel_rounded));
        await tester.pump();
        expect(clears, equals(1));
      },
    );
  });
}
