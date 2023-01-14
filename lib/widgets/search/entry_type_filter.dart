import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:quiver/collection.dart';

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
              const EntryTypeAllChip(),
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
        final isSelected = snapshot.selectedEntryTypes.contains(entryType);

        return GestureDetector(
          onTap: () {
            cubit.toggleSelectedEntryTypes(entryType);
            HapticFeedback.heavyImpact();
          },
          onLongPress: () {
            cubit.setSingleEntryType(entryType);
            HapticFeedback.heavyImpact();
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: isSelected
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
                      color: isSelected
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

class EntryTypeAllChip extends StatelessWidget {
  const EntryTypeAllChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();
        final isSelected =
            setsEqual(snapshot.selectedEntryTypes.toSet(), entryTypes.toSet());

        return GestureDetector(
          onTap: () {
            if (isSelected) {
              cubit.clearSelectedEntryTypes();
            } else {
              cubit.selectAllEntryTypes();
            }
            HapticFeedback.heavyImpact();
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: isSelected
                    ? styleConfig().selectedChoiceChipColor
                    : styleConfig().unselectedChoiceChipColor.withOpacity(0.7),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 15,
                  ),
                  child: Text(
                    'All',
                    style: TextStyle(
                      fontFamily: 'Oswald',
                      fontSize: fontSizeMedium,
                      fontWeight: FontWeight.w300,
                      color: isSelected
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
