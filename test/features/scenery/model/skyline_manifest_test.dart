import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/model/skyline_manifest.dart';

void main() {
  const m = kPlaceholderSkylineManifest;

  test('every anchor lies within the normalized 0..1 canvas', () {
    final points = [
      ...m.buildingTops,
      ...m.bridgeTowerTops,
      ...m.bridgeDeck,
      ...m.yachtNavLights,
    ];
    for (final o in points) {
      expect(o.dx, inInclusiveRange(0, 1));
      expect(o.dy, inInclusiveRange(0, 1));
    }
    for (final r in [...m.windowCells, m.yachtCabin]) {
      expect(r.left, inInclusiveRange(0, 1));
      expect(r.right, inInclusiveRange(0, 1));
      expect(r.top, inInclusiveRange(0, 1));
      expect(r.bottom, inInclusiveRange(0, 1));
    }
  });

  test('has two bridge towers and a left-to-right deck polyline', () {
    expect(m.bridgeTowerTops, hasLength(2));
    expect(m.bridgeDeck.length, greaterThanOrEqualTo(2));
    for (var i = 1; i < m.bridgeDeck.length; i++) {
      expect(
        m.bridgeDeck[i].dx,
        greaterThan(m.bridgeDeck[i - 1].dx),
        reason: 'deck polyline must run left to right',
      );
    }
  });

  test('waterline sits in the lower band, below every building top', () {
    expect(m.waterline, inInclusiveRange(0.5, 0.9));
    for (final top in m.buildingTops) {
      expect(top.dy, lessThan(m.waterline));
    }
  });

  test('exposes window cells and a full set of yacht nav lights', () {
    expect(m.windowCells, isNotEmpty);
    expect(m.buildingTops, isNotEmpty);
    expect(m.yachtNavLights, hasLength(3));
  });
}
