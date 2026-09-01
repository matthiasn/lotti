import 'package:health/health.dart';

/// Lotti's canonical spelling of a workout type: `lowerCamelCase`, as in
/// `walking`, `running`, `cycling`, `functionalStrengthTraining`.
///
/// That spelling is the one every stored `WorkoutEntry` carried until the app
/// moved from its `flutter_health_fit` fork to the upstream `health` plugin
/// (#2041), and it is what the dashboard workout catalogue and every persisted
/// `DashboardWorkoutItem` still use. The upstream plugin names the same
/// activities `UPPER_SNAKE_CASE`
/// (`HealthWorkoutActivityType.WALKING`), and importing that name verbatim is
/// what made every workout recorded since invisible to the charts that looked
/// for `walking`.
///
/// The conversion is mechanical — split on `_`, lower-case, camel-join — with
/// one alias on top: the plugin folds HealthKit's `cycling` into `BIKING`, and
/// the fork (like HealthKit, and the rows imported through it) called it
/// `cycling`. Anything already in the canonical shape passes through unchanged,
/// so the function is idempotent and safe to apply to stored and incoming
/// values alike.
///
/// Rows imported between #2041 and this normalisation are still stored under
/// the plugin's spelling; readers that compare types in Dart go through
/// [isSameWorkoutType], and readers that match by SQL equality query every
/// spelling via [workoutTypeSpellings], so those rows — and rules keyed on
/// them — keep working.
String canonicalWorkoutType(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  final String camel;
  if (trimmed.contains('_') || trimmed.toUpperCase() == trimmed) {
    // The plugin's `UPPER_SNAKE_CASE` enum name.
    final segments = trimmed
        .split('_')
        .where((segment) => segment.isNotEmpty)
        .map((segment) => segment.toLowerCase())
        .toList();
    if (segments.isEmpty) {
      return '';
    }
    camel = segments.first + segments.skip(1).map(_capitalize).join();
  } else {
    // Already camelCase — only a stray leading capital is folded.
    camel = trimmed[0].toLowerCase() + trimmed.substring(1);
  }

  // A value without a single lower-case letter — digits, or a lone capital —
  // would otherwise read as UPPER_SNAKE on the next pass and change again.
  final settled = camel.contains(RegExp('[a-z]')) ? camel : camel.toLowerCase();
  return _aliases[settled] ?? settled;
}

/// The canonical type string for a plugin activity — what a workout imported
/// from Apple Health or Health Connect is stored under.
String workoutTypeForActivity(HealthWorkoutActivityType activity) =>
    canonicalWorkoutType(activity.name);

/// Whether two stored or configured workout type strings name the same
/// activity, whichever era's spelling each of them carries.
bool isSameWorkoutType(String a, String b) =>
    canonicalWorkoutType(a) == canonicalWorkoutType(b);

/// Every spelling under which rows of [type]'s activity may be stored, for
/// readers that match by SQL equality on the row's `subtype`
/// (`workoutsByType`): the canonical camelCase, the plugin's
/// `UPPER_SNAKE_CASE`, any alias family ([type] `cycling` also queries
/// `biking`/`BIKING`), and — future-proofing against spellings this module
/// never produced — [type] itself, verbatim.
///
/// The canonical form leads and the order is deterministic, so callers that
/// fan one query out per spelling do so in a stable sequence. Empty strings
/// are dropped: no stored row carries an empty activity worth matching.
List<String> workoutTypeSpellings(String type) {
  final canonical = canonicalWorkoutType(type);
  final spellings = <String>{
    if (canonical.isNotEmpty) ...[canonical, _upperSnakeOf(canonical)],
    for (final MapEntry(key: alias, value: target) in _aliases.entries)
      if (target == canonical) ...[alias, _upperSnakeOf(alias)],
    type.trim(),
  }..remove('');
  return List.unmodifiable(spellings);
}

/// The plugin's `UPPER_SNAKE_CASE` rendering of a canonical camelCase name.
String _upperSnakeOf(String camel) => camel
    .replaceAllMapped(
      RegExp('([a-z0-9])([A-Z])'),
      (match) => '${match[1]}_${match[2]}',
    )
    .toUpperCase();

/// Plugin spellings that differ from the canonical one by more than case.
const _aliases = <String, String>{
  'biking': 'cycling',
};

String _capitalize(String segment) =>
    segment[0].toUpperCase() + segment.substring(1);
