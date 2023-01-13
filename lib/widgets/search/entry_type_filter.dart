import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/themes/theme.dart';

class EntryTypeFilter extends StatelessWidget {
  const EntryTypeFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: WrapSuper(
            alignment: WrapSuperAlignment.center,
            spacing: 5,
            lineSpacing: 5,
            children: [
              ...entryTypes.map(EntryTypeChip.new),
            ],
          ),
        );
      },
    );
  }
}

class EntryTypeChip extends StatelessWidget {
  const EntryTypeChip(
    this.entryType, {
    super.key,
  });

  final String entryType;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();

        return GestureDetector(
          onTap: () {
            cubit.toggleSelectedEntryTypes(entryType);
            HapticFeedback.heavyImpact();
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: snapshot.selectedEntryTypes.contains(entryType)
                    ? styleConfig().selectedChoiceChipColor
                    : styleConfig().unselectedChoiceChipColor.withOpacity(0.7),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 15,
                  ),
                  child: Text(
                    entryTypeDisplayNames[entryType] ?? '',
                    style: TextStyle(
                      fontFamily: 'Oswald',
                      fontSize: fontSizeMedium,
                      fontWeight: FontWeight.w300,
                      color: snapshot.selectedEntryTypes.contains(entryType)
                          ? styleConfig().selectedChoiceChipTextColor
                          : styleConfig().unselectedChoiceChipTextColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

final entryTypeDisplayNames = {
  'Task': 'Task',
  'JournalEntry': 'Text',
  'JournalAudio': 'Audio',
  'JournalImage': 'Photo',
  'MeasurementEntry': 'Measured',
  'SurveyEntry': 'Survey',
  'WorkoutEntry': 'Workout',
  'HabitCompletionEntry': 'Habit',
  'QuantitativeEntry': 'Health',
};
