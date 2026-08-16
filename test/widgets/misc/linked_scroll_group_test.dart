import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/misc/linked_scroll_group.dart';

void main() {
  testWidgets('dragging one member scrolls every member — clamped to a '
      "shorter member's own extent", (tester) async {
    final group = LinkedScrollGroup();
    addTearDown(group.dispose);
    final long = group.attach();
    final short = group.attach();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          // A 300px viewport, so BOTH members overflow — the short one by
          // 200px, the long one by 700px.
          child: SizedBox(
            width: 300,
            child: Column(
              children: [
                SizedBox(
                  height: 50,
                  child: SingleChildScrollView(
                    key: const ValueKey('long'),
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    controller: long,
                    child: const SizedBox(width: 1000, height: 50),
                  ),
                ),
                SizedBox(
                  height: 50,
                  child: SingleChildScrollView(
                    key: const ValueKey('short'),
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    controller: short,
                    child: const SizedBox(width: 500, height: 50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Members share an anchor: reverse scroll views measure offsets from
    // the trailing edge, so both open showing "today".
    expect(long.offset, 0);
    expect(short.offset, 0);

    // Reverse + LTR: dragging content to the RIGHT increases the offset.
    await tester.drag(find.byKey(const ValueKey('long')), const Offset(60, 0));
    await tester.pump();
    expect(long.offset, greaterThan(0));
    expect(short.offset, moreOrLessEquals(long.offset, epsilon: 0.5));

    // Past the short member's extent, it pins to its edge while the long
    // one keeps going — mirrored, never overscrolled.
    await tester.drag(
      find.byKey(const ValueKey('long')),
      const Offset(400, 0),
    );
    await tester.pump();
    final shortMax = short.position.maxScrollExtent;
    expect(long.offset, greaterThan(shortMax));
    expect(short.offset, moreOrLessEquals(shortMax, epsilon: 0.5));
  });
}
