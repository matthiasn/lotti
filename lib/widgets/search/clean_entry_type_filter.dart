import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/clean_filter_chip.dart';
import 'package:lotti/widgets/modal/clean_filter_section.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:quiver/collection.dart';

class CleanEntryTypeFilter extends StatelessWidget {
  const CleanEntryTypeFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        // Split entry types into two groups for better organization
        final primaryTypes = entryTypeConfigs.where((c) => 
          ['Task', 'JournalEntry', 'JournalEvent', 'JournalAudio', 'JournalImage'].contains(c.type)
        ).toList();
        
        final secondaryTypes = entryTypeConfigs.where((c) => 
          !primaryTypes.any((p) => p.type == c.type)
        ).toList();

        return Column(
          children: [
            CleanFilterSection(
              title: 'Entry Types',
              subtitle: 'Filter by entry type',
              children: [
                ...primaryTypes.map((config) => CleanEntryTypeChip(
                  entryType: config.type,
                  icon: config.icon,
                  label: config.label,
                )),
                const CleanEntryTypeAllChip(),
              ],
            ),
            if (secondaryTypes.isNotEmpty)
              CleanFilterSection(
                title: 'Specialized Types',
                useGrid: true,
                crossAxisCount: 3,
                children: secondaryTypes.map((config) => CleanEntryTypeChip(
                  entryType: config.type,
                  icon: config.icon,
                  label: config.label,
                  compact: true,
                )).toList(),
              ),
          ],
        );
      },
    );
  }
}

class CleanEntryTypeChip extends StatelessWidget {
  const CleanEntryTypeChip({
    required this.entryType,
    required this.icon,
    required this.label,
    this.compact = false,
    super.key,
  });

  final String entryType;
  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();
        final isSelected = snapshot.selectedEntryTypes.contains(entryType);

        return CleanFilterChip(
          label: label,
          icon: icon,
          isSelected: isSelected,
          onTap: () => cubit.toggleSelectedEntryTypes(entryType),
          onLongPress: () => cubit.selectSingleEntryType(entryType),
          selectedColor: getEntryTypeColor(entryType, context),
          compact: compact,
        );
      },
    );
  }
}

class CleanEntryTypeAllChip extends StatelessWidget {
  const CleanEntryTypeAllChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();
        final isSelected = setsEqual(
          snapshot.selectedEntryTypes.toSet(),
          entryTypeConfigs.map((c) => c.type).toSet(),
        );

        return CleanFilterChip(
          label: 'All',
          icon: Icons.select_all,
          isSelected: isSelected,
          onTap: () {
            if (isSelected) {
              cubit.clearSelectedEntryTypes();
            } else {
              cubit.selectAllEntryTypes();
            }
          },
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
    icon: Icons.task_alt,
  ),
  const EntryTypeConfig(
    type: 'JournalEntry',
    label: 'Text',
    icon: Icons.text_fields,
  ),
  const EntryTypeConfig(
    type: 'JournalEvent',
    label: 'Event',
    icon: Icons.event,
  ),
  const EntryTypeConfig(
    type: 'JournalAudio',
    label: 'Audio',
    icon: Icons.mic,
  ),
  const EntryTypeConfig(
    type: 'JournalImage',
    label: 'Photo',
    icon: Icons.photo_camera,
  ),
  const EntryTypeConfig(
    type: 'MeasurementEntry',
    label: 'Measured',
    icon: Icons.straighten,
  ),
  const EntryTypeConfig(
    type: 'SurveyEntry',
    label: 'Survey',
    icon: Icons.quiz,
  ),
  const EntryTypeConfig(
    type: 'WorkoutEntry',
    label: 'Workout',
    icon: Icons.fitness_center,
  ),
  const EntryTypeConfig(
    type: 'HabitCompletionEntry',
    label: 'Habit',
    icon: Icons.check_circle_outline,
  ),
  const EntryTypeConfig(
    type: 'QuantitativeEntry',
    label: 'Health',
    icon: Icons.favorite,
  ),
  const EntryTypeConfig(
    type: 'Checklist',
    label: 'Checklist',
    icon: Icons.checklist,
  ),
  const EntryTypeConfig(
    type: 'ChecklistItem',
    label: 'ChecklistItem',
    icon: Icons.check_box,
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
