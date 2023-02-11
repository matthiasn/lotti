import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

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
    );
  }
}
