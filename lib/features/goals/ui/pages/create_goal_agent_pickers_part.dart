part of 'create_goal_agent_page.dart';

class _DimensionSourcePicker extends StatefulWidget {
  const _DimensionSourcePicker({
    required this.habits,
    required this.habitsFailed,
    required this.measurables,
    required this.categories,
    required this.labels,
    required this.selectedHabitIds,
    required this.selectedMeasurableIds,
    required this.selectedHealthDataTypes,
    required this.selectedCategoryIds,
    required this.selectedLabelIds,
    required this.watchesSteps,
    required this.onStepsChanged,
    required this.onHabitChanged,
    required this.onMeasurableChanged,
    required this.onHealthSelected,
    required this.onHealthRemoved,
    required this.onCategorySelected,
    required this.onCategoryRemoved,
    required this.onLabelSelected,
    required this.onLabelRemoved,
  });

  final List<HabitDefinition> habits;
  final bool habitsFailed;
  final List<MeasurableDataType> measurables;
  final List<CategoryDefinition> categories;
  final List<LabelDefinition> labels;
  final Set<String> selectedHabitIds;
  final Set<String> selectedMeasurableIds;
  final Set<String> selectedHealthDataTypes;
  final Set<String> selectedCategoryIds;
  final Set<String> selectedLabelIds;
  final bool watchesSteps;
  final ValueChanged<bool> onStepsChanged;
  final void Function({required String habitId, required bool selected})
  onHabitChanged;
  final void Function({required String measurableId, required bool selected})
  onMeasurableChanged;
  final ValueChanged<List<String>> onHealthSelected;
  final ValueChanged<String> onHealthRemoved;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onCategoryRemoved;
  final ValueChanged<String> onLabelSelected;
  final ValueChanged<String> onLabelRemoved;

  @override
  State<_DimensionSourcePicker> createState() => _DimensionSourcePickerState();
}

/// The ONE place every watchable signal lives — habits, steps, weight,
/// blood pressure, measurables and tracked time — searchable in plain
/// language, multi-select, and it stays open until Done so composing a goal
/// is one visit, not four.
class _DimensionSourcePickerState extends State<_DimensionSourcePicker> {
  final _search = TextEditingController();
  var _query = '';

  // Local mirrors: the sheet applies every toggle to the parent immediately
  // but renders from its own state, because a modal does not rebuild with
  // the page behind it.
  late final Set<String> _habitIds = {...widget.selectedHabitIds};
  late final Set<String> _measurableIds = {...widget.selectedMeasurableIds};
  late final Set<String> _healthTypes = {...widget.selectedHealthDataTypes};
  late final Set<String> _categoryIds = {...widget.selectedCategoryIds};
  late final Set<String> _labelIds = {...widget.selectedLabelIds};
  late bool _watchesSteps = widget.watchesSteps;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final query = _query.trim().toLowerCase();
    final visibleHabits = widget.habits.where((habit) {
      return query.isEmpty || habit.name.toLowerCase().contains(query);
    }).toList();
    final visible = widget.measurables.where((measurable) {
      return query.isEmpty ||
          measurable.displayName.toLowerCase().contains(query) ||
          measurable.unitName.toLowerCase().contains(query);
    }).toList();
    final visibleCategories = widget.categories.where((category) {
      return query.isEmpty || category.name.toLowerCase().contains(query);
    }).toList();
    final visibleLabels = widget.labels.where((label) {
      return query.isEmpty || label.name.toLowerCase().contains(query);
    }).toList();
    final stepsMatches =
        query.isEmpty ||
        messages.goalCreateStepsTargetLabel.toLowerCase().contains(query) ||
        messages.goalFormStepsSignal.toLowerCase().contains(query);
    final weightMatches =
        query.isEmpty ||
        messages.goalFormHealthWeight.toLowerCase().contains(query) ||
        'kg'.contains(query);
    final bloodPressureMatches =
        query.isEmpty ||
        messages.dashboardHealthBloodPressure.toLowerCase().contains(query) ||
        messages.goalFormHealthBloodPressureSystolic.toLowerCase().contains(
          query,
        ) ||
        messages.goalFormHealthBloodPressureDiastolic.toLowerCase().contains(
          query,
        ) ||
        'mmhg'.contains(query);
    final showsHealth = weightMatches || bloodPressureMatches;
    final bloodPressureTypes = [
      GoalHealthDataTypes.bloodPressureSystolic,
      GoalHealthDataTypes.bloodPressureDiastolic,
    ];
    final weightSelected = _healthTypes.contains(GoalHealthDataTypes.weight);
    // The signal row treats a partial pair as selected; the picker has to
    // agree, or tapping an apparently unchecked source would silently seed
    // a default target for the reading the goal deliberately lacks.
    final bloodPressureSelected = bloodPressureTypes.any(_healthTypes.contains);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              messages.goalFormAddSignal,
              style: tokens.typography.styles.heading.heading3,
            ),
            SizedBox(height: tokens.spacing.step3),
            DesignSystemTextInput(
              controller: _search,
              hintText: context.messages.searchHint,
              leadingIcon: LottiIcons.search,
              onChanged: (value) => setState(() => _query = value),
            ),
            SizedBox(height: tokens.spacing.step3),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (visibleHabits.isNotEmpty ||
                      (query.isEmpty &&
                          (widget.habits.isEmpty || widget.habitsFailed))) ...[
                    Text(
                      messages.goalDimensionHabitSource,
                      style: tokens.typography.styles.subtitle.subtitle2,
                    ),
                    SizedBox(height: tokens.spacing.step2),
                    for (final habit in visibleHabits)
                      DesignSystemSelectionRow(
                        key: ValueKey('goal-form-picker-habit-${habit.id}'),
                        title: habit.name,
                        subtitle: messages.goalFormHabitSignal,
                        titleMaxLines: 2,
                        selected: _habitIds.contains(habit.id),
                        type: DesignSystemSelectionRowType.multiSelect,
                        onTap: () {
                          final selected = !_habitIds.contains(habit.id);
                          setState(() {
                            selected
                                ? _habitIds.add(habit.id)
                                : _habitIds.remove(habit.id);
                          });
                          widget.onHabitChanged(
                            habitId: habit.id,
                            selected: selected,
                          );
                        },
                      ),
                    if (widget.habits.isEmpty && query.isEmpty) ...[
                      Text(
                        widget.habitsFailed
                            ? messages.goalCreateHabitsLoadFailed
                            : messages.goalFormNoHabits,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                      SizedBox(height: tokens.spacing.step2),
                      DesignSystemButton(
                        label: messages.goalFormOpenHabits,
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Habit definitions are CREATED in settings, and the
                          // settings tab is always enabled — the Habits tab is
                          // flag-gated (and has no create affordance), so
                          // routing there strands the wizard on /tasks when
                          // only the unified Goals flag is on.
                          beamToNamed('/settings/habits');
                        },
                        variant: DesignSystemButtonVariant.secondary,
                        fullWidth: true,
                      ),
                    ],
                    SizedBox(height: tokens.spacing.step4),
                  ],
                  if (stepsMatches || showsHealth) ...[
                    Text(
                      messages.goalFormHealthData,
                      style: tokens.typography.styles.subtitle.subtitle2,
                    ),
                    SizedBox(height: tokens.spacing.step2),
                    if (stepsMatches)
                      DesignSystemSelectionRow(
                        key: const ValueKey('goal-form-picker-steps'),
                        title: messages.goalCreateStepsTargetLabel,
                        subtitle: messages.goalFormStepsSignal,
                        selected: _watchesSteps,
                        type: DesignSystemSelectionRowType.multiSelect,
                        onTap: () {
                          final selected = !_watchesSteps;
                          setState(() => _watchesSteps = selected);
                          widget.onStepsChanged(selected);
                        },
                      ),
                    if (weightMatches)
                      DesignSystemSelectionRow(
                        key: const ValueKey(
                          'goal-form-health-source-weight',
                        ),
                        title: messages.goalFormHealthWeight,
                        subtitle: messages.goalFormHealthSource('kg'),
                        selected: weightSelected,
                        type: DesignSystemSelectionRowType.multiSelect,
                        onTap: () {
                          setState(() {
                            weightSelected
                                ? _healthTypes.remove(
                                    GoalHealthDataTypes.weight,
                                  )
                                : _healthTypes.add(GoalHealthDataTypes.weight);
                          });
                          if (weightSelected) {
                            widget.onHealthRemoved(GoalHealthDataTypes.weight);
                          } else {
                            widget.onHealthSelected(
                              const [GoalHealthDataTypes.weight],
                            );
                          }
                        },
                      ),
                    if (bloodPressureMatches)
                      DesignSystemSelectionRow(
                        key: const ValueKey(
                          'goal-form-health-source-blood-pressure',
                        ),
                        title: messages.dashboardHealthBloodPressure,
                        subtitle: messages.goalFormBloodPressureSource,
                        selected: bloodPressureSelected,
                        type: DesignSystemSelectionRowType.multiSelect,
                        onTap: () {
                          setState(() {
                            bloodPressureSelected
                                ? _healthTypes.removeAll(bloodPressureTypes)
                                : _healthTypes.addAll(bloodPressureTypes);
                          });
                          if (bloodPressureSelected) {
                            bloodPressureTypes.forEach(
                              widget.onHealthRemoved,
                            );
                          } else {
                            widget.onHealthSelected(bloodPressureTypes);
                          }
                        },
                      ),
                    SizedBox(height: tokens.spacing.step4),
                  ],
                  if (visibleCategories.isNotEmpty) ...[
                    Text(
                      messages.goalDimensionCategoryTimeSource,
                      style: tokens.typography.styles.subtitle.subtitle2,
                    ),
                    SizedBox(height: tokens.spacing.step2),
                    for (final category in visibleCategories)
                      DesignSystemSelectionRow(
                        key: ValueKey(
                          'goal-form-category-time-source-${category.id}',
                        ),
                        title: category.name,
                        subtitle: messages.goalFormCategoryTimeSource,
                        selected: _categoryIds.contains(category.id),
                        type: DesignSystemSelectionRowType.multiSelect,
                        onTap: () {
                          final selected = !_categoryIds.contains(category.id);
                          setState(() {
                            selected
                                ? _categoryIds.add(category.id)
                                : _categoryIds.remove(category.id);
                          });
                          if (selected) {
                            widget.onCategorySelected(category.id);
                          } else {
                            widget.onCategoryRemoved(category.id);
                          }
                        },
                      ),
                    SizedBox(height: tokens.spacing.step4),
                  ],
                  if (visibleLabels.isNotEmpty) ...[
                    Text(
                      messages.goalDimensionLabelTimeSource,
                      style: tokens.typography.styles.subtitle.subtitle2,
                    ),
                    SizedBox(height: tokens.spacing.step2),
                    for (final label in visibleLabels)
                      DesignSystemSelectionRow(
                        key: ValueKey(
                          'goal-form-label-time-source-${label.id}',
                        ),
                        title: label.name,
                        subtitle: messages.goalFormLabelTimeSource,
                        selected: _labelIds.contains(label.id),
                        type: DesignSystemSelectionRowType.multiSelect,
                        onTap: () {
                          final selected = !_labelIds.contains(label.id);
                          setState(() {
                            selected
                                ? _labelIds.add(label.id)
                                : _labelIds.remove(label.id);
                          });
                          if (selected) {
                            widget.onLabelSelected(label.id);
                          } else {
                            widget.onLabelRemoved(label.id);
                          }
                        },
                      ),
                    SizedBox(height: tokens.spacing.step4),
                  ],
                  Text(
                    messages.goalFormYourMeasurables,
                    style: tokens.typography.styles.subtitle.subtitle2,
                  ),
                  SizedBox(height: tokens.spacing.step2),
                  for (final measurable in visible)
                    DesignSystemSelectionRow(
                      title: measurable.displayName,
                      subtitle: context.messages.goalFormMeasurableSource(
                        measurable.unitName,
                      ),
                      selected: _measurableIds.contains(measurable.id),
                      type: DesignSystemSelectionRowType.multiSelect,
                      onTap: () {
                        final selected = !_measurableIds.contains(
                          measurable.id,
                        );
                        setState(() {
                          selected
                              ? _measurableIds.add(measurable.id)
                              : _measurableIds.remove(measurable.id);
                        });
                        widget.onMeasurableChanged(
                          measurableId: measurable.id,
                          selected: selected,
                        );
                      },
                    ),
                  if (visible.isEmpty && query.isEmpty)
                    DesignSystemButton(
                      label: context.messages.settingsMeasurablesCreateTitle,
                      leadingIcon: LottiIcons.add,
                      variant: DesignSystemButtonVariant.secondary,
                      fullWidth: true,
                      onPressed: () {
                        Navigator.of(context).pop();
                        beamToNamed('/settings/measurables/create');
                      },
                    ),
                ],
              ),
            ),
            SizedBox(height: tokens.spacing.step4),
            DesignSystemButton(
              key: const ValueKey('goal-form-picker-done'),
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

class _CompositeRulePicker extends StatefulWidget {
  const _CompositeRulePicker({
    required this.value,
    required this.requiredSuccesses,
    required this.dimensionCount,
    required this.onChanged,
  });

  final GoalFormCompositeRule value;
  final int requiredSuccesses;
  final int dimensionCount;
  final void Function(GoalFormCompositeRule rule, int requiredSuccesses)
  onChanged;

  @override
  State<_CompositeRulePicker> createState() => _CompositeRulePickerState();
}

/// Chooses how the goal's dimensions combine, and stays open while it does.
///
/// Every tap applies to the page immediately but renders from local mirrors,
/// because a modal does not rebuild with the page behind it. Crucially the
/// at-least stepper only adjusts the count — the sheet dismisses on Done (or
/// an explicit dismiss gesture), never as a side effect of stepping.
class _CompositeRulePickerState extends State<_CompositeRulePicker> {
  late GoalFormCompositeRule _rule = widget.value;
  late int _required = widget.requiredSuccesses.clamp(1, widget.dimensionCount);

  void _apply(GoalFormCompositeRule rule, int required) {
    setState(() {
      _rule = rule;
      _required = required;
    });
    widget.onChanged(rule, required);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              messages.goalFormCompositeRule,
              style: tokens.typography.styles.heading.heading3,
            ),
            SizedBox(height: tokens.spacing.step3),
            // Scrollable, because the selected at-least row grows a
            // full-width stepper line: on a short phone or at raised text
            // scale the fixed column overflowed and could clip the stepper
            // or the Done button.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final rule in GoalFormCompositeRule.values)
                    DesignSystemSelectionRow(
                      title: _compositeRuleLabel(
                        context,
                        rule,
                        _required,
                        widget.dimensionCount,
                      ),
                      subtitle: switch (rule) {
                        GoalFormCompositeRule.all =>
                          messages.goalFormCompositeAllHint,
                        GoalFormCompositeRule.any =>
                          messages.goalFormCompositeAnyHint,
                        GoalFormCompositeRule.atLeast =>
                          messages.goalFormCompositeAtLeastHint,
                      },
                      selected: _rule == rule,
                      type: DesignSystemSelectionRowType.singleSelect,
                      // The stepper gets the row's full width on its own line —
                      // trailing squeezed it against the selection mark, which is
                      // how a stray tap kept landing beside the glyphs.
                      secondaryLine:
                          rule == GoalFormCompositeRule.atLeast && _rule == rule
                          ? DesignSystemStepper(
                              label: '$_required / ${widget.dimensionCount}',
                              decrementTooltip: messages.goalFormDecreaseTarget,
                              incrementTooltip: messages.goalFormIncreaseTarget,
                              decrementKey: const ValueKey(
                                'goal-form-composite-decrease',
                              ),
                              incrementKey: const ValueKey(
                                'goal-form-composite-increase',
                              ),
                              onDecrement: _required > 1
                                  ? () => _apply(rule, _required - 1)
                                  : null,
                              onIncrement: _required < widget.dimensionCount
                                  ? () => _apply(rule, _required + 1)
                                  : null,
                            )
                          : null,
                      onTap: () => _apply(rule, _required),
                    ),
                ],
              ),
            ),
            SizedBox(height: tokens.spacing.step4),
            DesignSystemButton(
              key: const ValueKey('goal-form-composite-done'),
              label: messages.doneButton,
              onPressed: () {
                // Commit the local state, not just close: opening the sheet
                // clamps a stale "3 of 2" to what the goal can actually
                // require, and Done is where that normalization reaches the
                // page instead of silently diverging until save.
                widget.onChanged(_rule, _required);
                Navigator.of(context).pop();
              },
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitTargetStepper extends StatelessWidget {
  const _HabitTargetStepper({
    required this.habitId,
    required this.value,
    required this.onChanged,
  });

  final String habitId;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DesignSystemStepper(
    label: context.messages.goalFormWeeklyTarget(value),
    decrementTooltip: context.messages.goalFormDecreaseTarget,
    incrementTooltip: context.messages.goalFormIncreaseTarget,
    decrementKey: ValueKey('goal-form-decrease-$habitId'),
    incrementKey: ValueKey('goal-form-increase-$habitId'),
    onDecrement: value > 1 ? () => onChanged(value - 1) : null,
    onIncrement: value < 7 ? () => onChanged(value + 1) : null,
  );
}
