import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

enum _Mode { first, second }

Widget _wrap(Widget child) => makeTestableWidget2(
  Scaffold(body: Center(child: child)),
  mediaQueryData: const MediaQueryData(size: Size(800, 600)),
);

// Each segment stacks an invisible bold ghost under the visible label, so a
// plain find.text matches two Texts — the visible one is the Stack's last
// child.
Finder _visible(String label) => find.text(label).last;

void main() {
  group('DsSegmentedToggle', () {
    testWidgets('renders every segment label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DsSegmentedToggle<_Mode>(
            selected: _Mode.first,
            onChanged: (_) {},
            segments: const [
              DsSegment(_Mode.first, 'Per day'),
              DsSegment(_Mode.second, 'Running total'),
            ],
          ),
        ),
      );

      expect(_visible('Per day'), findsOneWidget);
      expect(_visible('Running total'), findsOneWidget);
    });

    testWidgets('selected segment uses teal + semibold; others stay quiet', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DsSegmentedToggle<_Mode>(
            selected: _Mode.first,
            onChanged: (_) {},
            segments: const [
              DsSegment(_Mode.first, 'Per day'),
              DsSegment(_Mode.second, 'Running total'),
            ],
          ),
        ),
      );

      final tokens = tester
          .element(find.byType(DsSegmentedToggle<_Mode>))
          .designTokens;
      final teal = tokens.colors.interactive.enabled;
      final selected = tester.widget<Text>(_visible('Per day'));
      final unselected = tester.widget<Text>(_visible('Running total'));

      expect(selected.style?.color, teal);
      expect(selected.style?.fontWeight, FontWeight.w600);
      expect(unselected.style?.color, tokens.colors.text.mediumEmphasis);
      expect(unselected.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('each segment is announced as a selected/unselected button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          DsSegmentedToggle<_Mode>(
            selected: _Mode.first,
            onChanged: (_) {},
            segments: const [
              DsSegment(_Mode.first, 'Per day'),
              DsSegment(_Mode.second, 'Running total'),
            ],
          ),
        ),
      );

      // isSemantics (non-exhaustive) so InkWell's tap/focus actions
      // don't fail the match — we only assert the button role + selected state.
      expect(
        tester.getSemantics(_visible('Per day')),
        isSemantics(isButton: true, isSelected: true, label: 'Per day'),
      );
      expect(
        tester.getSemantics(_visible('Running total')),
        isSemantics(
          isButton: true,
          hasSelectedState: true,
          label: 'Running total',
        ),
      );
      handle.dispose();
    });

    testWidgets('is keyboard operable — Tab to a segment, Enter activates it', (
      tester,
    ) async {
      _Mode? received;
      await tester.pumpWidget(
        _wrap(
          DsSegmentedToggle<_Mode>(
            selected: _Mode.first,
            onChanged: (v) => received = v,
            segments: const [
              DsSegment(_Mode.first, 'Per day'),
              DsSegment(_Mode.second, 'Running total'),
            ],
          ),
        ),
      );

      // Tab into the first segment, then the second, and activate with Enter.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(received, _Mode.second);
    });

    testWidgets('tapping a segment reports its value', (tester) async {
      _Mode? received;
      await tester.pumpWidget(
        _wrap(
          DsSegmentedToggle<_Mode>(
            selected: _Mode.first,
            onChanged: (v) => received = v,
            segments: const [
              DsSegment(_Mode.first, 'Per day'),
              DsSegment(_Mode.second, 'Running total'),
            ],
          ),
        ),
      );

      await tester.tap(_visible('Running total'));
      await tester.pump();
      expect(received, _Mode.second);
    });

    testWidgets(
      'width is selection-invariant (the ghost reserves bold width)',
      (
        tester,
      ) async {
        DsSegmentedToggle<_Mode> build(_Mode selected) =>
            DsSegmentedToggle<_Mode>(
              selected: selected,
              onChanged: (_) {},
              segments: const [
                DsSegment(_Mode.first, 'Per day'),
                DsSegment(_Mode.second, 'Running total'),
              ],
            );

        await tester.pumpWidget(_wrap(build(_Mode.first)));
        final firstWidth = tester
            .getSize(find.byType(DsSegmentedToggle<_Mode>))
            .width;

        await tester.pumpWidget(_wrap(build(_Mode.second)));
        await tester.pump(const Duration(milliseconds: 200));
        final secondWidth = tester
            .getSize(find.byType(DsSegmentedToggle<_Mode>))
            .width;

        expect(secondWidth, firstWidth);
      },
    );

    testWidgets('expand mode fills its bounded width without overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          // A bounded width is required: expand uses MainAxisSize.max.
          SizedBox(
            width: 360,
            child: DsSegmentedToggle<_Mode>(
              expand: true,
              selected: _Mode.first,
              onChanged: (_) {},
              segments: const [
                DsSegment(_Mode.first, 'Per day'),
                DsSegment(_Mode.second, 'Running total'),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(DsSegmentedToggle<_Mode>)).width, 360);
      expect(_visible('Per day'), findsOneWidget);
      expect(_visible('Running total'), findsOneWidget);
    });

    testWidgets(
      'icon segments render the active glyph when selected (the base glyph '
      'otherwise), put the label on a tooltip, and report taps',
      (tester) async {
        _Mode? received;
        await tester.pumpWidget(
          _wrap(
            DsSegmentedToggle<_Mode>(
              selected: _Mode.first,
              onChanged: (v) => received = v,
              segments: const [
                DsSegment(
                  _Mode.first,
                  'Day',
                  icon: Icons.wb_sunny_outlined,
                  activeIcon: Icons.sunny,
                ),
                DsSegment(
                  _Mode.second,
                  'Night',
                  icon: Icons.nightlight_outlined,
                  activeIcon: Icons.nightlight,
                ),
              ],
            ),
          ),
        );

        // Selected → active glyph; unselected → the base glyph. No text.
        expect(find.byIcon(Icons.sunny), findsOneWidget);
        expect(find.byIcon(Icons.wb_sunny_outlined), findsNothing);
        expect(find.byIcon(Icons.nightlight_outlined), findsOneWidget);
        expect(find.byIcon(Icons.nightlight), findsNothing);
        expect(find.text('Day'), findsNothing);

        // The label rides a tooltip instead of visible text.
        expect(find.byTooltip('Day'), findsOneWidget);
        expect(find.byTooltip('Night'), findsOneWidget);

        // Tapping the inactive segment reports its value.
        await tester.tap(find.byIcon(Icons.nightlight_outlined));
        await tester.pump();
        expect(received, _Mode.second);
      },
    );
  });
}
