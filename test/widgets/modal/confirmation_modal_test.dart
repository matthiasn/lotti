import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';

import '../../widget_test_utils.dart';

/// Captures the modal's eventual result so tests can assert on it after the
/// route has popped.
class _ModalResult {
  bool? value;
}

void main() {
  /// Pumps a host with an 'open' button, taps it, and settles the modal route.
  ///
  /// [isDestructive] null means "omit the argument" so the production default
  /// is exercised, not restated. [cancelLabel] null likewise omits the
  /// argument, which is the localized-fallback path.
  Future<_ModalResult> pumpAndOpen(
    WidgetTester tester, {
    String message = 'Are you sure?',
    String confirmLabel = 'Yes, proceed',
    String? title,
    String? cancelLabel,
    bool? isDestructive,
    Locale? locale,
  }) async {
    final result = _ModalResult();
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result.value = isDestructive == null
                  ? await showConfirmationModal(
                      context: context,
                      message: message,
                      confirmLabel: confirmLabel,
                      title: title,
                      cancelLabel: cancelLabel,
                    )
                  : await showConfirmationModal(
                      context: context,
                      message: message,
                      confirmLabel: confirmLabel,
                      title: title,
                      cancelLabel: cancelLabel,
                      isDestructive: isDestructive,
                    );
            },
            child: const Text('open'),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.tap(find.text('open'));
    // Modal route transition — settle is genuinely needed here.
    await tester.pumpAndSettle();
    return result;
  }

  DesignSystemButton buttonWithLabel(WidgetTester tester, String label) =>
      tester.widget<DesignSystemButton>(
        find.widgetWithText(DesignSystemButton, label),
      );

  group('result contract', () {
    testWidgets('confirm resolves true and closes the modal', (tester) async {
      final result = await pumpAndOpen(
        tester,
        message: 'Delete everything?',
        confirmLabel: 'Yes, delete',
      );

      await tester.tap(find.text('Yes, delete'));
      await tester.pumpAndSettle();

      expect(result.value, isTrue);
      expect(find.text('Delete everything?'), findsNothing);
    });

    testWidgets('cancel resolves false and closes the modal', (tester) async {
      final result = await pumpAndOpen(
        tester,
        message: 'Discard changes?',
        cancelLabel: 'Keep editing',
      );

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();

      expect(result.value, isFalse);
      expect(find.text('Discard changes?'), findsNothing);
    });

    testWidgets('dismissing via the barrier resolves false', (tester) async {
      final result = await pumpAndOpen(tester, message: 'Sure?');

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(result.value, isFalse);
      expect(find.text('Sure?'), findsNothing);
    });
  });

  group('label rendering', () {
    testWidgets('renders the confirm label exactly as passed — never '
        'upper-cased', (tester) async {
      await pumpAndOpen(tester, confirmLabel: 'Yes, delete');

      expect(find.text('Yes, delete'), findsOneWidget);
      expect(
        find.text('YES, DELETE'),
        findsNothing,
        reason:
            'the modal used to shout every confirm label via '
            'toUpperCase(); the label must render verbatim',
      );
    });

    testWidgets('preserves characters a locale-free toUpperCase() would '
        'mangle', (tester) async {
      // German ß upper-cases to SS through Dart's locale-free toUpperCase(),
      // changing the word (and its length). Verbatim rendering is the fix.
      await pumpAndOpen(tester, confirmLabel: 'Straße löschen');

      expect(find.text('Straße löschen'), findsOneWidget);
      expect(find.text('STRASSE LÖSCHEN'), findsNothing);
    });

    testWidgets('renders a custom cancel label on a secondary button', (
      tester,
    ) async {
      await pumpAndOpen(tester, cancelLabel: 'Keep editing');

      expect(
        buttonWithLabel(tester, 'Keep editing').variant,
        DesignSystemButtonVariant.secondary,
      );
    });

    testWidgets('cancel label defaults to the MaterialLocalizations label', (
      tester,
    ) async {
      await pumpAndOpen(tester);

      expect(find.text('Cancel'), findsOneWidget);
      expect(
        find.text('CANCEL'),
        findsNothing,
        reason:
            'the old hardcoded default shouted in English regardless of '
            'locale',
      );
    });

    testWidgets('the default cancel label follows the app locale', (
      tester,
    ) async {
      await pumpAndOpen(tester, locale: const Locale('de'));

      expect(
        find.text('Abbrechen'),
        findsOneWidget,
        reason:
            'the fallback must come from MaterialLocalizations, not a '
            'hardcoded English string',
      );
      expect(find.text('Cancel'), findsNothing);
    });
  });

  group('structure', () {
    testWidgets('renders the title above the message when provided', (
      tester,
    ) async {
      await pumpAndOpen(
        tester,
        title: 'Discard recording?',
        message: 'This recording will be deleted.',
      );

      expect(
        find.byKey(const Key('confirmation_modal_title')),
        findsOneWidget,
      );
      expect(find.text('Discard recording?'), findsOneWidget);
      expect(find.text('This recording will be deleted.'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Discard recording?')).dy,
        lessThan(
          tester.getCenter(find.text('This recording will be deleted.')).dy,
        ),
      );
    });

    testWidgets('omits the title row when no title is passed', (tester) async {
      await pumpAndOpen(tester, message: 'Only the message.');

      expect(find.text('Only the message.'), findsOneWidget);
      expect(
        find.byKey(const Key('confirmation_modal_title')),
        findsNothing,
      );
    });

    testWidgets('destructive by default: warning icon and danger confirm', (
      tester,
    ) async {
      await pumpAndOpen(tester, confirmLabel: 'Yes, delete');

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(
        buttonWithLabel(tester, 'Yes, delete').variant,
        DesignSystemButtonVariant.danger,
      );
    });

    testWidgets('non-destructive: no warning icon, primary confirm', (
      tester,
    ) async {
      await pumpAndOpen(
        tester,
        confirmLabel: 'Run',
        isDestructive: false,
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(
        buttonWithLabel(tester, 'Run').variant,
        DesignSystemButtonVariant.primary,
      );
    });
  });
}
