import 'package:lotti/features/character/model/dance_dynamics.dart';
import 'package:lotti/features/character/model/dance_phrase.dart';

/// Which part of the body a move features — used to request the matching camera
/// framing (legs → the legwork-hero shot, arms → a hands-visible medium, …) and
/// to keep the trio's featured beats varied.
enum BodyRegion { legs, arms, chest, feet, full }

/// A reusable Afrobeats dance move: its identity ([name]), its [feel] against
/// the downbeat, the body region it [featuredRegion] (for the camera director),
/// its default Laban-Effort [dynamics], and a default sub-frame [swingFrames]
/// pocket. Together [feel] + [swingFrames] make a move's timing **explicit and
/// reviewable** (an Afrobeats coach judges the downbeat relationship directly),
/// rather than implicit in where each accent happens to sit.
///
/// A catalog move is authored as plain per-bone accents and then *stamped* with
/// this move's effort and pocket via [styleJointAccents], so the feel / effort /
/// timing live in ONE place instead of being repeated on every accent.
class AfrobeatsMove {
  const AfrobeatsMove({
    required this.name,
    required this.feel,
    required this.featuredRegion,
    this.dynamics = DanceDynamics.neutral,
    this.swingFrames = 0,
  });

  /// Lookup/display name (e.g. `zanku`, `shaku`, `pouncing-cat`).
  final String name;

  /// How the move's signature accent relates to the downbeat.
  final DanceFeel feel;

  /// The body region the move shows off — the camera director frames it.
  final BodyRegion featuredRegion;

  /// The move's default Effort dynamics, applied to any accent that does not
  /// already carry its own.
  final DanceDynamics dynamics;

  /// The move's default sub-frame swing (fractional frames) — the pocket — added
  /// to every accent so the whole move sits a hair behind (positive) or ahead
  /// (negative) of the beat. Realises the [feel] past the integer frame grid.
  final double swingFrames;

  /// Stamps [accents] with this move's identity: each accent inherits the move
  /// [dynamics] unless it specifies its own, and each accent's swing gains this
  /// move's [swingFrames] on top of any per-accent offset it already has.
  List<DanceJointAccent> styleJointAccents(List<DanceJointAccent> accents) => [
    for (final accent in accents)
      DanceJointAccent(
        accent.frame,
        radiusFrames: accent.radiusFrames,
        rotation: accent.rotation,
        scaleX: accent.scaleX,
        scaleY: accent.scaleY,
        ease: accent.ease,
        dynamics: accent.dynamics ?? dynamics,
        microFrames: accent.microFrames + swingFrames,
      ),
  ];
}
