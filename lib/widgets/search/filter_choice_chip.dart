import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/theme.dart';

class FilterChoiceChip extends StatelessWidget {
  const FilterChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.selectedColor,
    this.onLongPress,
    super.key,
  });

  final String label;
  final bool isSelected;
  final Color selectedColor;
  final void Function() onTap;
  final void Function()? onLongPress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Chip(
          side: BorderSide(color: selectedColor),
          // Material's default labelPadding is symmetric(horizontal: step3).
          // Add a step1 nudge on the leading side so the label is visibly
          // offset from the chip's start edge. Directional so RTL locales
          // get the nudge on the right side once they ship.
          labelPadding: EdgeInsetsDirectional.only(
            start: tokens.spacing.step3 + tokens.spacing.step1,
            end: tokens.spacing.step3,
          ),
          label: Text(
            label,
            style:
                choiceChipTextStyle(
                  themeData: Theme.of(context),
                  isSelected: isSelected,
                ).copyWith(
                  color: isSelected
                      ? selectedColor.isLight
                            ? Colors.black
                            : Colors.white
                      : context.colorScheme.onSurface,
                ),
          ),
          visualDensity: VisualDensity.compact,
          backgroundColor: isSelected ? selectedColor : null,
        ),
      ),
    );
  }
}
