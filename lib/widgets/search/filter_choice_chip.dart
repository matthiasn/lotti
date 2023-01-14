import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

class FilterChoiceChip extends StatelessWidget {
  const FilterChoiceChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(
            color: isSelected
                ? styleConfig().selectedChoiceChipColor
                : styleConfig().unselectedChoiceChipColor.withOpacity(0.7),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 5,
                horizontal: 15,
              ),
              child: Text(
                label,
                style: choiceChipTextStyle(isSelected: isSelected),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
