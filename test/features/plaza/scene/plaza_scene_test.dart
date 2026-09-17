import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/scene/plaza_scene.dart';

// The scene itself needs a GPU to build; what can be pinned without one is
// the order of the ground layers, which is what keeps the decals from
// fighting the paving for depth.
void main() {
  group('the ground layers', () {
    test('the decal plane clears the pavement it lights and shades', () {
      expect(
        PlazaSceneController.groundTop,
        greaterThan(PlazaSceneController.pavementTop),
      );
    });

    test('the map ribbon tops out under the decal plane', () {
      // From the air every shadow cast across a road lies over the ribbon;
      // an opaque face at the decals' own height ties the depth test with
      // each of them and stipples as the camera moves.
      expect(
        PlazaSceneController.mapRibbonTop,
        lessThan(PlazaSceneController.groundTop),
      );
      // With room to spare: the pavement's single centimetre already needs
      // the altitude-scaled near plane; the ribbon keeps three.
      expect(
        PlazaSceneController.groundTop - PlazaSceneController.mapRibbonTop,
        greaterThanOrEqualTo(0.03),
      );
    });

    test('the map ribbon still stands proud of the road markings', () {
      const ribbonBottom =
          PlazaSceneController.mapRibbonTop -
          PlazaSceneController.mapRibbonThickness;
      expect(ribbonBottom, greaterThan(PlazaSceneController.roadMarkingsTop));
    });
  });
}
