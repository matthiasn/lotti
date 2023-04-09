import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/journal/helpers.dart';
import 'package:lotti/widgets/journal/text_viewer_widget.dart';
import 'package:lotti/widgets/settings/categories/categories_type_card.dart';

class HabitSummary extends StatelessWidget {
  HabitSummary(
    this.habitCompletion, {
    this.paddingLeft = 0,
    this.showIcon = false,
    this.showText = true,
    super.key,
  });

  final JournalDb _db = getIt<JournalDb>();
  final HabitCompletionEntry habitCompletion;
  final double paddingLeft;
  final bool showText;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final data = habitCompletion.data;

    return StreamBuilder<HabitDefinition?>(
      stream: _db.watchHabitById(data.habitId),
      builder: (
        BuildContext context,
        AsyncSnapshot<HabitDefinition?> typeSnapshot,
      ) {
        final habitDefinition = typeSnapshot.data;

        if (habitDefinition == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.only(top: 5, left: paddingLeft),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (showIcon)
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: CategoryColorIcon(
                        habitDefinition.categoryId,
                        size: 30,
                      ),
                    ),
                  EntryTextWidget(
                    'Habit completed: ${habitDefinition.name}',
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              if (habitCompletion.entryText?.plainText != null && showText)
                TextViewerWidget(
                  entryText: habitCompletion.entryText,
                  maxHeight: 120,
                ),
            ],
          ),
        );
      },
    );
  }
}
