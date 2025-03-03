import 'package:flutter/material.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';

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
