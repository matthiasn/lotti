import 'package:health/health.dart';

/// Lotti's canonical spelling of a workout type: `lowerCamelCase`, as in
/// `walking`, `running`, `cycling`, `functionalStrengthTraining`.
///
/// That spelling is the one every stored `WorkoutEntry` carried until the app
/// moved from its `flutter_health_fit` fork to the upstream `health` plugin
/// (#2041), and it is what the dashboard workout catalogue, every persisted
/// `DashboardWorkoutItem` and every habit signal keyed on a workout type still
/// use. The upstream plugin names the same activities `UPPER_SNAKE_CASE`
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
/// the plugin's spelling; readers that compare types go through
/// [isSameWorkoutType] so those rows chart too.
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

/// Plugin spellings that differ from the canonical one by more than case.
const _aliases = <String, String>{
  'biking': 'cycling',
};

String _capitalize(String segment) =>
    segment[0].toUpperCase() + segment.substring(1);
