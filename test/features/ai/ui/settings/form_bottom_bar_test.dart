import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/form_bottom_bar.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('FormBottomBar', () {
    Widget buildTestWidget(Widget child) {
      return makeTestableWidgetNoScroll(
        Scaffold(
          body: Column(
            children: [
              const Spacer(),
              child,
            ],
          ),
        ),
        theme: ThemeData.dark(),
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
      expect(find.byIcon(LottiIcons.confirmCircled), findsOneWidget);

      // The actual text depends on localization, so let's just check the icon exists
      // and the save button is disabled

      // Save button should be disabled
      final saveButton = find.byWidgetPredicate(
        (widget) =>
            widget is DesignSystemButton &&
            widget.leadingIcon == LottiIcons.save &&
            widget.onPressed == null,
      );
      expect(saveButton, findsOneWidget);
    });

    testWidgets('fits German status and actions on a phone width', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (context) => Localizations.override(
              context: context,
              locale: const Locale('de'),
              child: FormBottomBar(
                onSave: () {},
                onCancel: () {},
                isFormValid: true,
                isDirty: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Keine ungespeicherten Änderungen'), findsOneWidget);
      expect(find.text('Abbrechen'), findsOneWidget);
      expect(find.text('Speichern'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final (label, isDirty, isFormValid) in [
      ('no changes', false, true),
      ('fix errors', true, false),
    ]) {
      testWidgets(
        'at 320dp in German ($label) Save stays fully on screen and the '
        'bar lays out without overflow',
        (tester) async {
          tester.view
            ..physicalSize = const Size(320, 640)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            buildTestWidget(
              Builder(
                builder: (context) => Localizations.override(
                  context: context,
                  locale: const Locale('de'),
                  child: FormBottomBar(
                    onSave: () {},
                    onCancel: () {},
                    isFormValid: isFormValid,
                    isDirty: isDirty,
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          final save = tester.getRect(
            find.widgetWithIcon(DesignSystemButton, LottiIcons.save),
          );
          final cancel = tester.getRect(
            find.ancestor(
              of: find.text('Abbrechen'),
              matching: find.byType(DesignSystemButton),
            ),
          );
          for (final rect in [save, cancel]) {
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(320));
            expect(rect.bottom, lessThanOrEqualTo(640));
          }
          // The status line is still there to explain the disabled Save.
          expect(
            find.text(
              isDirty
                  ? 'Bitte behebe die Fehler vor dem Speichern'
                  : 'Keine ungespeicherten Änderungen',
            ),
            findsOneWidget,
          );
        },
      );
    }

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
      expect(find.byIcon(LottiIcons.info), findsOneWidget);

      // Save button should be disabled
      final saveButton = find.byWidgetPredicate(
        (widget) =>
            widget is DesignSystemButton &&
            widget.label == 'Save' &&
            widget.onPressed == null,
      );
      expect(saveButton, findsOneWidget);
    });

    testWidgets('shows save button when form is valid and dirty', (
      tester,
    ) async {
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
      expect(find.byIcon(LottiIcons.confirmCircled), findsNothing);
      expect(find.byIcon(LottiIcons.info), findsNothing);

      // Save button should be enabled
      final saveButton = find.byWidgetPredicate(
        (widget) =>
            widget is DesignSystemButton &&
            widget.label == 'Save' &&
            widget.onPressed != null,
      );
      expect(saveButton, findsOneWidget);

      // Test save button tap
      await tester.tap(saveButton);
      expect(saveCalled, isTrue);

      // Test cancel button tap
      final cancelButton = find.byWidgetPredicate(
        (widget) => widget is DesignSystemButton && widget.label == 'Cancel',
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
            widget is DesignSystemButton &&
            widget.label == 'Save' &&
            widget.onPressed == null,
      );
      expect(saveButton, findsOneWidget);
    });

    testWidgets(
      'renders on the design-system glass strip, bottom-docked, with the '
      'actions inside it',
      (tester) async {
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

        final strip = find.byType(DesignSystemGlassStrip);
        expect(
          tester.widget<DesignSystemGlassStrip>(strip).dock,
          DesignSystemGlassStripDock.bottom,
        );
        expect(
          find.descendant(of: strip, matching: find.byType(DesignSystemButton)),
          findsNWidgets(2),
        );
      },
    );

    testWidgets(
      'on a wide bar the status leads and Cancel + Save sit together on the '
      'trailing edge of one row',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1280, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);

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

        final status = tester.getRect(find.text('No unsaved changes'));
        final cancel = tester.getRect(
          find.ancestor(
            of: find.text('Cancel'),
            matching: find.byType(DesignSystemButton),
          ),
        );
        final save = tester.getRect(
          find.widgetWithIcon(DesignSystemButton, LottiIcons.save),
        );
        // One row: all three share a vertical centre.
        expect(status.center.dy, moreOrLessEquals(save.center.dy, epsilon: 1));
        expect(cancel.center.dy, moreOrLessEquals(save.center.dy, epsilon: 1));
        // Status on the leading half, actions adjacent on the trailing half.
        expect(status.left, lessThan(640));
        expect(cancel.left, greaterThan(640));
        expect(save.left, greaterThan(cancel.right));
      },
    );

    testWidgets(
      'a dirty, valid form shows no status and keeps the actions on the '
      'trailing edge',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1280, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          buildTestWidget(
            FormBottomBar(
              onSave: () {},
              onCancel: () {},
              isFormValid: true,
              isDirty: true,
            ),
          ),
        );

        expect(find.text('No unsaved changes'), findsNothing);
        expect(find.text('Please fix errors before saving'), findsNothing);
        final cancel = tester.getRect(
          find.ancestor(
            of: find.text('Cancel'),
            matching: find.byType(DesignSystemButton),
          ),
        );
        expect(cancel.left, greaterThan(640));
      },
    );

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
        (widget) =>
            widget is DesignSystemButton &&
            widget.leadingIcon == LottiIcons.save,
      );
      expect(saveButton, findsOneWidget);

      // Verify the button's onPressed is null
      final button = tester.widget<DesignSystemButton>(saveButton);
      expect(button.onPressed, isNull);
    });
  });
}
