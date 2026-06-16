import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_calendar_picker.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/utils/disabled_overlay.dart';

enum DesignSystemCalendarDateCardVisualState {
  idle,
  hover,
}

/// A compact two-line date card (weekday over day number) used by the
/// horizontal date strip of the design-system calendar pickers.
///
/// Renders a [DesignSystemCalendarDateCardVisualState] (idle/hover) and a
/// distinct selected treatment, derives all colors and geometry from design
/// tokens via [CalendarPickerGeometry], and dims itself when [onPressed] is
/// null. Pass [forcedState] to pin a visual state for showcases/tests.
class DesignSystemCalendarDateCard extends StatefulWidget {
  const DesignSystemCalendarDateCard({
    required this.weekdayLabel,
    required this.dayLabel,
    required this.selected,
    required this.onPressed,
    this.semanticsLabel,
    this.forcedState,
    super.key,
  }) : assert(
         weekdayLabel != '' || semanticsLabel != null,
         'Provide weekdayLabel or semanticsLabel for accessibility.',
       );

  final String weekdayLabel;
  final String dayLabel;
  final bool selected;
  final VoidCallback? onPressed;
  final String? semanticsLabel;
  final DesignSystemCalendarDateCardVisualState? forcedState;

  @override
  State<DesignSystemCalendarDateCard> createState() =>
      _DesignSystemCalendarDateCardState();
}

class _DesignSystemCalendarDateCardState
    extends State<DesignSystemCalendarDateCard> {
  bool _hovered = false;

  @override
  void didUpdateWidget(covariant DesignSystemCalendarDateCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final interactionModeChanged =
        oldWidget.forcedState != widget.forcedState ||
        oldWidget.selected != widget.selected ||
        (oldWidget.onPressed == null) != (widget.onPressed == null);

    if (interactionModeChanged) {
      _hovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final geometry = CalendarPickerGeometry.fromTokens(tokens);
    final enabled = widget.onPressed != null;
    final visualState = _resolveVisualState(enabled);
    final styleSpec = _CalendarDateCardStyleSpec.fromTokens(
      tokens: tokens,
      selected: widget.selected,
      visualState: visualState,
    );

    final card = Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label:
          widget.semanticsLabel ?? '${widget.weekdayLabel} ${widget.dayLabel}',
      child: MouseRegion(
        onEnter: widget.forcedState == null && enabled && !widget.selected
            ? (_) => setState(() => _hovered = true)
            : null,
        onExit: widget.forcedState == null && enabled && !widget.selected
            ? (_) => setState(() => _hovered = false)
            : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: styleSpec.backgroundColor,
              borderRadius: BorderRadius.circular(tokens.radii.l),
              border: styleSpec.borderColor == null
                  ? null
                  : Border.all(color: styleSpec.borderColor!),
            ),
            child: SizedBox(
              width: geometry.dateCardWidth,
              height: geometry.dateCardHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step2,
                  vertical: tokens.spacing.step2,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.weekdayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: styleSpec.weekdayColor,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.step3),
                    Text(
                      widget.dayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(color: styleSpec.dayColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return card.withDisabledOpacity(
      enabled: enabled,
      disabledOpacity: tokens.colors.text.lowEmphasis.a,
    );
  }

  DesignSystemCalendarDateCardVisualState _resolveVisualState(bool enabled) {
    if (!enabled || widget.selected) {
      return DesignSystemCalendarDateCardVisualState.idle;
    }

    if (widget.forcedState != null) {
      return widget.forcedState!;
    }

    if (_hovered) {
      return DesignSystemCalendarDateCardVisualState.hover;
    }

    return DesignSystemCalendarDateCardVisualState.idle;
  }
}

class _CalendarDateCardStyleSpec {
  const _CalendarDateCardStyleSpec({
    required this.backgroundColor,
    required this.weekdayColor,
    required this.dayColor,
    this.borderColor,
  });

  factory _CalendarDateCardStyleSpec.fromTokens({
    required DsTokens tokens,
    required bool selected,
    required DesignSystemCalendarDateCardVisualState visualState,
  }) {
    if (selected) {
      return _CalendarDateCardStyleSpec(
        backgroundColor: tokens.colors.surface.selected,
        weekdayColor: tokens.colors.interactive.enabled,
        dayColor: tokens.colors.interactive.enabled,
        borderColor: tokens.colors.interactive.enabled,
      );
    }

    return _CalendarDateCardStyleSpec(
      backgroundColor:
          visualState == DesignSystemCalendarDateCardVisualState.hover
          ? tokens.colors.background.level02
          : null,
      weekdayColor: tokens.colors.text.lowEmphasis,
      dayColor: tokens.colors.text.mediumEmphasis,
    );
  }

  final Color? backgroundColor;
  final Color weekdayColor;
  final Color dayColor;
  final Color? borderColor;
}
