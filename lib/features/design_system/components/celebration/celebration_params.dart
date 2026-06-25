import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';

/// One tunable knob of a celebration burst: a stable [id] (also the localization
/// key suffix and the JSON field name), the slider [min]/[max] range, the
/// [defaultValue] that reproduces today's hard-coded look, and whether the value
/// is a whole number ([isInt], e.g. particle count).
///
/// The playground builds its slider stack purely from a variant's spec list, so
/// adding a knob is a one-line edit here — no per-variant UI code.
@immutable
class CelebrationSliderSpec {
  const CelebrationSliderSpec(
    this.id, {
    required this.min,
    required this.max,
    required this.defaultValue,
    this.isInt = false,
  });

  final String id;
  final double min;
  final double max;
  final double defaultValue;
  final bool isInt;
}

/// The four knobs every variant shares: how many particles, their size, how far
/// they fly (as a multiple of the anchor height), and the cleared centre ring.
/// [clearCenter] is omitted for variants whose painter ignores it (confetti).
List<CelebrationSliderSpec> _base(
  int count, {
  double size = 0.8,
  double reach = 2.2,
  double? clearCenter = 0.4,
}) => [
  CelebrationSliderSpec(
    'count',
    min: 6,
    max: 90,
    defaultValue: count.toDouble(),
    isInt: true,
  ),
  CelebrationSliderSpec('size', min: 0.4, max: 1.8, defaultValue: size),
  CelebrationSliderSpec('reach', min: 1, max: 3.5, defaultValue: reach),
  if (clearCenter != null)
    CelebrationSliderSpec(
      'clearCenter',
      min: 0,
      max: 0.8,
      defaultValue: clearCenter,
    ),
];

/// The ordered, tunable knobs for [variant] — the shared four plus that
/// variant's characteristic physics. Every [CelebrationSliderSpec.defaultValue]
/// equals the constant
/// the painter used before parameters existed, so a fresh install (or a "reset
/// to default") renders exactly the original look.
List<CelebrationSliderSpec> celebrationSliderSpecs(
  CelebrationVariant variant,
) => switch (variant) {
  CelebrationVariant.sparks => [
    ..._base(40),
    const CelebrationSliderSpec(
      'gravity',
      min: 0,
      max: 0.6,
      defaultValue: 0.16,
    ),
    const CelebrationSliderSpec(
      'speedSpread',
      min: 0,
      max: 1.6,
      defaultValue: 0.8,
    ),
    const CelebrationSliderSpec('trail', min: 0, max: 0.6, defaultValue: 0.2),
    const CelebrationSliderSpec('glow', min: 0, max: 0.6, defaultValue: 0.18),
  ],
  CelebrationVariant.fireworks => [
    ..._base(44),
    const CelebrationSliderSpec(
      'launch',
      min: 0.1,
      max: 0.5,
      defaultValue: 0.28,
    ),
    const CelebrationSliderSpec('fallout', min: 0, max: 1.4, defaultValue: 0.5),
    const CelebrationSliderSpec('twinkle', min: 0, max: 16, defaultValue: 8),
    const CelebrationSliderSpec(
      'innerRing',
      min: 0.2,
      max: 1,
      defaultValue: 0.62,
    ),
  ],
  CelebrationVariant.confetti => [
    ..._base(40, clearCenter: null),
    const CelebrationSliderSpec(
      'spread',
      min: 0.3,
      max: 2.6,
      defaultValue: 1.3,
    ),
    const CelebrationSliderSpec(
      'gravity',
      min: 0.3,
      max: 2.2,
      defaultValue: 1.1,
    ),
    const CelebrationSliderSpec('sway', min: 0, max: 0.3, defaultValue: 0.08),
    const CelebrationSliderSpec('spin', min: 0, max: 16, defaultValue: 6),
  ],
  CelebrationVariant.embers => [
    ..._base(36),
    const CelebrationSliderSpec(
      'fanSpread',
      min: 0.3,
      max: 2.6,
      defaultValue: 1.4,
    ),
    const CelebrationSliderSpec(
      'wobble',
      min: 0,
      max: 0.25,
      defaultValue: 0.07,
    ),
    const CelebrationSliderSpec('halo', min: 0, max: 0.6, defaultValue: 0.22),
    const CelebrationSliderSpec('rise', min: 0.4, max: 2, defaultValue: 1),
  ],
  CelebrationVariant.bubbles => [
    ..._base(24, size: 1, clearCenter: 0.35),
    const CelebrationSliderSpec('upward', min: 0, max: 1, defaultValue: 0.35),
    const CelebrationSliderSpec(
      'wobble',
      min: 0,
      max: 0.25,
      defaultValue: 0.06,
    ),
    const CelebrationSliderSpec('swell', min: 0.8, max: 2.6, defaultValue: 1.6),
    const CelebrationSliderSpec('pop', min: 0.5, max: 0.98, defaultValue: 0.9),
  ],
};

/// The default (untouched) parameter map per variant, built once from the spec
/// table so the values can never drift apart from the slider ranges.
final Map<CelebrationVariant, CelebrationParams> _defaults = {
  for (final variant in CelebrationVariant.values)
    variant: CelebrationParams(
      variant: variant,
      values: {
        for (final spec in celebrationSliderSpecs(variant))
          spec.id: spec.defaultValue,
      },
    ),
};

/// The user-tunable parameters of a celebration burst, held as a flat
/// `id → value` map keyed by [CelebrationSliderSpec.id]. A map (rather than a
/// field per variant) keeps `copyWith`, equality, and JSON trivial and lets the
/// playground drive every knob generically.
///
/// Painters read named knobs via [v]; the four shared knobs have typed getters
/// ([count], [sizeScale], [reachFactor], [clearCenter]). Persisted per variant
/// as the [toJson] map; [tryDecode] tolerates a missing / corrupt blob by
/// returning `null` so the caller can fall back to [CelebrationParams.defaultsFor].
@immutable
class CelebrationParams {
  const CelebrationParams({required this.variant, required this.values});

  /// The untouched parameters for [variant] — every knob at the value that
  /// reproduces the original hard-coded look. Doubles as "reset to default".
  factory CelebrationParams.defaultsFor(CelebrationVariant variant) =>
      _defaults[variant]!;

  final CelebrationVariant variant;
  final Map<String, double> values;

  /// The raw value of knob [id]. Falls back to the spec default if a stored blob
  /// predates a newly added knob, so an old persisted map can never throw. An
  /// [id] with no spec for this variant is a programmer error (every id is a
  /// compile-time constant): fail fast with a clear message rather than silently
  /// returning a misleading value.
  double v(String id) =>
      values[id] ??
      celebrationSliderSpecs(variant)
          .firstWhere(
            (s) => s.id == id,
            orElse: () => throw ArgumentError.value(
              id,
              'id',
              'no celebration knob with this id for variant ${variant.name}',
            ),
          )
          .defaultValue;

  // `count`/`size`/`reach` are in the shared base spec for every variant, so
  // they always resolve through [v] (its spec-default fallback is the single
  // source of truth — no second copy of the numbers to drift from).
  int get count => v('count').round();
  double get sizeScale => v('size');
  double get reachFactor => v('reach');

  /// Confetti's painter ignores the cleared centre, so its map omits the knob;
  /// default to `0` (emit from the exact centre) for those variants.
  double get clearCenter => values['clearCenter'] ?? 0;

  /// A copy with knob [id] set to [value]; the source map is left untouched.
  CelebrationParams withValue(String id, double value) => CelebrationParams(
    variant: variant,
    values: {...values, id: value},
  );

  /// Whether this differs from the untouched default for its variant.
  bool get isCustomized => this != CelebrationParams.defaultsFor(variant);

  Map<String, dynamic> toJson() => {
    'variant': variant.name,
    'values': values,
  };

  /// Decodes a [toJson] map, clamping each known knob into its current slider
  /// range and dropping unknown keys, so a hand-edited or out-of-date blob can
  /// never push a value out of bounds. Returns `null` on a missing / malformed
  /// map (the caller then uses [CelebrationParams.defaultsFor]).
  static CelebrationParams? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final variant = CelebrationVariant.tryFromStorage(
      json['variant'] as String?,
    );
    if (variant == null) return null;
    final raw = json['values'];
    if (raw is! Map) return null;
    final specs = celebrationSliderSpecs(variant);
    final values = <String, double>{};
    for (final spec in specs) {
      final stored = raw[spec.id];
      if (stored is num) {
        values[spec.id] = stored.toDouble().clamp(spec.min, spec.max);
      } else {
        values[spec.id] = spec.defaultValue;
      }
    }
    return CelebrationParams(variant: variant, values: values);
  }

  /// Decodes a JSON [source] string, tolerating null / empty / malformed input
  /// by returning `null`.
  static CelebrationParams? tryDecode(String? source) {
    if (source == null || source.isEmpty) return null;
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic> ? fromJson(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is CelebrationParams &&
      other.variant == variant &&
      mapEquals(other.values, values);

  @override
  int get hashCode => Object.hash(
    variant,
    Object.hashAllUnordered(
      values.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}
