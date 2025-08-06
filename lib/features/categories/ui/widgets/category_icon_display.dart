import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/utils/color.dart';

/// Widget for displaying category icons with colored borders.
///
/// This widget displays either a Material Design icon (if the category has an icon selected)
/// or the first letter of the category name as a fallback. The display includes a colored
/// circular border matching the category's color.
///
/// Example:
/// ```dart
/// CategoryIconDisplay(
///   category: myCategory,
///   size: 64.0,
///   showBorder: true,
/// )
/// ```
class CategoryIconDisplay extends StatelessWidget {
  const CategoryIconDisplay({
    required this.category,
    super.key,
    this.showBorder = true,
    this.size = CategoryIconConstants.defaultIconSize,
  });

  /// The category to display an icon for
  final CategoryDefinition category;

  /// The size of the circular icon display (both width and height)
  final double size;

  /// Whether to show the colored border around the icon/text
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final categoryColor = colorFromCssHex(
      category.color,
      substitute: Theme.of(context).colorScheme.primary,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: categoryColor,
                width: CategoryIconConstants.borderWidth,
              )
            : null,
      ),
      child: Center(
        child: category.icon != null
            ? Icon(
                category.icon!.iconData,
                color: categoryColor,
                size: size * CategoryIconConstants.iconSizeMultiplier,
              )
            : Text(
                category.name.isNotEmpty
                    ? category.name[0].toUpperCase()
                    : CategoryIconStrings.fallbackCharacter,
                style: TextStyle(
                  color: categoryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: size * CategoryIconConstants.textSizeMultiplier,
                ),
              ),
      ),
    );
  }
}
