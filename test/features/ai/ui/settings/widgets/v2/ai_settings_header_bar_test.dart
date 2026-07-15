import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_search_bar.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_header_bar.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../../widget_test_utils.dart';

void main() {
  group('AiSettingsHeaderBar', () {
    testWidgets(
      'renders the shared search and configured wake concurrency',
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
                agentWakeConcurrency: 3,
                onAgentWakeConcurrencyChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(AiSettingsSearchBar), findsOneWidget);
        expect(find.byType(DesignSystemDropdown), findsOneWidget);
        final messages = tester
            .element(find.byType(AiSettingsHeaderBar))
            .messages;
        expect(
          find.text(messages.aiSettingsAgentWakeConcurrencyLabel),
          findsOneWidget,
        );
        expect(
          find.text(messages.aiSettingsAgentWakeConcurrencyDescription),
          findsOneWidget,
        );
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
                agentWakeConcurrency: 3,
                onAgentWakeConcurrencyChanged: (_) {},
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

    testWidgets('selecting a concurrency value reports the chosen limit', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      int? selectedConcurrency;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 600,
            child: AiSettingsHeaderBar(
              searchController: controller,
              onSearchClear: () {},
              agentWakeConcurrency: 3,
              onAgentWakeConcurrencyChanged: (value) {
                selectedConcurrency = value;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(InkWell, '3'));
      await tester.pump();
      await tester.tap(find.text('4').last);
      await tester.pump();

      expect(selectedConcurrency, 4);
    });
  });
}
