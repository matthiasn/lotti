import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

abstract final class DesignSystemFilterMetrics {
  static const frameWidth = 402.0;
  static const frameRadius = 32.0;
  static const handleWidth = 40.0;
  static const handleHeight = 4.0;
  static const actionRadius = 26.0;

  /// Sticky-footer action button height from the Figma "Apply filter"
  /// frame (115×56 / 159×56). The action bar's slot constraints and the
  /// button's own minimum height are pinned to this value so the
  /// painted pill, the InkWell hit area, and the slot all agree —
  /// previously they disagreed (slot 56, inner box 44) which under the
  /// glass-blur footer made the non-highlighted pills paint at one box
  /// while the centered text sat in another.
  static const actionMinHeight = 56.0;
}

/// Strips a trailing colon and any whitespace before it from a label string.
///
/// Some locales append a colon to field labels (e.g. "Status:" or "Statut :").
/// Filter headers display the bare word, so this helper removes the suffix.
String stripTrailingColon(String value) {
  return value.endsWith(':')
      ? value.substring(0, value.length - 1).trimRight()
      : value;
}

/// The resolved color set for the task-filter sheet and its selection modals.
///
/// Bundles every surface/text/pill/accent/priority color the filter UI needs in
/// one place. Build it from the active design tokens via
/// [DesignSystemFilterPalette.fromTokens], which derives a light or dark variant
/// from the current background luminance (mixing in a few sheet-specific values
/// that have no exported token yet).
@immutable
class DesignSystemFilterPalette {
  const DesignSystemFilterPalette({
    required this.sheetBackground,
    required this.handleColor,
    required this.primaryText,
    required this.secondaryText,
    required this.pillFill,
    required this.selectedPillBackground,
    required this.fieldBackground,
    required this.fieldOutline,
    required this.dismissFill,
    required this.dismissIcon,
    required this.dividerColor,
    required this.accent,
    required this.accentText,
    required this.applyBadgeFill,
    required this.priorityP0,
    required this.priorityP1,
    required this.priorityP2,
    required this.priorityP3,
    required this.glassFooterOverlayStart,
    required this.glassFooterOverlayEnd,
  });

  factory DesignSystemFilterPalette.fromTokens(DsTokens tokens) {
    final isDark = tokens.colors.background.level01.computeLuminance() < 0.5;

    if (isDark) {
      return DesignSystemFilterPalette(
        sheetBackground: const Color(0xFF1C1C1C),
        handleColor: tokens.colors.decorative.level02,
        primaryText: tokens.colors.text.highEmphasis,
        secondaryText: tokens.colors.text.mediumEmphasis,
        pillFill: const Color(0xFF2C2C2C),
        selectedPillBackground: const Color(0xFF253A36),
        fieldBackground: const Color(0xFF1C1C1C),
        fieldOutline: const Color(0xFF3A3A3A),
        dismissFill: const Color(0xFFCFCFCF),
        dismissIcon: const Color(0xFF373737),
        dividerColor: const Color(0xFF343434),
        accent: const Color(0xFF5AD5BE),
        accentText: const Color(0xFF0F2620),
        applyBadgeFill: const Color(0xFF8BE2D1),
        priorityP0: const Color(0xFFD65E5C),
        priorityP1: const Color(0xFFFBA337),
        priorityP2: const Color(0xFF4AB6E8),
        priorityP3: const Color(0xFF7AB889),
        // Theme-aware glass scrim: keep the blur visible while capping
        // bright content underneath, e.g. screenshots with large white
        // regions behind a sticky footer.
        glassFooterOverlayStart: tokens.colors.background.level02.withValues(
          alpha: _darkGlassFooterStartAlpha,
        ),
        glassFooterOverlayEnd: tokens.colors.background.level02.withValues(
          alpha: _darkGlassFooterEndAlpha,
        ),
      );
    }

    return DesignSystemFilterPalette(
      sheetBackground: const Color(0xFFFFFCF8),
      handleColor: tokens.colors.decorative.level02,
      primaryText: tokens.colors.text.highEmphasis,
      secondaryText: tokens.colors.text.mediumEmphasis,
      pillFill: const Color(0xFFF0EEE9),
      selectedPillBackground: const Color(0xFFE5F7F2),
      fieldBackground: const Color(0xFFFFFCF8),
      fieldOutline: const Color(0xFFD8D3CC),
      dismissFill: const Color(0xFF707070),
      dismissIcon: const Color(0xFFFFFFFF),
      dividerColor: const Color(0xFFE4DED7),
      accent: const Color(0xFF2CA990),
      accentText: const Color(0xFFFFFFFF),
      applyBadgeFill: const Color(0xFF1E8A74),
      priorityP0: const Color(0xFFD94A44),
      priorityP1: const Color(0xFFF19819),
      priorityP2: const Color(0xFF44AEEF),
      priorityP3: const Color(0xFF6C9E71),
      // Light mode uses the same semantic surface token instead of raw
      // white so the footer remains legible over dark or high-contrast
      // content while still reading as frosted glass.
      glassFooterOverlayStart: tokens.colors.background.level02.withValues(
        alpha: _lightGlassFooterStartAlpha,
      ),
      glassFooterOverlayEnd: tokens.colors.background.level02.withValues(
        alpha: _lightGlassFooterEndAlpha,
      ),
    );
  }

  static const _darkGlassFooterStartAlpha = 0.72;
  static const _darkGlassFooterEndAlpha = 0.9;
  static const _lightGlassFooterStartAlpha = 0.78;
  static const _lightGlassFooterEndAlpha = 0.94;

  final Color sheetBackground;
  final Color handleColor;
  final Color primaryText;
  final Color secondaryText;
  final Color pillFill;
  final Color selectedPillBackground;
  final Color fieldBackground;
  final Color fieldOutline;
  final Color dismissFill;
  final Color dismissIcon;
  final Color dividerColor;
  final Color accent;
  final Color accentText;
  final Color applyBadgeFill;
  final Color priorityP0;
  final Color priorityP1;
  final Color priorityP2;
  final Color priorityP3;

  /// Top stop of the sticky-footer "glass" gradient overlay.
  final Color glassFooterOverlayStart;

  /// Bottom stop of the sticky-footer "glass" gradient overlay.
  final Color glassFooterOverlayEnd;
}

/// A pill-shaped action button used inside the task-filter sheet footer (e.g.
/// "Clear all" / "Apply").
///
/// Styled from a [DesignSystemFilterPalette]; [highlighted] switches it to the
/// accent fill, an optional [counter] shows an applied-filter badge, and taps
/// fire [onTap].
class DesignSystemFilterActionButton extends StatelessWidget {
  const DesignSystemFilterActionButton({
    required this.label,
    required this.palette,
    required this.highlighted,
    required this.textStyle,
    required this.onTap,
    this.counter,
    super.key,
  });

  final String label;
  final DesignSystemFilterPalette palette;
  final bool highlighted;
  final TextStyle textStyle;
  final VoidCallback onTap;
  final int? counter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final radius = BorderRadius.circular(
      DesignSystemFilterMetrics.actionRadius,
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: highlighted ? palette.accent : palette.pillFill,
          borderRadius: radius,
          // Non-highlighted pills carry a 1px border. Their `pillFill`
          // is only ~4% of luminance away from the sheet background, so
          // the border keeps the pill silhouette readable inside the
          // glass footer. The border uses the same divider token as the
          // sheet's hairline divider so the seam reads consistently.
          // Highlighted (Apply) pills are opaque accent — no border
          // needed.
          border: highlighted ? null : Border.all(color: palette.dividerColor),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: DesignSystemFilterMetrics.actionMinHeight,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.step5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle.copyWith(
                        color: highlighted
                            ? palette.accentText
                            : palette.primaryText,
                      ),
                    ),
                  ),
                  if (counter != null) ...[
                    SizedBox(width: spacing.step4 - spacing.step1),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: palette.applyBadgeFill,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$counter',
                          style: tokens.typography.styles.subtitle.subtitle2
                              .copyWith(
                                color: highlighted
                                    ? palette.accentText
                                    : palette.primaryText,
                              ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated exclusive-choice pill rendered inside filter modals (sort
/// option, search mode, etc.). Selected state cross-fades the fill and
/// border using the design-system filter palette so the chip matches the
/// rest of the filter surfaces.
class DesignSystemFilterChoicePill extends StatefulWidget {
  const DesignSystemFilterChoicePill({
    required this.label,
    required this.selected,
    required this.palette,
    required this.textStyle,
    required this.onTap,
    this.onLongPress,
    this.leading,
    super.key,
  });

  final String label;
  final bool selected;
  final DesignSystemFilterPalette palette;
  final TextStyle textStyle;
  final VoidCallback onTap;

  /// Optional long-press handler (e.g. the logbook's "isolate to this entry
  /// type" power-user gesture).
  final VoidCallback? onLongPress;
  final Widget? leading;

  static const Duration animationDuration = Duration(milliseconds: 400);
  static const double borderWidth = 1.5;

  @override
  State<DesignSystemFilterChoicePill> createState() =>
      _DesignSystemFilterChoicePillState();
}

class _DesignSystemFilterChoicePillState
    extends State<DesignSystemFilterChoicePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: DesignSystemFilterChoicePill.animationDuration,
      value: widget.selected ? 1.0 : 0.0,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(covariant DesignSystemFilterChoicePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      if (widget.selected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    final radii = context.designTokens.radii;
    final borderRadius = BorderRadius.circular(radii.badgesPills);

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, child) {
            final t = _progress.value;
            final fillColor = Color.lerp(
              widget.palette.pillFill,
              widget.palette.selectedPillBackground,
              t,
            )!;
            final borderColor = widget.palette.accent.withValues(alpha: t);
            return Ink(
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: borderRadius,
                border: Border.all(
                  color: borderColor,
                  width: DesignSystemFilterChoicePill.borderWidth,
                ),
              ),
              child: InkWell(
                borderRadius: borderRadius,
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                child: child,
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.leading != null
                  ? spacing.step4
                  : spacing.step5,
              vertical: spacing.step3,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  SizedBox(width: spacing.step2),
                ],
                Text(
                  widget.label,
                  style: widget.textStyle.copyWith(
                    color: widget.palette.primaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
