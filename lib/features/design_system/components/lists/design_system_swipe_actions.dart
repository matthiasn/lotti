import 'package:lotti/features/design_system/components/lists/design_system_swipe_action_background.dart';
import 'package:material_ui/material_ui.dart';

/// One direction of a [DesignSystemSwipeActions] row: what the revealed band
/// says, and what letting go there does.
@immutable
class DesignSystemSwipeAction {
  const DesignSystemSwipeAction({
    required this.color,
    required this.foregroundColor,
    required this.icon,
    required this.label,
    required this.onTrigger,
  });

  /// Fill of the band the row is dragged off, and the ink on it. The pair is
  /// chosen per surface so a band always matches the palette it sits in.
  final Color color;
  final Color foregroundColor;
  final IconData icon;

  /// Names the action on the band, so a swipe always says what it will do.
  final String label;
  final VoidCallback onTrigger;
}

/// Wraps a row so a horizontal swipe decides it, with the action named on the
/// band the drag reveals.
///
/// The row always snaps back: these surfaces keep a decided row in place with
/// its outcome tag rather than letting it fly out, so the gesture triggers the
/// callback and the row's own state does the rest. Give a direction no action
/// and that direction does not drag; give neither and the child is returned
/// untouched, which is how a row that is already decided (or disabled) opts
/// out.
///
/// This is the one swipe mechanic behind the AI bands and the lists that share
/// their gestures — a surface picks its palette and its labels, never its own
/// thresholds or dismissal semantics.
class DesignSystemSwipeActions extends StatelessWidget {
  const DesignSystemSwipeActions({
    required this.swipeKey,
    required this.borderRadius,
    required this.child,
    this.startToEnd,
    this.endToStart,
    super.key,
  });

  /// Fraction of the row's width a drag must cross to trigger.
  static const double threshold = 0.4;

  /// Identity of the dragged row, required by the underlying [Dismissible].
  final Key swipeKey;

  /// Corner radius of the row, used to clip the revealed band to its shape.
  final BorderRadius borderRadius;

  /// Dragging the row towards the trailing edge (right, in LTR).
  final DesignSystemSwipeAction? startToEnd;

  /// Dragging the row towards the leading edge (left, in LTR).
  final DesignSystemSwipeAction? endToStart;

  final Widget child;

  static Widget _band(DesignSystemSwipeAction action, Alignment alignment) =>
      DesignSystemSwipeActionBackground(
        alignment: alignment,
        color: action.color,
        foregroundColor: action.foregroundColor,
        icon: action.icon,
        label: action.label,
      );

  @override
  Widget build(BuildContext context) {
    final start = startToEnd;
    final end = endToStart;
    if (start == null && end == null) return child;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Dismissible(
        key: swipeKey,
        direction: start == null
            ? DismissDirection.endToStart
            : end == null
            ? DismissDirection.startToEnd
            : DismissDirection.horizontal,
        dismissThresholds: const {
          DismissDirection.startToEnd: threshold,
          DismissDirection.endToStart: threshold,
        },
        // [Dismissible] refuses a secondary background without a primary one,
        // so a one-direction row hands the same band to both slots; `direction`
        // is what keeps the unused one from ever being dragged into view.
        background: _band(start ?? end!, Alignment.centerLeft),
        secondaryBackground: _band(end ?? start!, Alignment.centerRight),
        // Never actually dismiss: the row stays where it is and changes state.
        confirmDismiss: (direction) async {
          (direction == DismissDirection.startToEnd ? start : end)?.onTrigger();
          return false;
        },
        child: child,
      ),
    );
  }
}
