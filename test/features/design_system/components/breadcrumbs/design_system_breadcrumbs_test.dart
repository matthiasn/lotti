import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/breadcrumbs/design_system_breadcrumbs.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

/// Reads the [BoxDecoration.color] of the breadcrumb chip's background
/// [DecoratedBox] (the one whose decoration is a [BoxDecoration]).
Color? _chipBackground(WidgetTester tester) {
  final decorated = tester.widget<DecoratedBox>(
    find.byWidgetPredicate(
      (widget) => widget is DecoratedBox && widget.decoration is BoxDecoration,
    ),
  );
  return (decorated.decoration as BoxDecoration).color;
}

Future<void> _pumpBreadcrumbs(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(child, theme: DesignSystemTheme.light()),
  );
}

void main() {
  group('DesignSystemBreadcrumbs', () {
    testWidgets('renders a trail with a selected current item', (tester) async {
      await _pumpBreadcrumbs(
        tester,
        SizedBox(
          width: 600,
          child: DesignSystemBreadcrumbs(
            items: [
              DesignSystemBreadcrumbItem(label: 'Home', onPressed: () {}),
              DesignSystemBreadcrumbItem(label: 'Projects', onPressed: () {}),
              const DesignSystemBreadcrumbItem(
                label: 'Breadcrumbs',
                selected: true,
                showChevron: false,
              ),
            ],
          ),
        ),
      );

      final home = tester.widget<Text>(find.text('Home'));
      final current = tester.widget<Text>(find.text('Breadcrumbs'));

      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
      expect(home.style?.color, dsTokensLight.colors.text.highEmphasis);
      expect(current.style?.color, dsTokensLight.colors.interactive.enabled);
    });

    testWidgets('renders hover and disabled styles from tokens', (
      tester,
    ) async {
      await _pumpBreadcrumbs(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesignSystemBreadcrumbs(
              items: [
                DesignSystemBreadcrumbItem(
                  label: 'Breadcrumb',
                  onPressed: () {},
                  forcedState: DesignSystemBreadcrumbVisualState.hover,
                ),
              ],
            ),
            const SizedBox(height: 16),
            DesignSystemBreadcrumbs(
              items: const [
                DesignSystemBreadcrumbItem(
                  label: 'Disabled',
                  enabled: false,
                ),
              ],
            ),
          ],
        ),
      );

      final hoverBackground = tester.widget<DecoratedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color ==
                  dsTokensLight.colors.surface.enabled,
        ),
      );
      final disabledText = tester.widget<Text>(find.text('Disabled'));

      expect(
        (hoverBackground.decoration as BoxDecoration).color,
        dsTokensLight.colors.surface.enabled,
      );
      expect(disabledText.style?.color, dsTokensLight.colors.text.lowEmphasis);
    });

    testWidgets('InkWell wraps entire content row including chevron', (
      tester,
    ) async {
      await _pumpBreadcrumbs(
        tester,
        SizedBox(
          width: 600,
          child: DesignSystemBreadcrumbs(
            items: [
              DesignSystemBreadcrumbItem(
                label: 'Home',
                onPressed: () {},
                forcedState: DesignSystemBreadcrumbVisualState.hover,
              ),
            ],
          ),
        ),
      );

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.child, isA<Row>());
    });

    testWidgets('chevron is inside the interactive InkWell area', (
      tester,
    ) async {
      var tapped = false;

      await _pumpBreadcrumbs(
        tester,
        SizedBox(
          width: 600,
          child: DesignSystemBreadcrumbs(
            items: [
              DesignSystemBreadcrumbItem(
                label: 'Home',
                onPressed: () => tapped = true,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets(
      'mouse hover toggles the live hover background via onHover callback',
      (tester) async {
        await _pumpBreadcrumbs(
          tester,
          SizedBox(
            width: 600,
            child: DesignSystemBreadcrumbs(
              items: [
                DesignSystemBreadcrumbItem(label: 'Home', onPressed: () {}),
              ],
            ),
          ),
        );

        // Idle: transparent background.
        expect(_chipBackground(tester), Colors.transparent);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer();
        await tester.pump();

        // Move the pointer onto the breadcrumb: onHover fires -> _hovered=true.
        await gesture.moveTo(tester.getCenter(find.text('Home')));
        await tester.pump();
        expect(_chipBackground(tester), dsTokensLight.colors.surface.enabled);

        // Move the pointer away: onHover fires again with false.
        await gesture.moveTo(const Offset(-100, -100));
        await tester.pump();
        expect(_chipBackground(tester), Colors.transparent);
      },
    );

    testWidgets(
      'didUpdateWidget clears the hovered flag when the item changes',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const _BreadcrumbMutationHarness(),
            theme: DesignSystemTheme.light(),
          ),
        );

        // Hover the breadcrumb so the transient _hovered flag becomes true.
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer();
        await tester.pump();
        await gesture.moveTo(tester.getCenter(find.text('Crumb')));
        await tester.pump();
        expect(_chipBackground(tester), dsTokensLight.colors.surface.enabled);

        // Toggle `selected` on the same chip element. didUpdateWidget detects
        // the interaction change and resets _hovered -> background goes back to
        // transparent even though the pointer is still over the widget.
        await tester.tap(find.text('Toggle'));
        await tester.pump();
        expect(_chipBackground(tester), Colors.transparent);
      },
    );

    testWidgets(
      'didUpdateWidget keeps the hovered flag when only the label changes',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const _BreadcrumbMutationHarness(),
            theme: DesignSystemTheme.light(),
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer();
        await tester.pump();
        await gesture.moveTo(tester.getCenter(find.text('Crumb')));
        await tester.pump();
        expect(_chipBackground(tester), dsTokensLight.colors.surface.enabled);

        // Rebuild changing only the label (not in the interactionChanged set):
        // the hovered flag survives, so the hover background stays.
        await tester.tap(find.text('Rename'));
        await tester.pump();
        expect(find.text('Renamed'), findsOneWidget);
        expect(_chipBackground(tester), dsTokensLight.colors.surface.enabled);
      },
    );

    testWidgets('pressed gesture renders the pressed background then clears', (
      tester,
    ) async {
      await _pumpBreadcrumbs(
        tester,
        SizedBox(
          width: 600,
          child: DesignSystemBreadcrumbs(
            items: [
              DesignSystemBreadcrumbItem(label: 'Home', onPressed: () {}),
            ],
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Home')),
      );
      await tester.pump();
      // onHighlightChanged(true) -> _pressed=true -> pressed background.
      expect(_chipBackground(tester), dsTokensLight.colors.surface.selected);

      await gesture.up();
      await tester.pump();
      expect(_chipBackground(tester), Colors.transparent);
    });
  });
}

/// Harness that lets a test mutate breadcrumb item properties at runtime so the
/// reused chip element runs through `didUpdateWidget`.
class _BreadcrumbMutationHarness extends StatefulWidget {
  const _BreadcrumbMutationHarness();

  @override
  State<_BreadcrumbMutationHarness> createState() =>
      _BreadcrumbMutationHarnessState();
}

class _BreadcrumbMutationHarnessState
    extends State<_BreadcrumbMutationHarness> {
  bool _selected = false;
  String _label = 'Crumb';

  // Stable callback identity across rebuilds so that changing only the label
  // does not count as an interaction change in didUpdateWidget.
  void _onPressed() {}

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: () => setState(() => _selected = !_selected),
          child: const Text('Toggle'),
        ),
        TextButton(
          onPressed: () => setState(() => _label = 'Renamed'),
          child: const Text('Rename'),
        ),
        DesignSystemBreadcrumbs(
          items: [
            DesignSystemBreadcrumbItem(
              label: _label,
              selected: _selected,
              showChevron: false,
              onPressed: _onPressed,
            ),
          ],
        ),
      ],
    );
  }
}
