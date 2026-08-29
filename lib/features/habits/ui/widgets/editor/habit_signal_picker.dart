import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/model/habit_form_mapping.dart';
import 'package:lotti/features/habits/ui/widgets/editor/habit_signal_presentation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Every signal a habit can watch — measurables, health data types,
/// imported workout types — searchable, multi-select, open until Done.
///
/// Each toggle reaches the parent at once but the sheet renders from its
/// own mirror, because a modal does not rebuild with the page behind it.
class HabitSignalPicker extends StatefulWidget {
  const HabitSignalPicker({
    required this.measurables,
    required this.workoutTypes,
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final List<MeasurableDataType> measurables;
  final List<String> workoutTypes;
  final Set<(HabitSignalKind, String)> selected;
  final void Function(HabitSignalKind kind, String id, {required bool selected})
  onToggle;

  @override
  State<HabitSignalPicker> createState() => _HabitSignalPickerState();
}

class _HabitSignalPickerState extends State<HabitSignalPicker> {
  final _search = TextEditingController();
  var _query = '';
  late final Set<(HabitSignalKind, String)> _selected = {...widget.selected};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(String text) =>
      _query.isEmpty || text.toLowerCase().contains(_query);

  void _toggle(HabitSignalKind kind, String id) {
    final key = (kind, id);
    final selected = !_selected.contains(key);
    setState(() => selected ? _selected.add(key) : _selected.remove(key));
    widget.onToggle(kind, id, selected: selected);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // A choice measurable is found by any of its choices' titles, the way a
    // numeric one is found by its unit.
    final measurables = widget.measurables.where(
      (m) =>
          _matches(m.displayName) ||
          _matches(m.unitName) ||
          m.activeChoices.any((choice) => _matches(choice.title)),
    );
    final health = [
      for (final key in evaluableHealthDataTypes)
        (key: key, name: habitHealthTypeName(messages, key)),
    ].where((e) => _matches(e.name));
    final workouts = widget.workoutTypes.where(_matches);
    final empty = measurables.isEmpty && health.isEmpty && workouts.isEmpty;

    Widget section(String title) => Padding(
      padding: EdgeInsets.only(
        top: tokens.spacing.step4,
        bottom: tokens.spacing.step2,
      ),
      child: Text(
        title,
        style: tokens.typography.styles.others.overline.copyWith(
          color: tokens.colors.text.lowEmphasis,
        ),
      ),
    );

    Widget row(HabitSignalKind kind, String id, String title, String? sub) =>
        DesignSystemSelectionRow(
          key: ValueKey('habit-signal-option-${kind.name}-$id'),
          title: title,
          subtitle: sub,
          leading: Icon(kind.icon, size: IconSizes.m),
          type: DesignSystemSelectionRowType.multiSelect,
          selected: _selected.contains((kind, id)),
          onTap: () => _toggle(kind, id),
        );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              messages.habitEditorPickerTitle,
              style: tokens.typography.styles.heading.heading3,
            ),
            SizedBox(height: tokens.spacing.step3),
            DesignSystemTextInput(
              key: const ValueKey('habit-signal-picker-search'),
              controller: _search,
              hintText: messages.habitEditorPickerSearchHint,
              leadingIcon: LottiIcons.search,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (empty)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: tokens.spacing.step5,
                      ),
                      child: Text(
                        messages.habitEditorPickerEmpty,
                        style: tokens.typography.styles.body.bodyMedium
                            .copyWith(color: tokens.colors.text.mediumEmphasis),
                      ),
                    ),
                  if (measurables.isNotEmpty)
                    section(messages.habitEditorPickerMeasurables),
                  for (final m in measurables)
                    row(
                      HabitSignalKind.measurable,
                      m.id,
                      m.displayName,
                      habitMeasurableSubtitle(m),
                    ),
                  if (health.isNotEmpty)
                    section(messages.habitEditorPickerHealth),
                  for (final e in health)
                    row(HabitSignalKind.health, e.key, e.name, null),
                  if (workouts.isNotEmpty)
                    section(messages.habitEditorPickerWorkouts),
                  for (final w in workouts)
                    row(HabitSignalKind.workout, w, w, null),
                ],
              ),
            ),
            SizedBox(height: tokens.spacing.step4),
            DesignSystemButton(
              key: const ValueKey('habit-signal-picker-done'),
              label: messages.doneButton,
              onPressed: () => Navigator.of(context).pop(),
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
