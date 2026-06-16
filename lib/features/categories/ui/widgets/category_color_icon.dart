import 'package:flutter/material.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';

/// A small rounded-square swatch filled with [color] (corner radius `size/4`).
/// The raw building block behind [CategoryColorIcon] and reused wherever a
/// bare color chip is needed.
class ColorIcon extends StatelessWidget {
  const ColorIcon(
    this.color, {
    this.size = 20.0,
    super.key,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: Container(
        height: size,
        width: size,
        color: color,
      ),
    );
  }
}

/// A [ColorIcon] that resolves its fill from a category id.
///
/// Looks [categoryId] up in [EntitiesCacheService] and draws the category's
/// color. A null/unresolved id falls back to a faint outline swatch. Unlike
/// `CategoryIconCompact` this shows only the color, with no glyph or letter.
class CategoryColorIcon extends StatelessWidget {
  const CategoryColorIcon(
    this.categoryId, {
    this.size = 20.0,
    super.key,
  });

  final String? categoryId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final category = getIt<EntitiesCacheService>().getCategoryById(categoryId);

    return ColorIcon(
      category != null
          ? colorFromCssHex(category.color)
          : context.colorScheme.outline.withAlpha(51),
      size: size,
    );
  }
}
