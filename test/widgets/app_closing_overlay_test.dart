import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/widgets/app_closing_overlay.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

import '../widget_test_utils.dart';

/// A child with state of its own, a tap target and a focusable field, so the
/// tests can tell whether the overlay preserved, blocked or unfocused it.
class _Probe extends StatefulWidget {
  const _Probe({required this.focusNode});

  final FocusNode focusNode;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int taps = 0;

  @override
  Widget build(BuildContext context) {
    // The app's pages sit on Material; the TextField needs it too.
    return Material(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => taps++),
            child: SizedBox.square(
              dimension: 80,
              child: Text('taps: $taps', key: const Key('probe-taps')),
            ),
          ),
          SizedBox(width: 200, child: TextField(focusNode: widget.focusNode)),
        ],
      ),
    );
  }
}

void main() {
  late FocusNode focusNode;
  late ValueNotifier<bool> closing;

  setUp(() {
    focusNode = FocusNode();
    closing = ValueNotifier(false);
  });

  tearDown(() {
    focusNode.dispose();
    closing.dispose();
  });

  Future<void> pumpOverlay(
    WidgetTester tester, {
    bool useClosing = true,
    ThemeData? theme,
    Locale? locale,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        AppClosingOverlay(
          closing: useClosing ? closing : null,
          child: _Probe(focusNode: focusNode),
        ),
        theme: theme,
        locale: locale,
      ),
    );
    await tester.pump();
  }

  String tapsText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('probe-taps'))).data!;

  group('AppClosingOverlay', () {
    testWidgets('without a closing signal renders only the child', (
      tester,
    ) async {
      await pumpOverlay(tester, useClosing: false);

      expect(
        find.descendant(
          of: find.byType(AppClosingOverlay),
          matching: find.byType(ValueListenableBuilder<bool>),
        ),
        findsNothing,
      );
      expect(find.byType(AppClosingNotice), findsNothing);
      await tester.tap(find.byKey(const Key('probe-taps')));
      await tester.pump();
      expect(tapsText(tester), 'taps: 1');
    });

    testWidgets('while not closing the child stays interactive', (
      tester,
    ) async {
      await pumpOverlay(tester);

      expect(find.byType(AppClosingNotice), findsNothing);
      await tester.tap(find.byKey(const Key('probe-taps')));
      await tester.pump();
      expect(tapsText(tester), 'taps: 1');

      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('a quit shows the localized notice with a spinner', (
      tester,
    ) async {
      await pumpOverlay(tester);

      closing.value = true;
      await tester.pump();

      expect(find.text('Closing Lotti…'), findsOneWidget);
      expect(find.text('Saving everything. Please stand by.'), findsOneWidget);
      final spinner = tester.widget<DesignSystemSpinner>(
        find.byType(DesignSystemSpinner),
      );
      expect(spinner.semanticsLabel, 'Closing Lotti…');
    });

    testWidgets('the notice text is not drawn with the no-Material fallback', (
      tester,
    ) async {
      // The host puts the overlay straight under the Navigator, like the
      // app's MaterialApp builder: no page Material sits behind it.
      closing.value = true;
      await pumpOverlay(tester);

      for (final label in [
        'Closing Lotti…',
        'Saving everything. Please stand by.',
      ]) {
        final rendered = tester.widget<RichText>(
          find.descendant(
            of: find.text(label),
            matching: find.byType(RichText),
          ),
        );
        expect(
          rendered.text.style?.decoration,
          isNot(TextDecoration.underline),
        );
      }
    });

    testWidgets('the notice follows the app locale', (tester) async {
      closing.value = true;
      await pumpOverlay(tester, locale: const Locale('de'));

      expect(find.text('Lotti wird geschlossen…'), findsOneWidget);
      expect(
        find.text('Alles wird gespeichert. Einen Moment noch.'),
        findsOneWidget,
      );
    });

    testWidgets('the notice blocks taps and cannot be dismissed', (
      tester,
    ) async {
      await pumpOverlay(tester);
      closing.value = true;
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('probe-taps')),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(tapsText(tester), 'taps: 0');
      expect(find.byType(AppClosingNotice), findsOneWidget);
      final barrier = tester.widget<ModalBarrier>(
        find.descendant(
          of: find.byType(AppClosingNotice),
          matching: find.byType(ModalBarrier),
        ),
      );
      expect(barrier.dismissible, isFalse);
    });

    testWidgets('a quit takes focus away from the child', (tester) async {
      await pumpOverlay(tester);
      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      closing.value = true;
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);
      expect(focusNode.canRequestFocus, isFalse);
    });

    testWidgets('the child keeps its state while the notice comes and goes', (
      tester,
    ) async {
      await pumpOverlay(tester);
      await tester.tap(find.byKey(const Key('probe-taps')));
      await tester.pump();

      closing.value = true;
      await tester.pump();
      expect(tapsText(tester), 'taps: 1');

      closing.value = false;
      await tester.pump();
      expect(find.byType(AppClosingNotice), findsNothing);
      expect(tapsText(tester), 'taps: 1');
    });
  });

  group('AppClosingNotice surfaces', () {
    for (final brightness in Brightness.values) {
      testWidgets('uses the shared scrim and card surface ($brightness)', (
        tester,
      ) async {
        closing.value = true;
        await pumpOverlay(
          tester,
          theme: ThemeData(useMaterial3: true, brightness: brightness),
        );

        final noticeContext = tester.element(find.byType(AppClosingNotice));
        final barrier = tester.widget<ModalBarrier>(
          find.descendant(
            of: find.byType(AppClosingNotice),
            matching: find.byType(ModalBarrier),
          ),
        );
        expect(
          barrier.color,
          ModalUtils.getModalBarrierColor(
            isDark: brightness == Brightness.dark,
            context: noticeContext,
          ),
        );

        final card = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.byType(DesignSystemSpinner),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect(
          (card.decoration as BoxDecoration).color,
          dsCardSurface(noticeContext),
        );
      });
    }
  });
}
