import 'package:flutter/material.dart';
import 'package:lotti/features/categories/ui/widgets/categories_type_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

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
