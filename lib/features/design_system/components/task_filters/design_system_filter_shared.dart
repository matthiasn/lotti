import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Strips a trailing colon and any whitespace before it from a label string.
String stripTrailingColon(String value) {
  return value.endsWith(':')
      ? value.substring(0, value.length - 1).trimRight()
      : value;
}

/// Full-width boolean filter row used by compact filter and sort sheets.
///
/// The entire row is one hover, focus, tap, and semantics target. The trailing
/// toggle is visual-only, avoiding the cramped inset-card treatment and a
/// duplicate focus stop.
class DesignSystemFilterToggleRow extends StatelessWidget {
  const DesignSystemFilterToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      button: true,
      toggled: value,
      label: label,
      onTap: () => onChanged(!value),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.s),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step4,
              vertical: tokens.spacing.step3,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
                ExcludeFocus(
                  child: IgnorePointer(
                    child: DesignSystemToggle(
                      value: value,
                      semanticsLabel: label,
                      onChanged: onChanged,
                    ),
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

/// Accessibility role for a compact filter choice.
enum DesignSystemFilterChoiceRole {
  /// One choice in a mutually exclusive group, such as sort order.
  singleSelect,

  /// An independently toggled choice, such as priority or entry type.
  multiSelect,

  /// A compact command that opens another filter surface.
  action,
}

/// Compact token-backed choice used by inline filter sections.
///
/// Selection remains visually selected while hovered. Hover, focus, and press
/// states are immediate, while a selection change uses the established 400 ms
/// coordinated transition. Every variant keeps a 48 logical-pixel minimum hit
/// target and exposes its selected/checked role to assistive technology.
class DesignSystemFilterChoicePill extends StatefulWidget {
  const DesignSystemFilterChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.role,
    this.onLongPress,
    this.leading,
    this.semanticsLabel,
    this.semanticHint,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final DesignSystemFilterChoiceRole role;
  final VoidCallback? onLongPress;
  final Widget? leading;
  final String? semanticsLabel;
  final String? semanticHint;

  static const Duration animationDuration = MotionDurations.medium4;

  @override
  State<DesignSystemFilterChoicePill> createState() =>
      _DesignSystemFilterChoicePillState();
}

class _DesignSystemFilterChoicePillState
    extends State<DesignSystemFilterChoicePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _selectionController;
  late final CurvedAnimation _selectionProgress;
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _selectionController = AnimationController(
      vsync: this,
      duration: DesignSystemFilterChoicePill.animationDuration,
      value: widget.selected ? 1 : 0,
    );
    _selectionProgress = CurvedAnimation(
      parent: _selectionController,
      curve: MotionCurves.standard,
    );
  }

  @override
  void didUpdateWidget(covariant DesignSystemFilterChoicePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      if (widget.selected) {
        _selectionController.forward();
      } else {
        _selectionController.reverse();
      }
    }
    if ((oldWidget.onTap == null) != (widget.onTap == null)) {
      _hovered = false;
      _focused = false;
      _pressed = false;
    }
  }

  @override
  void dispose() {
    _selectionProgress.dispose();
    _selectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final enabled = widget.onTap != null;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: enabled,
      label: widget.semanticsLabel ?? widget.label,
      hint: widget.semanticHint,
      selected: widget.role == DesignSystemFilterChoiceRole.singleSelect
          ? widget.selected
          : null,
      checked: widget.role == DesignSystemFilterChoiceRole.multiSelect
          ? widget.selected
          : null,
      inMutuallyExclusiveGroup:
          widget.role == DesignSystemFilterChoiceRole.singleSelect,
      onTap: widget.onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: spacing.step9),
        child: Material(
          color: Colors.transparent,
          child: AnimatedBuilder(
            animation: _selectionProgress,
            builder: (context, child) {
              final selectedFill = Color.lerp(
                Colors.transparent,
                tokens.colors.surface.selected,
                _selectionProgress.value,
              )!;
              final interactionFill = _pressed || _focused
                  ? tokens.colors.surface.focusPressed
                  : _hovered
                  ? tokens.colors.surface.hover
                  : Colors.transparent;
              final fill = widget.selected ? selectedFill : interactionFill;
              final outline = _focused || widget.selected
                  ? tokens.colors.interactive.enabled
                  : tokens.colors.decorative.level01;

              return Ink(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: radius,
                  border: Border.all(color: outline),
                ),
                child: InkWell(
                  excludeFromSemantics: true,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  borderRadius: radius,
                  onTap: widget.onTap,
                  onLongPress: widget.onLongPress,
                  onHover: enabled
                      ? (value) => setState(() => _hovered = value)
                      : null,
                  onFocusChange: enabled
                      ? (value) => setState(() => _focused = value)
                      : null,
                  onHighlightChanged: enabled
                      ? (value) => setState(() => _pressed = value)
                      : null,
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.step4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.leading != null) ...[
                    widget.leading!,
                    SizedBox(width: spacing.step2),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(color: tokens.colors.text.highEmphasis),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
