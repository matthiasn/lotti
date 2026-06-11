import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Sticky glass action bar for the day-planning modal — the planner's
/// counterpart to the task details `TaskActionBar`.
///
/// Built on the shared [DesignSystemGlassStrip] (top hairline + backdrop
/// blur + scrim gradient), it stacks an optional [topSlot] (the AI thinking
/// shader, riding the top edge of the bar) above an [actions] row. All of a
/// planning step's clickable interactions live in [actions]; the body above
/// stays display-only.
///
/// Used as each step's `stickyActionBar` inside the Wolt multi-page modal,
/// so a single bar treatment carries across Capture → Reconcile → Drafting
/// → Refine while the contents change per step.
class DayPlanningGlassActionBar extends StatelessWidget {
  const DayPlanningGlassActionBar({
    required this.actions,
    this.topSlot,
    super.key,
  });

  /// The action row (buttons/pills). Laid out full-width below [topSlot].
  final Widget actions;

  /// Optional widget pinned to the top edge of the bar — the day-planning
  /// thinking shader. Collapses to zero height when idle, so the bar keeps
  /// its standard padding whether or not it is present.
  final Widget? topSlot;

  /// Stable test key for the optional top (shader) slot.
  @visibleForTesting
  static const Key topSlotKey = ValueKey('day-planning-action-bar-top-slot');

  /// Action rows are capped to the planning surfaces' content width so a
  /// wide host (the desktop side sheet) doesn't stretch pills into
  /// full-width slabs.
  @visibleForTesting
  static const double actionsMaxWidth = 560;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;

    // The glass surface extends edge-to-edge into the system home-indicator
    // inset; the touchable row sits above it via the bottom padding.
    final safeBottomInset = MediaQuery.paddingOf(context).bottom;

    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          spacing.step5,
          spacing.step4,
          spacing.step5,
          spacing.step4 + safeBottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (topSlot != null) KeyedSubtree(key: topSlotKey, child: topSlot!),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: actionsMaxWidth),
                child: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
