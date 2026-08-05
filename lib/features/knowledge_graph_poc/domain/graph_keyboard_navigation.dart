import 'dart:math' as math;
import 'dart:ui';

/// Returns the spatially nearest node in [direction] from [fromId].
///
/// Candidates behind the cursor are excluded. Perpendicular distance receives
/// extra weight so arrow keys follow the row/column a user visually expects.
String? nearestGraphNodeInDirection({
  required Map<String, Offset> positions,
  required String fromId,
  required Offset direction,
}) {
  final origin = positions[fromId];
  if (origin == null || direction.distanceSquared == 0) return null;
  final unit = direction / math.sqrt(direction.distanceSquared);
  String? nearest;
  var bestScore = double.infinity;
  for (final entry in positions.entries) {
    if (entry.key == fromId) continue;
    final delta = entry.value - origin;
    final forward = delta.dx * unit.dx + delta.dy * unit.dy;
    if (forward <= 0) continue;
    final perpendicular = (delta.dx * unit.dy - delta.dy * unit.dx).abs();
    final score = forward + perpendicular * 2;
    if (score < bestScore) {
      bestScore = score;
      nearest = entry.key;
    }
  }
  return nearest;
}
