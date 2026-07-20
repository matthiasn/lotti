import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';

/// Placeholder shown in the detail pane of a desktop split layout
/// when no item has been selected yet.
///
/// Thin alias over [DesignSystemEmptyState], which owns the empty-state
/// grammar (glyph + `subtitle1` title), so every split view's idle pane
/// speaks the same typographic ramp as the list zero-states.
class DesktopDetailEmptyState extends StatelessWidget {
  const DesktopDetailEmptyState({
    required this.message,
    this.icon = Icons.touch_app_outlined,
    super.key,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DesignSystemEmptyState(
      icon: icon,
      title: message,
    );
  }
}
