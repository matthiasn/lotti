import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/config_loading_state.dart';

void main() {
  group('ConfigLoadingState', () {
    Widget createWidget() {
      return const MaterialApp(
        home: Scaffold(
          body: ConfigLoadingState(),
        ),
      );
    }

    testWidgets('displays circular progress indicator',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('centers the loading indicator', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      expect(find.byType(Center), findsOneWidget);
    });

    testWidgets('loading indicator is contained properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      // The ConfigLoadingState itself contains a Center widget
      final center = find.descendant(
        of: find.byType(ConfigLoadingState),
        matching: find.byType(Center),
      );
      expect(center, findsOneWidget);

      // The CircularProgressIndicator should be inside the Center
      final progressIndicator = find.descendant(
        of: center,
        matching: find.byType(CircularProgressIndicator),
      );
      expect(progressIndicator, findsOneWidget);
    });

    testWidgets('has minimal widget tree', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      // Should only have Center and CircularProgressIndicator
      final configLoadingState = find.byType(ConfigLoadingState);
      final widgets = find.descendant(
        of: configLoadingState,
        matching: find.byType(Widget),
      );

      // The widget tree should be minimal
      expect(widgets.evaluate().length, lessThan(5));
    });
  });
}
