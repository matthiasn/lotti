import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modern_filter_chip.dart';
import 'package:lotti/widgets/modal/modern_filter_section.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:quiver/collection.dart';

class ModernEntryTypeFilter extends StatelessWidget {
  const ModernEntryTypeFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        return ModernFilterSection(
          title: 'Entry Types',
          subtitle: 'Filter by entry type',
          children: [
            ...entryTypeConfigs.map((config) => ModernEntryTypeChip(
                  entryType: config.type,
                  icon: config.icon,
                  label: config.label,
                )),
            const ModernEntryTypeAllChip(),
          ],
        );
      },
    );
  }
}

class ModernEntryTypeChip extends StatelessWidget {
  const ModernEntryTypeChip({
    required this.entryType,
    required this.icon,
    required this.label,
    super.key,
  });

  final String entryType;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();
        final isSelected = snapshot.selectedEntryTypes.contains(entryType);

        return ModernFilterChip(
          label: label,
          icon: icon,
          isSelected: isSelected,
          onTap: () => cubit.toggleSelectedEntryTypes(entryType),
          onLongPress: () => cubit.selectSingleEntryType(entryType),
          selectedColor: getEntryTypeColor(entryType, context),
        );
      },
    );
  }
}

class ModernEntryTypeAllChip extends StatelessWidget {
  const ModernEntryTypeAllChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();
        final isSelected = setsEqual(
          snapshot.selectedEntryTypes.toSet(),
          entryTypeConfigs.map((c) => c.type).toSet(),
        );

        return ModernFilterChip(
          label: 'All',
          icon: Icons.select_all_rounded,
          isSelected: isSelected,
          onTap: () {
            if (isSelected) {
              cubit.clearSelectedEntryTypes();
            } else {
              cubit.selectAllEntryTypes();
            }
          },
          selectedColor: context.colorScheme.primary,
        );
      },
    );
  }
}

class EntryTypeConfig {
  const EntryTypeConfig({
    required this.type,
    required this.label,
    required this.icon,
  });

  final String type;
  final String label;
  final IconData icon;
}

final entryTypeConfigs = [
  const EntryTypeConfig(
    type: 'Task',
    label: 'Task',
    icon: Icons.task_alt_rounded,
  ),
  const EntryTypeConfig(
    type: 'JournalEntry',
    label: 'Text',
    icon: Icons.text_fields_rounded,
  ),
  const EntryTypeConfig(
    type: 'JournalEvent',
    label: 'Event',
    icon: Icons.event_rounded,
  ),
  const EntryTypeConfig(
    type: 'JournalAudio',
    label: 'Audio',
    icon: Icons.mic_rounded,
  ),
  const EntryTypeConfig(
    type: 'JournalImage',
    label: 'Photo',
    icon: Icons.photo_camera_rounded,
  ),
  const EntryTypeConfig(
    type: 'MeasurementEntry',
    label: 'Measured',
    icon: Icons.straighten_rounded,
  ),
  const EntryTypeConfig(
    type: 'SurveyEntry',
    label: 'Survey',
    icon: Icons.quiz_rounded,
  ),
  const EntryTypeConfig(
    type: 'WorkoutEntry',
    label: 'Workout',
    icon: Icons.fitness_center_rounded,
  ),
  const EntryTypeConfig(
    type: 'HabitCompletionEntry',
    label: 'Habit',
    icon: Icons.check_circle_outline_rounded,
  ),
  const EntryTypeConfig(
    type: 'QuantitativeEntry',
    label: 'Health',
    icon: Icons.favorite_rounded,
  ),
  const EntryTypeConfig(
    type: 'Checklist',
    label: 'Checklist',
    icon: Icons.checklist_rounded,
  ),
  const EntryTypeConfig(
    type: 'ChecklistItem',
    label: 'ChecklistItem',
    icon: Icons.check_box_rounded,
  ),
  EntryTypeConfig(
    type: 'AiResponse',
    label: 'AI Response',
    icon: MdiIcons.robot,
  ),
];

Color getEntryTypeColor(String entryType, BuildContext context) {
  final colorScheme = context.colorScheme;
  switch (entryType) {
    case 'Task':
      return colorScheme.primary;
    case 'JournalEntry':
      return colorScheme.secondary;
    case 'JournalEvent':
      return const Color(0xFF9C27B0);
    case 'JournalAudio':
      return const Color(0xFF2196F3);
    case 'JournalImage':
      return const Color(0xFF4CAF50);
    case 'MeasurementEntry':
      return const Color(0xFFFF9800);
    case 'SurveyEntry':
      return const Color(0xFF795548);
    case 'WorkoutEntry':
      return const Color(0xFFE91E63);
    case 'HabitCompletionEntry':
      return const Color(0xFF00BCD4);
    case 'QuantitativeEntry':
      return const Color(0xFFF44336);
    case 'Checklist':
      return const Color(0xFF3F51B5);
    case 'ChecklistItem':
      return const Color(0xFF673AB7);
    case 'AiResponse':
      return const Color(0xFF009688);
    default:
      return colorScheme.primary;
  }
}
