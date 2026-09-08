import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/building_architecture.dart';

void main() {
  test('Art Deco crown narrows through three distinct setbacks', () {
    final kit = BuildingArchitecture.forEnvelope(
      id: 'landmark',
      width: 30,
      depth: 12,
      height: 80,
      family: BuildingFamily.steppedTower,
      minimumFrontageHeight: 60,
    );
    final crown = kit.volumes.where((volume) => volume.bottom >= 60).toList();
    expect(crown, hasLength(3));
    expect(crown.first.bottom, 60);
    expect(crown.last.top, 80);
    for (var i = 1; i < crown.length; i++) {
      expect(crown[i].width, lessThan(crown[i - 1].width));
      expect(crown[i].bottom, crown[i - 1].top);
    }
    expect(crown.last.width, lessThan(30 / 2));
  });

  for (final family in BuildingFamily.values) {
    test('$family keeps solids and signs within the reserved plot', () {
      for (final width in [5.0, 14.0, 30.0]) {
        for (final height in [6.0, 20.0, 60.0]) {
          final kit = BuildingArchitecture.forEnvelope(
            id: 'task',
            width: width,
            depth: 12,
            height: height,
            family: family,
          );
          expect(kit.family, family);
          expect(kit.front, 6);
          expect(kit.volumes.first.top, kit.entranceHeight);
          expect(
            kit.volumes.first.z + kit.volumes.first.depth / 2,
            lessThan(kit.front),
          );
          for (final volume in kit.volumes) {
            expect(volume.height, greaterThan(0));
            expect(volume.width, greaterThan(0));
            expect(volume.depth, greaterThan(0));
            expect(
              volume.x.abs() + volume.width / 2,
              lessThanOrEqualTo(width / 2 + 1e-9),
            );
            expect(volume.z.abs() + volume.depth / 2, lessThanOrEqualTo(6));
            expect(volume.bottom, greaterThanOrEqualTo(0));
            expect(volume.top, lessThanOrEqualTo(height + 1e-9));
          }
          expect(kit.volumes.last.top, closeTo(height, 1e-9));
          expect(kit.volumes.last.width, lessThan(width));
          expect(kit.facadeWidth, lessThan(width));
          expect(kit.facadeBottom, greaterThan(kit.entranceHeight));
          expect(
            kit.facadeBottom + kit.facadeHeight,
            lessThan(kit.frontageHeight),
          );
        }
      }
    });
  }

  test(
    'priority changes sign area without moving its centre or street plane',
    () {
      BuildingArchitecture kit(double scale) =>
          BuildingArchitecture.forEnvelope(
            id: 'same-task',
            width: 16,
            depth: 12,
            height: 25,
            billboardScale: scale,
          );
      final large = kit(1);
      final small = kit(0.6);
      expect(small.facadeWidth, closeTo(large.facadeWidth * 0.6, 1e-9));
      expect(small.facadeHeight, closeTo(large.facadeHeight * 0.6, 1e-9));
      expect(small.facadeCenterY, closeTo(large.facadeCenterY, 1e-9));
      expect(small.front, large.front);
      expect(small.family, large.family);
    },
  );

  test(
    'seed selects reproducible families and proportions remain configurable',
    () {
      BuildingArchitecture kit(int seed) => BuildingArchitecture.forEnvelope(
        id: 'same-task',
        width: 20,
        depth: 12,
        height: 30,
        config: ArchitectureConfig(
          seed: seed,
          streetwallFraction: 0.8,
          towerInsetFraction: 0.25,
        ),
      );
      final families = <BuildingFamily>{};
      for (var seed = 0; seed < 30; seed++) {
        final result = kit(seed);
        expect(result.family, kit(seed).family);
        expect(result.frontageHeight, 24);
        expect(result.facadeWidth, 15);
        families.add(result.family);
      }
      expect(families, BuildingFamily.values.toSet());
    },
  );

  test('landmark frontage reservation leaves its full sign envelope clear', () {
    final kit = BuildingArchitecture.forEnvelope(
      id: 'landmark',
      width: 20,
      depth: 12,
      height: 30,
      minimumFrontageHeight: 30,
    );
    expect(kit.volumes, hasLength(2));
    expect(kit.frontageHeight, 30);
    expect(kit.volumes.last.top, 30);
    expect(kit.volumes.clear, throwsUnsupportedError);
  });
}
