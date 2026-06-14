import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// One option of a [DsSegmentedToggle].
class DsSegment<T> {
  const DsSegment(this.value, this.label);

  final T value;
  final String label;
}

/// Pill-shaped segmented control for switching between mutually exclusive
/// views or modes. The selected segment carries a teal-tinted fill and a teal
/// semibold label; the rest stay quiet medium-emphasis.
///
/// Each segment reserves its selected (bold) width via an invisible ghost, so
/// toggling never changes the control's width — callers may measure it for
/// layout, and the row never jumps when a segment is tapped. Shared by the
/// Daily OS plan view switch and the Time Analysis chart-mode toggle so both
/// speak one visual language.
class DsSegmentedToggle<T> extends StatelessWidget {
  const DsSegmentedToggle({
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.expand = false,
    super.key,
  });

  final List<DsSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// When true, segments share the parent's width equally and the control
  /// fills it (`MainAxisSize.max`), with tighter per-segment padding. Use for
  /// controls with more segments than fit at natural width (e.g. a 7-step
  /// speed picker); the control must be given a bounded width (e.g. inside a
  /// stretch column). Defaults to false — the shrink-wrap behavior the 2–3
  /// mode switches use, where each segment hugs its label.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final segment in segments)
            if (expand)
              Expanded(
                child: _DsSegmentItem(
                  label: segment.label,
                  isSelected: segment.value == selected,
                  onTap: () => onChanged(segment.value),
                  dense: true,
                ),
              )
            else
              _DsSegmentItem(
                label: segment.label,
                isSelected: segment.value == selected,
                onTap: () => onChanged(segment.value),
              ),
        ],
      ),
    );
  }
}

class _DsSegmentItem extends StatelessWidget {
  const _DsSegmentItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.dense = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  /// Tighter horizontal padding for fill-width (`expand`) toggles, where many
  /// equal-width segments leave little room per label.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final selectedStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: teal,
      fontWeight: FontWeight.w600,
    );
    final unselectedStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
      fontWeight: FontWeight.w500,
    );
    // Material + InkWell + Semantics (the codebase's button pattern) so each
    // segment is Tab-focusable, Enter/Space-activatable, and announced as a
    // selected/unselected button — GestureDetector alone gave none of that.
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.symmetric(
              horizontal: dense ? tokens.spacing.step2 : tokens.spacing.step4,
              vertical: tokens.spacing.step2,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? teal.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Invisible ghost at the selected weight reserves the width so
                // the control's size never changes with the selection (a bold
                // label is wider) — callers can measure it and the row won't
                // jump on tap. Hidden from semantics so the label isn't read
                // twice.
                ExcludeSemantics(
                  child: Opacity(
                    opacity: 0,
                    child: Text(
                      label,
                      style: selectedStyle,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
                Text(
                  label,
                  style: isSelected ? selectedStyle : unselectedStyle,
                  maxLines: 1,
                  softWrap: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
