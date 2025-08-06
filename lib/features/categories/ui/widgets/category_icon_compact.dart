import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';

/// A compact widget for displaying category icons in constrained spaces like journals.
/// 
/// Unlike CategoryIconDisplay, this widget:
/// - Never shows borders
/// - Uses consistent sizing from CategoryIconConstants
/// - Can take a category ID directly (like CategoryColorIcon)
/// - Optimized for inline display in lists and cards
class CategoryIconCompact extends StatelessWidget {
  const CategoryIconCompact(
    this.categoryId, {
    super.key,
    this.size = CategoryIconConstants.iconSizeSmall,
  });

  /// The category ID to display an icon for
  final String? categoryId;
  
  /// The size of the icon display (both width and height)
  final double size;

  @override
  Widget build(BuildContext context) {
    final category = getIt<EntitiesCacheService>().getCategoryById(categoryId);
    
    if (category == null) {
      return _buildFallbackIcon(context);
    }

    return _CategoryIconRenderer(
      category: category,
      size: size,
    );
  }

  /// Builds fallback icon when category is not found
  Widget _buildFallbackIcon(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.outline.withAlpha(
          CategoryIconConstants.fallbackIconAlpha.toInt(),
        ),
      ),
      child: Icon(
        Icons.category_outlined,
        size: size * CategoryIconConstants.fallbackIconSizeMultiplier,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

/// Widget that displays category icon from a CategoryDefinition object.
/// 
/// This is similar to CategoryIconCompact but takes the full CategoryDefinition
/// instead of just the ID, useful when you already have the category object.
class CategoryIconCompactFromDefinition extends StatelessWidget {
  const CategoryIconCompactFromDefinition(
    this.category, {
    super.key,
    this.size = CategoryIconConstants.iconSizeSmall,
  });

  /// The category to display an icon for
  final CategoryDefinition category;
  
  /// The size of the icon display (both width and height)
  final double size;

  @override
  Widget build(BuildContext context) {
    return _CategoryIconRenderer(
      category: category,
      size: size,
    );
  }
}

/// Shared widget for rendering category icons to eliminate code duplication.
/// 
/// This widget handles the common rendering logic for both CategoryIconCompact
/// and CategoryIconCompactFromDefinition widgets.
class _CategoryIconRenderer extends StatelessWidget {
  const _CategoryIconRenderer({
    required this.category,
    required this.size,
  });

  /// The category to display an icon for
  final CategoryDefinition category;
  
  /// The size of the icon display (both width and height)
  final double size;

  @override
  Widget build(BuildContext context) {
    final categoryColor = colorFromCssHex(
      category.color,
      substitute: Theme.of(context).colorScheme.primary,
    );

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: category.icon != null
            ? Icon(
                category.icon!.iconData,
                color: categoryColor,
                size: size * CategoryIconConstants.iconSizeMultiplier,
              )
            : _buildTextFallback(categoryColor, category.name),
      ),
    );
  }

  /// Builds text fallback when no icon is set
  Widget _buildTextFallback(Color categoryColor, String categoryName) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: categoryColor,
      ),
      child: Center(
        child: Text(
          categoryName.isNotEmpty 
              ? categoryName[0].toUpperCase() 
              : CategoryIconStrings.fallbackCharacter,
          style: TextStyle(
            color: categoryColor.computeLuminance() > CategoryIconConstants.luminanceThreshold 
                ? Colors.black 
                : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * CategoryIconConstants.textSizeMultiplier,
          ),
        ),
      ),
    );
  }
}
