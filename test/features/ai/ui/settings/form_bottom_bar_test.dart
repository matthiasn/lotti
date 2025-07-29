import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:lotti/features/ai/ui/settings/form_bottom_bar.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/widgets/lotti_primary_button.dart';
import 'package:lotti/widgets/lotti_tertiary_button.dart';

void main() {
  group('FormBottomBar', () {
    Widget buildTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
        ],
        home: Scaffold(
          body: Column(
            children: [
              const Spacer(),
              child,
            ],
          ),
        ),
      );
    }

    testWidgets('shows "no changes" state when not dirty', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          FormBottomBar(
            onSave: () {},
            onCancel: () {},
            isFormValid: true,
            isDirty: false,
          ),
        ),
      );

      // Should show check icon and "no changes" text
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

      // The actual text depends on localization, so let's just check the icon exists
      // and the save button is disabled

      // Save button should be disabled
      final saveButton = find.byWidgetPredicate(
        (widget) =>
            widget is LottiPrimaryButton &&
            widget.icon == Icons.save_rounded &&
            widget.onPressed == null,
      );
      expect(saveButton, findsOneWidget);
    });

    testWidgets('shows error state when form is invalid', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          FormBottomBar(
            onSave: () {},
            onCancel: () {},
            isFormValid: false,
            isDirty: true,
          ),
        ),
      );

      // Should show error icon
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

      // Save button should be disabled
      final saveButton = find.byWidgetPredicate(
        (widget) =>
            widget is LottiPrimaryButton &&
            widget.label == 'Save' &&
            widget.onPressed == null,
      );
      expect(saveButton, findsOneWidget);
    });

    testWidgets('shows save button when form is valid and dirty',
        (tester) async {
      var saveCalled = false;
      var cancelCalled = false;

      await tester.pumpWidget(
        buildTestWidget(
          FormBottomBar(
            onSave: () => saveCalled = true,
            onCancel: () => cancelCalled = true,
            isFormValid: true,
            isDirty: true,
          ),
        ),
      );

      // Should not show status indicators
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);

      // Save button should be enabled
      final saveButton = find.byWidgetPredicate(
        (widget) =>
            widget is LottiPrimaryButton &&
            widget.label == 'Save' &&
            widget.onPressed != null,
      );
      expect(saveButton, findsOneWidget);

      // Test save button tap
      await tester.tap(saveButton);
      expect(saveCalled, isTrue);

      // Test cancel button tap
      final cancelButton = find.byWidgetPredicate(
        (widget) =>
            widget is LottiTertiaryButton && widget.label == 'Cancel',
      );
      await tester.tap(cancelButton);
      expect(cancelCalled, isTrue);
    });

    testWidgets('shows loading state correctly', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          FormBottomBar(
            onSave: () {},
            onCancel: () {},
            isFormValid: true,
            isDirty: true,
            isLoading: true,
          ),
        ),
      );

      // Save button should show loading state (disabled when loading)
      final saveButton = find.byWidgetPredicate(
        (widget) =>
            widget is LottiPrimaryButton &&
            widget.label == 'Save' &&
            widget.onPressed == null,
      );
      expect(saveButton, findsOneWidget);
    });

    testWidgets('has correct glass effect styling', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          FormBottomBar(
            onSave: () {},
            onCancel: () {},
            isFormValid: true,
            isDirty: false,
          ),
        ),
      );

      // Check for glass container
      expect(find.byType(GlassContainer), findsOneWidget);

      // Check for border decoration container
      final containers = find
          .byType(Container)
          .evaluate()
          .map((e) => e.widget as Container)
          .where((container) => container.decoration != null)
          .toList();

      expect(containers.isNotEmpty, isTrue);
      final borderContainer = containers.first;
      final decoration = borderContainer.decoration as BoxDecoration?;
      expect(decoration?.border?.top, isNotNull);
    });

    testWidgets('handles null onSave callback', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          FormBottomBar(
            onSave: null,
            onCancel: () {},
            isFormValid: true,
            isDirty: true,
          ),
        ),
      );

      // Save button should exist and be enabled (showSaveButton = true)
      // but onPressed should be null
      final saveButton = find.byWidgetPredicate(
        (widget) => widget is LottiPrimaryButton && widget.icon == Icons.save_rounded,
      );
      expect(saveButton, findsOneWidget);

      // Verify the button's onPressed is null
      final button = tester.widget<LottiPrimaryButton>(saveButton);
      expect(button.onPressed, isNull);
    });
  });
}
