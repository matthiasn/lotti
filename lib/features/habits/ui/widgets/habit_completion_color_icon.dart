import 'package:flutter/material.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// Renders the category colour swatch for a habit.
///
/// Resolves [habitId] to its `HabitDefinition` via `EntitiesCacheService` and
/// delegates to `CategoryColorIcon` using the habit's `categoryId`. Falls back
/// to the uncategorised swatch when the habit or its category is unknown.
class HabitCompletionColorIcon extends StatelessWidget {
  const HabitCompletionColorIcon(
    this.habitId, {
    this.size = 50.0,
    super.key,
  });

  final String? habitId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final habitDefinition = getIt<EntitiesCacheService>().getHabitById(habitId);

    return CategoryColorIcon(
      habitDefinition?.categoryId,
      size: size,
    );
  }
}
