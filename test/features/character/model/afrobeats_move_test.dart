import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/model/afrobeats_move.dart';
import 'package:lotti/features/character/model/dance_dynamics.dart';
import 'package:lotti/features/character/model/dance_phrase.dart';

void main() {
  group('AfrobeatsMove.styleJointAccents', () {
    const move = AfrobeatsMove(
      name: 'zanku',
      feel: DanceFeel.offBeat,
      featuredRegion: BodyRegion.legs,
      dynamics: DanceDynamics(weight: 0.8, time: 0.8),
      swingFrames: 0.3,
    );

    test(
      'stamps the move dynamics only where an accent has none of its own',
      () {
        final styled = move.styleJointAccents(const [
          DanceJointAccent(8, radiusFrames: 4, rotation: 1),
          DanceJointAccent(
            16,
            radiusFrames: 4,
            rotation: -1,
            dynamics: DanceDynamics(flow: 1),
          ),
        ]);

        // First accent inherits the move's Strong+Sudden dynamics.
        expect(styled[0].dynamics?.weight, 0.8);
        expect(styled[0].dynamics?.time, 0.8);
        // Second accent keeps its own Free dynamics untouched.
        expect(styled[1].dynamics?.flow, 1);
        expect(styled[1].dynamics?.weight, 0);
      },
    );

    test('adds the move swing on top of any per-accent offset', () {
      final styled = move.styleJointAccents(const [
        DanceJointAccent(8, radiusFrames: 4),
        DanceJointAccent(16, radiusFrames: 4, microFrames: 0.1),
      ]);

      expect(styled[0].microFrames, closeTo(0.3, 1e-9));
      expect(styled[1].microFrames, closeTo(0.4, 1e-9));
    });

    test('preserves the authored pose values (frame, rotation, radius)', () {
      final styled = move.styleJointAccents(const [
        DanceJointAccent(8, radiusFrames: 4, rotation: 1.2, scaleY: 0.9),
      ]);

      expect(styled.single.frame, 8);
      expect(styled.single.radiusFrames, 4);
      expect(styled.single.rotation, 1.2);
      expect(styled.single.scaleY, 0.9);
    });
  });
}
