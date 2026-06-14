import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// "Pick one of N" time-span selector rendered as design-system pills
/// (the same idiom the Insights dashboard uses) rather than a default-Material
/// `SegmentedButton`, so it matches the polished selectors elsewhere.
class TimeSpanSegmentedControl extends StatelessWidget {
  const TimeSpanSegmentedControl({
    required this.timeSpanDays,
    required this.onValueChanged,
    this.segments = const [30, 90, 180, 365],
    super.key,
  });

  final int timeSpanDays;
  final void Function(int) onValueChanged;
  final List<int> segments;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final shortLabels = MediaQuery.sizeOf(context).width < 450;

    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      alignment: WrapAlignment.center,
      children: [
        for (final days in segments)
          _TimeSpanPill(
            label: shortLabels ? '${days}d' : '$days days',
            active: days == timeSpanDays,
            onTap: () => onValueChanged(days),
          ),
      ],
    );
  }
}

class _TimeSpanPill extends StatelessWidget {
  const _TimeSpanPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.s);
    final foreground = active
        ? tokens.colors.text.highEmphasis
        : tokens.colors.text.mediumEmphasis;

    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? tokens.colors.surface.selected : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          hoverColor: tokens.colors.surface.hover,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: active
                    ? tokens.colors.decorative.level02
                    : tokens.colors.decorative.level01,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step4,
                vertical: tokens.spacing.step2,
              ),
              child: Text(
                label,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: foreground,
                  fontWeight: active ? tokens.typography.weight.semiBold : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
