import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

const horizontalChipMargin = 2.0;

class FilterChoiceChip extends StatelessWidget {
  const FilterChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.selectedColor,
    this.onLongPress,
    super.key,
  });

  final String label;
  final bool isSelected;
  final Color? selectedColor;
  final void Function() onTap;
  final void Function()? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: horizontalChipMargin,
          ),
          child: Chip(
            side: BorderSide(
              color: isSelected
                  ? selectedColor ?? Colors.grey
                  : Theme.of(context).colorScheme.secondary,
            ),
            label: Text(
              label,
              style: choiceChipTextStyle(
                themeData: Theme.of(context),
                isSelected: isSelected,
              ),
            ),
            visualDensity: VisualDensity.compact,
            backgroundColor: isSelected
                ? selectedColor ?? Theme.of(context).colorScheme.secondary
                : null,
          ),
        ),
      ),
    );
  }
}
