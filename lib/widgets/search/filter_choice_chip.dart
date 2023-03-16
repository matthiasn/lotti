import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

const horizontalChipMargin = 2.0;

class FilterChoiceChip extends StatelessWidget {
  const FilterChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    super.key,
  });

  final String label;
  final bool isSelected;
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
            label: Text(
              label,
              style: choiceChipTextStyle(isSelected: isSelected),
            ),
            visualDensity: VisualDensity.compact,
            backgroundColor: isSelected
                ? styleConfig().selectedChoiceChipColor
                : styleConfig().unselectedChoiceChipColor.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}
