import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/journal/helpers.dart';
import 'package:lotti/widgets/journal/text_viewer_widget.dart';

class HabitSummary extends StatelessWidget {
  HabitSummary(
    this.habitCompletion, {
    this.showChart = true,
    this.paddingLeft = 0,
    super.key,
  });

  final JournalDb _db = getIt<JournalDb>();
  final HabitCompletionEntry habitCompletion;
  final bool showChart;
  final double paddingLeft;

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
              EntryTextWidget(
                'Habit completed: ${habitDefinition.name}',
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 5),
              if (habitCompletion.entryText?.plainText != null && !showChart)
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
