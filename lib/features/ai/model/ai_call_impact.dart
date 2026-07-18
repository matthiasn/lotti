import 'package:meta/meta.dart';

/// The per-call cost + environmental impact of one AI backend call.
///
/// Parsed from the top-level JSON of a **non-streaming** Melious chat/image
/// response (`environment_impact` + `billing_cost`). Melious only reports these
/// on non-streaming responses — streaming yields just token `usage` — so this
/// is surfaced out of band via an [InferenceImpactCollector] rather than riding
/// the (typed) stream. Every field is nullable: other providers never populate
/// it, and Melious may omit fields.
///
/// Units are exactly as Melious delivers them (no lossy conversion): energy in
/// kWh, carbon in grams CO₂, water in litres, cost in credits (≈ EUR).
@immutable
class MeliousCallImpact {
  const MeliousCallImpact({
    this.energyKwh,
    this.carbonGCo2,
    this.waterLiters,
    this.renewablePercent,
    this.pue,
    this.dataCenter,
    this.providerId,
    this.costCredits,
    this.costCreditsDecimal,
  });

  /// Parses the impact from a decoded non-streaming response body. Tolerant of
  /// missing/oddly-typed fields — anything unparseable becomes null.
  factory MeliousCallImpact.fromResponseJson(
    Map<String, dynamic> top, {
    String? costCreditsDecimal,
  }) {
    final env = top['environment_impact'];
    final billing = top['billing_cost'];
    final envMap = env is Map<String, dynamic>
        ? env
        : const <String, dynamic>{};
    final billingMap = billing is Map<String, dynamic>
        ? billing
        : const <String, dynamic>{};
    return MeliousCallImpact(
      energyKwh: _toDouble(envMap['energy_kwh']),
      carbonGCo2: _toDouble(envMap['carbon_g_co2']),
      waterLiters: _toDouble(envMap['water_liters']),
      renewablePercent: _toDouble(envMap['renewable_percent']),
      pue: _toDouble(envMap['pue']),
      dataCenter: _toStringOrNull(envMap['location']),
      providerId: _toStringOrNull(envMap['provider_id']),
      costCredits: _toDouble(billingMap['credits']),
      costCreditsDecimal:
          costCreditsDecimal ?? _toDecimalString(billingMap['credits']),
    );
  }

  /// Extracts the provider's unmodified JSON number/string representation.
  ///
  /// This runs before `jsonDecode` converts JSON numbers to binary doubles, so
  /// billing evidence retains all provider-reported decimal digits.
  static String? costDecimalFromResponseBody(String body) {
    final match = _billingCreditsPattern.firstMatch(body);
    if (match == null) return null;
    return match.namedGroup('number') ?? match.namedGroup('string');
  }

  /// Energy in kilowatt-hours (`environment_impact.energy_kwh`).
  final double? energyKwh;

  /// Carbon in grams of CO₂ (`environment_impact.carbon_g_co2`).
  final double? carbonGCo2;

  /// Water in litres (`environment_impact.water_liters`).
  final double? waterLiters;

  /// Percentage of the data centre's energy from renewables, 0–100
  /// (`environment_impact.renewable_percent`).
  final double? renewablePercent;

  /// Power-usage-effectiveness of the data centre (`environment_impact.pue`).
  final double? pue;

  /// The serving data-centre location (`environment_impact.location`, e.g.
  /// `"FI"`).
  final String? dataCenter;

  /// The upstream provider that served the call
  /// (`environment_impact.provider_id`).
  final String? providerId;

  /// Billing cost in Melious credits, ≈ EUR (`billing_cost.credits`).
  final double? costCredits;

  /// Exact provider-reported billing decimal, retained for audit evidence.
  final String? costCreditsDecimal;

  /// Whether any field was reported — lets callers skip an all-null impact.
  bool get hasData =>
      energyKwh != null ||
      carbonGCo2 != null ||
      waterLiters != null ||
      renewablePercent != null ||
      pue != null ||
      dataCenter != null ||
      providerId != null ||
      costCredits != null ||
      costCreditsDecimal != null;

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String? _toStringOrNull(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static String? _toDecimalString(Object? value) => switch (value) {
    final String value when value.trim().isNotEmpty => value.trim(),
    final num value => value.toString(),
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeliousCallImpact &&
          other.energyKwh == energyKwh &&
          other.carbonGCo2 == carbonGCo2 &&
          other.waterLiters == waterLiters &&
          other.renewablePercent == renewablePercent &&
          other.pue == pue &&
          other.dataCenter == dataCenter &&
          other.providerId == providerId &&
          other.costCredits == costCredits &&
          other.costCreditsDecimal == costCreditsDecimal;

  @override
  int get hashCode => Object.hash(
    energyKwh,
    carbonGCo2,
    waterLiters,
    renewablePercent,
    pue,
    dataCenter,
    providerId,
    costCredits,
    costCreditsDecimal,
  );

  @override
  String toString() =>
      'MeliousCallImpact(energyKwh: $energyKwh, carbonGCo2: $carbonGCo2, '
      'waterLiters: $waterLiters, renewablePercent: $renewablePercent, '
      'pue: $pue, dataCenter: $dataCenter, providerId: $providerId, '
      'costCredits: $costCredits, costCreditsDecimal: $costCreditsDecimal)';
}

final RegExp _billingCreditsPattern = RegExp(
  r'"billing_cost"\s*:\s*\{[^{}]*?"credits"\s*:\s*'
  r'(?:(?<number>-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)|'
  r'"(?<string>-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)")',
);

/// A mutable side-channel that carries a [MeliousCallImpact] up from the Melious
/// adapter (which parses the non-streaming body) to the capture point, without
/// threading it through the typed inference stream.
///
/// Mirrors `ThoughtSignatureCollector`: the caller constructs one, passes it
/// down the inference call chain, and reads [impact] after the response drains.
/// The Melious adapter assigns [impact] from the non-streaming body; non-Melious
/// providers never touch it, so it stays null.
class InferenceImpactCollector {
  MeliousCallImpact? impact;
}
