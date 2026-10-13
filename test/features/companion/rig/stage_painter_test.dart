import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/rig/stage_painter.dart';

import '../companion_test_utils.dart';

double _lum(Color c) => c.r + c.g + c.b;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the ground deepens to the floor and is lit behind her', () async {
    const size = Size(200, 300);
    final r = await Raster.of(200, 300, (canvas) {
      CompanionStage.paintGround(canvas, size, const Offset(100, 120), 100);
    });
    // Away from the light: the top is lighter than the bottom.
    expect(_lum(r.at(5, 5)), greaterThan(_lum(r.at(5, 295))));
    // The light lifts the ground behind her.
    expect(_lum(r.at(100, 120)), greaterThan(_lum(r.at(5, 120))));
  });

  test('the floor shadow darkens under her feet and fades out', () async {
    final r = await Raster.of(
      300,
      60,
      background: const Color(0xFF808080),
      (canvas) {
        canvas.translate(150, 30);
        CompanionStage.paintFloorShadow(canvas);
      },
    );
    expect(_lum(r.at(150, 32)), lessThan(_lum(r.at(150 + 80, 32))));
    expect(r.at(5, 5), const Color(0xFF808080));
  });

  test('the vignette darkens the corners, never the centre', () async {
    final r = await Raster.of(
      200,
      200,
      background: const Color(0xFF808080),
      (canvas) => CompanionStage.paintVignette(canvas, const Size(200, 200)),
    );
    expect(r.at(100, 100), const Color(0xFF808080));
    expect(_lum(r.at(1, 1)), lessThan(_lum(r.at(100, 100))));
  });
}
