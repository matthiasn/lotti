import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_history_section.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    return tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        TaskHistorySection(
          expanded: expanded,
          onToggle: onToggle,
          child: const Text('entry stream'),
        ),
      ),
    );
  }

  group('TaskHistorySection', () {
    testWidgets('keeps the child out of the tree while collapsed', (
      tester,
    ) async {
      await pump(tester, expanded: false, onToggle: () {});

      expect(find.text('History'), findsOneWidget);
      // Not offstage, not zero-sized — genuinely unbuilt, so a long log
      // costs nothing until asked for.
      expect(find.text('entry stream', skipOffstage: false), findsNothing);
    });

    testWidgets('shows the child when expanded', (tester) async {
      await pump(tester, expanded: true, onToggle: () {});

      expect(find.text('entry stream'), findsOneWidget);
    });

    testWidgets(
      'the whole row is ONE control: taps anywhere fire onToggle and no '
      'nested button duplicates it for assistive technology',
      (tester) async {
        var toggles = 0;
        await pump(tester, expanded: false, onToggle: () => toggles++);

        await tester.tap(find.text('History'));
        await tester.tap(find.byIcon(LottiIcons.expand));
        await tester.pump();

        expect(toggles, 2);
        // The chevron is a plain glyph inside the row's InkWell — a nested
        // IconButton exposed a duplicate control to screen readers.
        expect(find.byType(IconButton), findsNothing);
        expect(find.byType(InkWell), findsOneWidget);
      },
    );

    testWidgets('the header stays pinned in place across the states', (
      tester,
    ) async {
      await pump(tester, expanded: false, onToggle: () {});
      final collapsedTitle = tester.getTopLeft(find.text('History'));
      final collapsedChevron = tester.getCenter(find.byIcon(LottiIcons.expand));

      await pump(tester, expanded: true, onToggle: () {});

      expect(tester.getTopLeft(find.text('History')), collapsedTitle);
      expect(
        tester.getCenter(find.byIcon(LottiIcons.expand)),
        collapsedChevron,
      );
    });

    testWidgets(
      'hover paints no overlay rectangle — the chevron brightens instead',
      (tester) async {
        await pump(tester, expanded: false, onToggle: () {});

        final tokens = tester.element(find.text('History')).designTokens;
        Color chevronColor() =>
            tester.widget<Icon>(find.byIcon(LottiIcons.expand)).color!;
        expect(chevronColor(), tokens.colors.text.lowEmphasis);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(find.text('History')));
        await tester.pump();

        expect(chevronColor(), tokens.colors.text.highEmphasis);
        // The row must not grow a phantom-button fill on hover; the quiet
        // ink silences every Material overlay.
        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        expect(inkWell.hoverColor, Colors.transparent);
        expect(
          inkWell.overlayColor?.resolve({WidgetState.hovered}),
          Colors.transparent,
        );
      },
    );

    testWidgets('the chevron points right collapsed and down expanded', (
      tester,
    ) async {
      await pump(tester, expanded: false, onToggle: () {});
      var rotation = tester.widget<AnimatedRotation>(
        find.byType(AnimatedRotation),
      );
      expect(rotation.turns, -0.25);

      await pump(tester, expanded: true, onToggle: () {});
      rotation = tester.widget<AnimatedRotation>(
        find.byType(AnimatedRotation),
      );
      expect(rotation.turns, 0.0);
    });
  });
}
