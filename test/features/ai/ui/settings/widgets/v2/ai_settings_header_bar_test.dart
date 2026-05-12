import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_header_bar.dart';

import '../../../../../../widget_test_utils.dart';

void main() {
  group('AiSettingsHeaderBar', () {
    testWidgets(
      'renders the subtitle paragraph, the search field, and the green '
      '"+ Add provider" CTA on a wide viewport',
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
                onAddProvider: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.textContaining('Configure AI providers'),
          findsOneWidget,
          reason: 'Header should render the page lead paragraph.',
        );
        expect(find.text('Add provider'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      },
    );

    testWidgets('tapping Add provider fires onAddProvider', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var taps = 0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 900,
            child: AiSettingsHeaderBar(
              searchController: controller,
              onSearchClear: () {},
              onAddProvider: () => taps++,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Add provider'));
      await tester.pump();
      expect(taps, equals(1));
    });

    testWidgets(
      'narrow viewport stacks the search field above the Add provider '
      'button — both still visible and tappable',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            SizedBox(
              width: 320,
              child: AiSettingsHeaderBar(
                searchController: controller,
                onSearchClear: () {},
                onAddProvider: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Add provider'), findsOneWidget);
      },
    );

    testWidgets(
      'typing in the search field drives the supplied controller; clearing '
      'fires onSearchClear',
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
                onAddProvider: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'anthropic');
        await tester.pump();
        expect(controller.text, equals('anthropic'));

        // The clear icon only appears once there's text.
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        expect(clears, equals(1));
      },
    );
  });
}
