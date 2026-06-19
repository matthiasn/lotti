import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/util/scroll_anchor.dart';

void main() {
  group('anchorCorrectionOffset', () {
    test('null when drift is within tolerance', () {
      expect(
        anchorCorrectionOffset(
          anchorTop: 200,
          currentTop: 200.3,
          currentOffset: 100,
          minScrollExtent: 0,
          maxScrollExtent: 1000,
        ),
        isNull,
      );
    });

    test('compensates downward drift by scrolling forward', () {
      expect(
        anchorCorrectionOffset(
          anchorTop: 200,
          currentTop: 260,
          currentOffset: 100,
          minScrollExtent: 0,
          maxScrollExtent: 1000,
        ),
        160,
      );
    });

    test('compensates upward drift by scrolling back', () {
      expect(
        anchorCorrectionOffset(
          anchorTop: 200,
          currentTop: 160,
          currentOffset: 100,
          minScrollExtent: 0,
          maxScrollExtent: 1000,
        ),
        60,
      );
    });

    test('clamps to max scroll extent', () {
      expect(
        anchorCorrectionOffset(
          anchorTop: 100,
          currentTop: 700,
          currentOffset: 100,
          minScrollExtent: 0,
          maxScrollExtent: 500,
        ),
        500,
      );
    });

    test('clamps to min scroll extent', () {
      expect(
        anchorCorrectionOffset(
          anchorTop: 700,
          currentTop: 100,
          currentOffset: 100,
          minScrollExtent: 0,
          maxScrollExtent: 1000,
        ),
        0,
      );
    });

    test('null when clamping leaves the offset effectively unchanged', () {
      expect(
        anchorCorrectionOffset(
          anchorTop: 100,
          currentTop: 160,
          currentOffset: 500,
          minScrollExtent: 0,
          maxScrollExtent: 500,
        ),
        isNull,
      );
    });

    test('honours a custom tolerance', () {
      expect(
        anchorCorrectionOffset(
          anchorTop: 200,
          currentTop: 203,
          currentOffset: 100,
          minScrollExtent: 0,
          maxScrollExtent: 1000,
          tolerance: 5,
        ),
        isNull,
      );
    });
  });

  group('ScrollAnchor', () {
    testWidgets(
      'holds the anchored widget at its viewport position when content above '
      'it grows',
      (tester) async {
        final harnessKey = GlobalKey<_AnchorHarnessState>();
        await tester.pumpWidget(_AnchorHarness(key: harnessKey));
        await tester.pump();

        final state = harnessKey.currentState!;
        // Scroll so the anchor sits mid-viewport (not pinned at an extent).
        state.controller.jumpTo(120);
        await tester.pump();

        final before = state.anchorTop();
        expect(before, isNotNull);

        // Capture the anchor, THEN grow the content above it (as a confirmed
        // proposal would add a checklist item above the AI card).
        state.anchor.hold();
        state.grow(300);
        await tester.pump();
        await tester.pump();

        final after = state.anchorTop();
        expect(after, isNotNull);
        // The anchor stayed essentially put despite 300px inserted above it.
        expect((after! - before!).abs(), lessThan(2));
        // ...and the scroll compensated by ~the inserted height.
        expect(state.controller.offset, closeTo(420, 2));

        // After its (small) frame budget drains, the hold releases itself.
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(state.anchor.isHolding, isFalse);
      },
    );

    testWidgets('does nothing when locate returns null (anchor absent)', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final anchor = ScrollAnchor(controller: controller, locate: () => null);
      addTearDown(anchor.dispose);
      anchor.hold();
      expect(anchor.isHolding, isFalse);
    });

    testWidgets('dispose stops an in-flight hold', (tester) async {
      final harnessKey = GlobalKey<_AnchorHarnessState>();
      await tester.pumpWidget(_AnchorHarness(key: harnessKey));
      await tester.pump();
      final state = harnessKey.currentState!;
      state.controller.jumpTo(120);
      await tester.pump();

      state.anchor.hold();
      expect(state.anchor.isHolding, isTrue);
      state.anchor.dispose();
      // After dispose a subsequent grow must not be compensated.
      final offsetAfterDispose = state.controller.offset;
      state.grow(300);
      await tester.pump();
      await tester.pump();
      expect(state.controller.offset, offsetAfterDispose);
    });
  });
}

class _AnchorHarness extends StatefulWidget {
  const _AnchorHarness({super.key});

  @override
  State<_AnchorHarness> createState() => _AnchorHarnessState();
}

class _AnchorHarnessState extends State<_AnchorHarness> {
  final ScrollController controller = ScrollController();
  final GlobalKey _anchorKey = GlobalKey();
  late final ScrollAnchor anchor = ScrollAnchor(
    controller: controller,
    maxFrames: 3,
    locate: () {
      final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return null;
      return box.localToGlobal(Offset.zero).dy;
    },
  );
  double _spacer = 200;

  double? anchorTop() {
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  void grow(double by) => setState(() => _spacer += by);

  @override
  void dispose() {
    anchor.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(400, 600)),
        child: SingleChildScrollView(
          controller: controller,
          child: Column(
            children: [
              SizedBox(height: _spacer),
              Container(
                key: _anchorKey,
                height: 50,
                color: const Color(0xFF00FF00),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
  }
}
