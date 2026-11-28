import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/relationships/ui/widgets/person_timeline_extent.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const a = ValueKey('a');
  const b = ValueKey('b');
  const phone = (390.0, TextScaler.noScaling);

  group('TimelineSlotExtents', () {
    test('is the mean of the least height each slot was seen at', () {
      final extents = TimelineSlotExtents()
        ..measure(a, 100, layout: phone)
        ..measure(b, 40, layout: phone);
      expect(extents.mean, 70);

      // Opened: twenty times its height. It still counts as it was.
      extents.measure(a, 2000, layout: phone);
      expect(extents.mean, 70);

      // Seen shorter, it counts as that.
      extents.measure(a, 60, layout: phone);
      expect(extents.mean, 50);
    });

    test('forgets what it measured at another width or text scale', () {
      final extents = TimelineSlotExtents()
        ..measure(a, 100, layout: phone)
        ..measure(b, 40, layout: phone)
        // The pane narrowed: the same row wraps onto more lines.
        ..measure(a, 180, layout: (280.0, TextScaler.noScaling));
      expect(extents.mean, 180, reason: 'the narrower layout alone');

      extents.measure(a, 260, layout: (280.0, const TextScaler.linear(1.5)));
      expect(extents.mean, 260, reason: 'the larger text alone');
    });
  });

  testWidgets('MeasuredSlot reports the size its child is laid out at, again '
      'when it changes and to the newest callback', (tester) async {
    final first = <Size>[];
    final second = <Size>[];
    Widget slot(double height, List<Size> into) => makeTestableWidget(
      Center(
        child: MeasuredSlot(
          onSize: into.add,
          child: SizedBox(width: 120, height: height),
        ),
      ),
    );

    await tester.pumpWidget(slot(48, first));
    expect(first, [const Size(120, 48)]);

    await tester.pumpWidget(slot(96, second));
    expect(first, hasLength(1), reason: 'the replaced callback hears nothing');
    expect(second, [const Size(120, 96)]);
  });

  testWidgets('TimelineChildDelegate claims the rows left at the usual '
      'height, whatever is on stage', (tester) async {
    // Forty rows of 50, the first opened to 3000: on stage alone it would
    // have the list claim 40 x 3000.
    final extents = TimelineSlotExtents();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    const viewport = 600.0;
    setTestSurfaceSize(tester, const Size(400, viewport));
    Widget list({required bool opened}) => makeTestableWidgetNoScroll(
      CustomScrollView(
        controller: controller,
        slivers: [
          SliverList(
            delegate: TimelineChildDelegate(
              (context, index) => MeasuredSlot(
                onSize: (size) => extents.measure(
                  ValueKey(index),
                  size.height,
                  layout: size.width,
                ),
                child: SizedBox(height: opened && index == 0 ? 3000 : 50),
              ),
              extents: extents,
              childCount: 40,
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(list(opened: false));
    await tester.pumpWidget(list(opened: true));

    const real = 3000 + 39 * 50 - viewport;
    expect(controller.position.maxScrollExtent, real);
  });
}
