// Every geometry argument is stated even when it matches a default: the
// numbers are what the assertions below are about.
// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/projects/ui/widgets/project_header_title_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

/// A stand-in for the real action rail: the same fixed 48 pt tap target the
/// overflow menu is, without pulling a menu into a layout test.
const _railSize = 48.0;
const _titleHeight = 30.0;

void main() {
  Future<void> pump(
    WidgetTester tester, {
    double width = 400,
    double railWidth = _railSize,
    double gap = 8,
    double lift = 4,
    TextDirection direction = TextDirection.ltr,
    Widget? title,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget2(
        Directionality(
          textDirection: direction,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProjectHeaderTitleRow(
                    gap: gap,
                    lift: lift,
                    title:
                        title ??
                        const SizedBox(
                          key: Key('title'),
                          height: _titleHeight,
                          width: 120,
                        ),
                    actions: SizedBox(
                      key: const Key('actions'),
                      height: _railSize,
                      width: railWidth,
                    ),
                  ),
                  const SizedBox(key: Key('below'), height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('ProjectHeaderTitleRow', () {
    testWidgets('is exactly as tall as its title, not its action rail', (
      tester,
    ) async {
      // The regression this layout exists for: a `Row` would be 48 pt tall
      // and open an empty toolbar band under the project title.
      await pump(tester);
      expect(
        tester.getSize(find.byType(ProjectHeaderTitleRow)).height,
        _titleHeight,
      );
    });

    testWidgets('the content below starts right under the title', (
      tester,
    ) async {
      await pump(tester);
      expect(
        tester.getTopLeft(find.byKey(const Key('below'))).dy -
            tester.getTopLeft(find.byKey(const Key('title'))).dy,
        _titleHeight,
      );
    });

    testWidgets('pins the rail to the trailing corner, lifted', (
      tester,
    ) async {
      await pump(tester, width: 400, lift: 4);
      final row = tester.getRect(find.byType(ProjectHeaderTitleRow));
      final actions = tester.getRect(find.byKey(const Key('actions')));
      expect(actions.right, row.right);
      expect(actions.top, row.top - 4);
    });

    testWidgets('mirrors both slots under right-to-left text', (tester) async {
      await pump(tester, direction: TextDirection.rtl);
      final row = tester.getRect(find.byType(ProjectHeaderTitleRow));
      expect(tester.getRect(find.byKey(const Key('actions'))).left, row.left);
      expect(tester.getRect(find.byKey(const Key('title'))).right, row.right);
    });

    testWidgets('leaves the title the width the rail and gap do not take', (
      tester,
    ) async {
      // A title that would fill any width it is given, so the constraint it
      // received is what its rendered width reports.
      await pump(
        tester,
        width: 400,
        railWidth: 100,
        gap: 8,
        title: const SizedBox(
          key: Key('title'),
          height: _titleHeight,
          width: double.infinity,
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('title'))).width,
        400 - 100 - 8,
      );
    });

    testWidgets('a rail wider than the row is bounded, not overflowed', (
      tester,
    ) async {
      // Clamped rather than negative, and the rail is laid out against the
      // header's own constraints, so it cannot paint past the right edge.
      await pump(
        tester,
        width: 60,
        railWidth: 100,
        title: const SizedBox(
          key: Key('title'),
          height: _titleHeight,
          width: double.infinity,
        ),
      );

      expect(tester.getSize(find.byKey(const Key('title'))).width, 0);
      final row = tester.getRect(find.byType(ProjectHeaderTitleRow));
      final actions = tester.getRect(find.byKey(const Key('actions')));
      expect(actions.width, lessThanOrEqualTo(row.width));
      expect(actions.left, greaterThanOrEqualTo(row.left));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unbounded width falls back to both natural widths', (
      tester,
    ) async {
      // A horizontally scrolling host offers infinite width; the header must
      // size to what its two children actually want.
      await tester.pumpWidget(
        makeTestableWidget2(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ProjectHeaderTitleRow(
              gap: 8,
              lift: 4,
              title: const SizedBox(
                key: Key('title'),
                height: _titleHeight,
                width: 120,
              ),
              actions: const SizedBox(
                key: Key('actions'),
                height: _railSize,
                width: _railSize,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byType(ProjectHeaderTitleRow)).width,
        120 + 8 + _railSize,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets("reports intrinsics: both widths, the title's height", (
      tester,
    ) async {
      await pump(tester, width: 400, railWidth: 60, gap: 8);
      final render = tester.renderObject<RenderProjectHeaderTitleRow>(
        find.byType(ProjectHeaderTitleRow),
      );

      expect(render.getMinIntrinsicWidth(double.infinity), 120 + 8 + 60);
      expect(render.getMaxIntrinsicWidth(double.infinity), 120 + 8 + 60);
      expect(
        render.getMinIntrinsicHeight(400),
        _titleHeight,
        reason: "the rail must not raise the header's intrinsic height",
      );
      expect(render.getMaxIntrinsicHeight(400), _titleHeight);
    });

    testWidgets('a dry layout matches the layout it performs', (tester) async {
      await pump(tester, width: 400, railWidth: 60, gap: 8);
      final render = tester.renderObject<RenderProjectHeaderTitleRow>(
        find.byType(ProjectHeaderTitleRow),
      );

      expect(
        render.getDryLayout(const BoxConstraints(maxWidth: 400)),
        render.size,
      );
    });

    testWidgets('re-laying out on changed gap, lift and direction', (
      tester,
    ) async {
      await pump(tester, gap: 8, lift: 4);
      final first = tester.getRect(find.byKey(const Key('actions')));

      // Same values: the setters short-circuit and nothing moves.
      await pump(tester, gap: 8, lift: 4);
      expect(tester.getRect(find.byKey(const Key('actions'))), first);

      await pump(tester, gap: 20, lift: 10);
      expect(tester.getRect(find.byKey(const Key('actions'))).top, -10);

      await pump(tester, gap: 20, lift: 10, direction: TextDirection.rtl);
      expect(
        tester.getRect(find.byKey(const Key('actions'))).left,
        tester.getRect(find.byType(ProjectHeaderTitleRow)).left,
      );
    });

    testWidgets('the whole rail is tappable, overhang included', (
      tester,
    ) async {
      // The rail hangs below a title-height header, the way it does under the
      // real header's `Column`. Without the hit-test override the header's own
      // bounds would swallow that overhang and leave a 48 pt control with a
      // ~26 pt target.
      var taps = 0;
      await tester.pumpWidget(
        makeTestableWidget2(
          Align(
            alignment: Alignment.topLeft,
            // Inset, so the lifted top of the rail is still on screen.
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ProjectHeaderTitleRow(
                      gap: 8,
                      lift: 4,
                      title: const SizedBox(height: _titleHeight, width: 120),
                      actions: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => taps++,
                        child: const SizedBox(
                          key: Key('actions'),
                          height: _railSize,
                          width: _railSize,
                        ),
                      ),
                    ),
                    // The metadata band the header sits above.
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final actions = tester.getRect(find.byKey(const Key('actions')));
      final row = tester.getRect(find.byType(ProjectHeaderTitleRow));
      expect(
        actions.bottom,
        greaterThan(row.bottom),
        reason: 'the fixture must actually overhang, or this proves nothing',
      );

      await tester.tapAt(Offset(actions.center.dx, row.top + 2));
      expect(taps, 1, reason: 'inside the header band');

      await tester.tapAt(actions.center);
      expect(taps, 2, reason: 'below the header already');

      await tester.tapAt(Offset(actions.center.dx, actions.bottom - 2));
      expect(taps, 3, reason: 'the bottom edge, well below the header');
    });

    testWidgets('a pointer beside the rail is not claimed by the header', (
      tester,
    ) async {
      // The override must not turn the whole band under the header into a
      // catch-all: only the rail's own rectangle is claimed.
      var railTaps = 0;
      var belowTaps = 0;
      await tester.pumpWidget(
        makeTestableWidget2(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProjectHeaderTitleRow(
                    gap: 8,
                    lift: 4,
                    title: const SizedBox(height: _titleHeight, width: 120),
                    actions: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => railTaps++,
                      child: const SizedBox(
                        key: Key('actions'),
                        height: _railSize,
                        width: _railSize,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => belowTaps++,
                    child: const SizedBox(
                      key: Key('below'),
                      height: 40,
                      width: double.infinity,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final actions = tester.getRect(find.byKey(const Key('actions')));
      await tester.tapAt(Offset(actions.left - 20, actions.bottom - 2));

      expect(railTaps, 0);
      expect(belowTaps, 1);
    });
  });
}
