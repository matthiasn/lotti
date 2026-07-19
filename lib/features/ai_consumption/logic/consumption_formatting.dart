/// Pure adaptive-unit formatters for AI consumption metrics.
///
/// Values are stored in the units Melious delivers (credits, kWh, g CO₂,
/// liters — see `AiConsumptionEvent`); display adapts the unit to the
/// magnitude so a single task ("12 Wh") and a whole year ("34 kWh") both read
/// naturally. Every formatter returns a value **with** its unit suffix so call
/// sites can never mislabel a converted number.
///
/// Number shaping rule, shared by all metrics: one decimal below 10, whole
/// numbers from 10 up (`_shaped`). Sub-threshold amounts collapse to a `<`
/// floor (e.g. `<1 Wh`) instead of noisy long fractions.
library;

import 'package:intl/intl.dart';

final NumberFormat _oneDecimal = NumberFormat('0.0');
final NumberFormat _whole = NumberFormat('0');
final NumberFormat _twoDecimals = NumberFormat('0.00');
final NumberFormat _compact = NumberFormat.compact();

/// One decimal below 10, whole number from 10 up: `3.4`, `9.9`, `12`, `120`.
String _shaped(double value) =>
    value < 10 ? _oneDecimal.format(value) : _whole.format(value);

/// Formats Melious credits using the product's established EUR presentation.
///
/// The euro symbol is presentation only; persisted events retain the raw
/// provider-reported credits and do not attach or infer currency metadata.
String formatCredits(double credits) {
  if (credits <= 0) return '€0.00';
  if (credits < 0.01) return '<€0.01';
  if (credits < 100) return '€${_twoDecimals.format(credits)}';
  return '€${_whole.format(credits)}';
}

/// Formats energy stored in kWh, degrading to Wh below 1 kWh.
///
/// `12 Wh`, `1.2 kWh`, `34 kWh`; below one watt-hour collapses to `<1 Wh`
/// (`0 Wh` for zero).
String formatEnergyKwh(double kwh) {
  if (kwh <= 0) return '0 Wh';
  if (kwh >= 1) return '${_shaped(kwh)} kWh';
  final wh = kwh * 1000;
  if (wh < 1) return '<1 Wh';
  return '${_shaped(wh)} Wh';
}

/// Formats carbon stored in grams CO₂, escalating to kg at 1000 g.
///
/// `0.4 g`, `3.4 g`, `120 g`, `1.2 kg`; below a tenth of a gram collapses to
/// `<0.1 g` (`0 g` for zero).
String formatCarbonGrams(double grams) {
  if (grams <= 0) return '0 g';
  if (grams >= 1000) return '${_shaped(grams / 1000)} kg';
  if (grams < 0.1) return '<0.1 g';
  return '${_shaped(grams)} g';
}

/// Formats water stored in liters, degrading to mL below 1 L.
///
/// `12 mL`, `1.2 L`; below one milliliter collapses to `<1 mL` (`0 mL` for
/// zero).
String formatWaterLiters(double liters) {
  if (liters <= 0) return '0 mL';
  if (liters >= 1) return '${_shaped(liters)} L';
  final ml = liters * 1000;
  if (ml < 1) return '<1 mL';
  return '${_shaped(ml)} mL';
}

/// Formats a token count compactly: `950`, `12.3K`, `4.5M`.
String formatTokenCount(int tokens) => _compact.format(tokens);

/// Formats a call/request count compactly: `7`, `950`, `12.3K`.
String formatCallCount(int calls) => _compact.format(calls);
