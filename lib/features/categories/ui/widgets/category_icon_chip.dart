import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';

/// The single leading "language" for settings definition list rows.
///
/// Every definitions list (categories, labels, habits, measurables,
/// dashboards) leads its rows with this 36px rounded-square chip so the
/// five pages read as one system instead of five. The chip shows either
/// an [icon] or the first letter of [name] on a solid [background]; when
/// no explicit [foreground] is given it picks white or black from the
/// background brightness — the rule the categories list badge established.
class DefinitionIconChip extends StatelessWidget {
  const DefinitionIconChip({
    required this.background,
    this.icon,
    this.name,
    this.foreground,
    this.size = defaultSize,
    super.key,
  }) : assert(
         icon != null || name != null,
         'Provide an icon or a name for the letter fallback.',
       );

  /// Fill color of the rounded square.
  final Color background;

  /// Glyph rendered centered in the chip; takes precedence over [name].
  final IconData? icon;

  /// Source for the single-letter fallback (first letter, uppercased;
  /// `?` when empty). Used when [icon] is null.
  final String? name;

  /// Foreground for the glyph or letter. When null it is derived from
  /// the [background] brightness (white on dark, black on light).
  final Color? foreground;

  /// Edge length of the square chip.
  final double size;

  /// Shared chip metrics — the categories list badge's established
  /// constants, reused by every definitions list row.
  static const double defaultSize = 36;
  static const double borderRadius = 10;

  /// Glyph and letter scales mirror the categories list badge.
  static const double _iconScale = 0.5;
  static const double _letterScale = 0.4;

  @override
  Widget build(BuildContext context) {
    final isDark =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
    final resolvedForeground =
        foreground ?? (isDark ? Colors.white : Colors.black);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: icon != null
            ? Icon(
                icon,
                color: resolvedForeground,
                size: size * _iconScale,
              )
            : Text(
                name!.isNotEmpty ? name![0].toUpperCase() : '?',
                style: TextStyle(
                  color: resolvedForeground,
                  fontWeight: FontWeight.bold,
                  fontSize: size * _letterScale,
                ),
              ),
      ),
    );
  }
}

/// [DefinitionIconChip] variant for rows that carry a category.
///
/// Renders the category color as the chip background with the category
/// icon (or first-letter fallback) as the glyph. [CategoryIconChip.fromId]
/// resolves the category through [EntitiesCacheService] for rows that only
/// store a category id (habits, dashboards); a null or unresolved id falls
/// back to a neutral chip (`background.level03`) with an [Icons.more_horiz]
/// glyph at `text.lowEmphasis` — deliberately not the shapes glyph used by
/// the empty-state illustration, which would read as a bug.
class CategoryIconChip extends StatelessWidget {
  const CategoryIconChip({
    required CategoryDefinition this.category,
    this.size = DefinitionIconChip.defaultSize,
    super.key,
  }) : categoryId = null;

  const CategoryIconChip.fromId(
    this.categoryId, {
    this.size = DefinitionIconChip.defaultSize,
    super.key,
  }) : category = null;

  /// Category rendered directly; null for the [CategoryIconChip.fromId]
  /// variant.
  final CategoryDefinition? category;

  /// Category id resolved via [EntitiesCacheService] when [category] is
  /// null.
  final String? categoryId;

  /// Edge length of the square chip.
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolved =
        category ?? getIt<EntitiesCacheService>().getCategoryById(categoryId);

    if (resolved == null) {
      final tokens = context.designTokens;
      return DefinitionIconChip(
        background: tokens.colors.background.level03,
        foreground: tokens.colors.text.lowEmphasis,
        icon: Icons.more_horiz,
        size: size,
      );
    }

    return DefinitionIconChip(
      background: colorFromCssHex(
        resolved.color,
        substitute: Theme.of(context).colorScheme.primary,
      ),
      icon: resolved.icon?.iconData,
      name: resolved.name,
      size: size,
    );
  }
}
