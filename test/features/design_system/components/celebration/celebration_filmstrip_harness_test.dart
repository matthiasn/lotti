@Tags(['filmstrip'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/components/celebration/completion_burst.dart';
import 'package:path/path.dart' as p;

import '../../../../widget_test_utils.dart';

/// Renders each [CelebrationVariant]'s burst as a deterministic **filmstrip** —
/// one PNG per frame across the burst timeline — so a panel of reviewers (or a
/// model that can't watch motion) can judge how the animation *progresses* from
/// a strip of stills.
///
/// Two modes, both deterministic (the painters are index-seeded, no RNG):
///
/// * Always: a fast smoke test asserting each variant actually paints and
///   *moves* — a mid-burst frame differs from the empty rest frame, and two
///   different mid-burst frames differ from each other.
/// * Opt-in: when `LOTTI_SCREENSHOT_DIR` is set, every frame is written to
///   `<dir>/celebration_filmstrip/<variant>/frame_<ms>.png` (over a notional
///   1000 ms timeline), the artifact the expert-panel loop rates. Skipped in a
///   normal `make test` run so it neither slows CI nor litters the tree.
///
/// Run just this (and write frames):
///   LOTTI_SCREENSHOT_DIR=/tmp/shots fvm flutter test \
///     --tags filmstrip \
///     test/features/design_system/components/celebration/celebration_filmstrip_harness_test.dart
void main() {
  const boundaryKey = Key('celebration-filmstrip-boundary');
  const frameSize = Size(320, 320);

  // The notional timeline the filmstrip samples, in milliseconds. The burst
  // maps progress 0→1 over this span; the painter fades particles out before
  // the end, so the last frames are near-empty by design.
  const timelineMs = 1000;
  const stepMs = 50;

  /// Pumps a single [variant] burst at [progress] on a dark stage and grabs the
  /// boundary as PNG bytes.
  Future<Uint8List> frame(
    WidgetTester tester,
    CelebrationVariant variant,
    double progress,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: const Color(0xFF101015),
              child: SizedBox.fromSize(
                size: frameSize,
                child: CompletionBurst(
                  progress: progress,
                  variant: variant,
                  origin: Alignment.center,
                  count: 44,
                  reachFactor: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    late Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      bytes = data!.buffer.asUint8List();
    });
    return bytes;
  }

  testWidgets('every variant paints and visibly progresses', (tester) async {
    for (final variant in CelebrationVariant.values) {
      final rest = await frame(tester, variant, 0); // nothing painted yet
      final early = await frame(tester, variant, 0.2);
      final mid = await frame(tester, variant, 0.5);

      // It paints: a mid-burst frame is not the empty rest frame.
      expect(
        mid,
        isNot(equals(rest)),
        reason: '${variant.name}: mid-burst frame should differ from rest',
      );
      // It moves: two different points in the timeline are not identical.
      expect(
        early,
        isNot(equals(mid)),
        reason: '${variant.name}: early and mid frames should differ',
      );
    }
  });

  testWidgets(
    'writes a filmstrip per variant when LOTTI_SCREENSHOT_DIR is set',
    (
      tester,
    ) async {
      final root = Platform.environment['LOTTI_SCREENSHOT_DIR'];
      if (root == null || root.isEmpty) {
        // Opt-in only — keep a normal `make test` fast and the tree clean.
        return;
      }

      for (final variant in CelebrationVariant.values) {
        final dir = Directory(
          p.join(root, 'celebration_filmstrip', variant.name),
        )..createSync(recursive: true);
        for (var ms = 0; ms <= timelineMs; ms += stepMs) {
          final bytes = await frame(tester, variant, ms / timelineMs);
          final label = ms.toString().padLeft(4, '0');
          File(p.join(dir.path, 'frame_$label.png')).writeAsBytesSync(bytes);
        }
        // ignore: avoid_print
        print('wrote filmstrip: ${dir.path}');
      }
    },
  );
}
