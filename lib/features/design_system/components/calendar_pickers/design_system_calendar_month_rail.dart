import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_calendar_picker.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/utils/disabled_overlay.dart';

@immutable
class DesignSystemCalendarMonthRailSection {
  const DesignSystemCalendarMonthRailSection({
    required this.yearLabel,
    required this.items,
  });

  final String yearLabel;
  final List<DesignSystemCalendarMonthRailItem> items;
}

@immutable
class DesignSystemCalendarMonthRailItem {
  const DesignSystemCalendarMonthRailItem({
    required this.label,
    required this.selected,
    this.key,
    this.onPressed,
    this.semanticsLabel,
  });

  final Key? key;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final String? semanticsLabel;
}

class CalendarMonthRail extends StatelessWidget {
  const CalendarMonthRail({
    required this.monthSections,
    super.key,
  });

  final List<DesignSystemCalendarMonthRailSection> monthSections;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final section in monthSections) ...[
                _CalendarYearDivider(label: section.yearLabel),
                for (final item in section.items)
                  _CalendarMonthRailButton(item: item),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarYearDivider extends StatelessWidget {
  const _CalendarYearDivider({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final geometry = CalendarPickerGeometry.fromTokens(tokens);
    final labelColor = tokens.colors.decorative.level02;

    return Padding(
      padding: EdgeInsets.only(
        top: tokens.spacing.step3,
        bottom: tokens.spacing.step2,
      ),
      child: SizedBox(
        width: geometry.railButtonWidth,
        height: tokens.typography.lineHeight.caption,
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.others.overline.copyWith(
              color: labelColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarMonthRailButton extends StatefulWidget {
  const _CalendarMonthRailButton({
    required this.item,
  });

  final DesignSystemCalendarMonthRailItem item;

  @override
  State<_CalendarMonthRailButton> createState() =>
      _CalendarMonthRailButtonState();
}

class _CalendarMonthRailButtonState extends State<_CalendarMonthRailButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final geometry = CalendarPickerGeometry.fromTokens(tokens);
    final enabled = widget.item.onPressed != null;

    final backgroundColor = switch ((widget.item.selected, _hovered)) {
      (true, _) => tokens.colors.surface.hover,
      (false, true) => tokens.colors.surface.enabled,
      (false, false) => null,
    };

    final button = Semantics(
      button: true,
      enabled: enabled,
      selected: widget.item.selected,
      label: widget.item.semanticsLabel ?? widget.item.label,
      child: MouseRegion(
        onEnter: enabled && !widget.item.selected
            ? (_) => setState(() => _hovered = true)
            : null,
        onExit: enabled && !widget.item.selected
            ? (_) => setState(() => _hovered = false)
            : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.item.onPressed,
          child: DecoratedBox(
            key: widget.item.key,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(tokens.radii.l),
            ),
            child: SizedBox(
              width: geometry.railButtonWidth,
              height: geometry.controlHeight,
              child: Center(
                child: Text(
                  widget.item.label,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return button.withDisabledOpacity(
      enabled: enabled,
      disabledOpacity: tokens.colors.text.lowEmphasis.a,
    );
  }
}
