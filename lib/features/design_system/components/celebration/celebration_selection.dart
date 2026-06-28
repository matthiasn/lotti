import 'package:flutter/foundation.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';

/// The concrete variant(s) one completion fires, after a [CelebrationSelection]
/// is resolved. [secondary] is non-null only for "combine two", where two
/// particle languages are layered.
@immutable
class ResolvedCelebration {
  const ResolvedCelebration(this.primary, [this.secondary]);

  final CelebrationVariant primary;
  final CelebrationVariant? secondary;

  bool get isCombined => secondary != null;

  @override
  bool operator ==(Object other) =>
      other is ResolvedCelebration &&
      other.primary == primary &&
      other.secondary == secondary;

  @override
  int get hashCode => Object.hash(primary, secondary);
}

/// What a content type (tasks / habits / checklist items) celebrates with. Three
/// flavours: a [FixedSelection] of one variant, a [RandomSelection] that picks a
/// fresh variant on every completion, and a [CombineSelection] that layers a
/// fresh pair every time — so "you never know what you get".
///
/// Persisted as a single [token] string: the variant `name` for a fixed choice,
/// or the [randomToken] / [combineToken] sentinel. [fromToken] is backward
/// compatible — values stored before surprise modes existed are variant names
/// and decode to a [FixedSelection].
@immutable
sealed class CelebrationSelection {
  const CelebrationSelection();

  static const String randomToken = '__random__';
  static const String combineToken = '__combine__';

  static const CelebrationSelection random = RandomSelection();
  static const CelebrationSelection combine = CombineSelection();

  /// Resolves to the variant(s) for one fire. Deterministic in [seed] so tests
  /// are reproducible; callers pass a fresh [seed] per completion (see
  /// [nextCelebrationSeed]) to re-roll surprise modes.
  ResolvedCelebration resolve({required int seed});

  /// The persisted form (see class doc).
  String get token;

  /// Decodes a stored [token], tolerating null / empty / unknown values by
  /// returning `null` so the caller can fall back to a product default.
  static CelebrationSelection? fromToken(String? token) {
    if (token == null || token.isEmpty) return null;
    if (token == randomToken) return random;
    if (token == combineToken) return combine;
    final variant = CelebrationVariant.tryFromStorage(token);
    return variant == null ? null : FixedSelection(variant);
  }
}

/// One fixed variant, played every time.
class FixedSelection extends CelebrationSelection {
  const FixedSelection(this.variant);

  final CelebrationVariant variant;

  @override
  ResolvedCelebration resolve({required int seed}) =>
      ResolvedCelebration(variant);

  @override
  String get token => variant.name;

  @override
  bool operator ==(Object other) =>
      other is FixedSelection && other.variant == variant;

  @override
  int get hashCode => variant.hashCode;
}

/// A fresh random variant on every completion.
class RandomSelection extends CelebrationSelection {
  const RandomSelection();

  @override
  ResolvedCelebration resolve({required int seed}) {
    const values = CelebrationVariant.values;
    return ResolvedCelebration(values[seed % values.length]);
  }

  @override
  String get token => CelebrationSelection.randomToken;

  @override
  bool operator ==(Object other) => other is RandomSelection;

  @override
  int get hashCode => CelebrationSelection.randomToken.hashCode;
}

/// A fresh pair of distinct variants, layered, on every completion.
class CombineSelection extends CelebrationSelection {
  const CombineSelection();

  @override
  ResolvedCelebration resolve({required int seed}) {
    const values = CelebrationVariant.values;
    final n = values.length;
    // With a single variant there is no distinct pair to combine, and the
    // offset divisor `(n - 1)` below would be zero; fall back to that lone
    // variant. Unreachable today (five variants) but keeps this total.
    if (n <= 1) return ResolvedCelebration(values.first);
    final a = seed % n;
    // An offset in 1..n-1 guarantees the second variant differs from the first
    // and still varies as the seed advances.
    final b = (a + 1 + (seed ~/ n) % (n - 1)) % n;
    return ResolvedCelebration(values[a], values[b]);
  }

  @override
  String get token => CelebrationSelection.combineToken;

  @override
  bool operator ==(Object other) => other is CombineSelection;

  @override
  int get hashCode => CelebrationSelection.combineToken.hashCode;
}

/// A process-wide monotonic counter that feeds [CelebrationSelection.resolve],
/// so Random / Combine roll a new look on *every* completion across the app
/// (rather than per build). Not for security — just to advance the deterministic
/// resolve seed. Reset between tests via [debugResetCelebrationSeed].
int _celebrationSeed = 0;

int nextCelebrationSeed() => _celebrationSeed++;

@visibleForTesting
void debugResetCelebrationSeed() => _celebrationSeed = 0;
