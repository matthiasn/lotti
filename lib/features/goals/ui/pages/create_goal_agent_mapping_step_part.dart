part of 'create_goal_agent_page.dart';

class _MappingStep extends StatelessWidget {
  const _MappingStep({
    required this.title,
    required this.habits,
    required this.habitsFailed,
    required this.mapping,
    required this.measurables,
    required this.categories,
    required this.labels,
    required this.measurableTargets,
    required this.healthTargets,
    required this.healthDirections,
    required this.categoryTimeTargets,
    required this.categoryTimeDirections,
    required this.labelTimeTargets,
    required this.labelTimeDirections,
    required this.labelTimeCategoryIds,
    required this.compositeRule,
    required this.requiredSuccesses,
    required this.habitTargets,
    required this.watchesSteps,
    required this.stepsTarget,
    required this.chosenSignalOrder,
    required this.suggestedSignalOrder,
    required this.targetErrors,
    required this.anchorFor,
    required this.titleError,
    required this.validation,
    required this.onTitleChanged,
    required this.onStepsChanged,
    required this.onStepsTargetChanged,
    required this.onHabitChanged,
    required this.onTargetChanged,
    required this.onMeasurableChanged,
    required this.onMeasurableTargetChanged,
    required this.onHealthSelected,
    required this.onHealthRemoved,
    required this.onHealthTargetChanged,
    required this.onHealthDirectionChanged,
    required this.onCategoryTimeSelected,
    required this.onCategoryTimeRemoved,
    required this.onCategoryTimeTargetChanged,
    required this.onCategoryTimeDirectionChanged,
    required this.onLabelTimeSelected,
    required this.onLabelTimeRemoved,
    required this.onLabelTimeTargetChanged,
    required this.onLabelTimeDirectionChanged,
    required this.onLabelTimeCategoryChanged,
    required this.onCompositeRuleChanged,
    this.statement,
    this.statementError,
    this.onStatementChanged,
    this.onExampleSelected,
  });

  final List<HabitDefinition> habits;
  final bool habitsFailed;
  final GoalFormMapping mapping;
  final List<MeasurableDataType> measurables;
  final List<CategoryDefinition> categories;
  final List<LabelDefinition> labels;
  final Map<String, num?> measurableTargets;
  final Map<String, num?> healthTargets;
  final Map<String, GoalDirection> healthDirections;
  final Map<String, num?> categoryTimeTargets;
  final Map<String, GoalDirection> categoryTimeDirections;
  final Map<String, num?> labelTimeTargets;
  final Map<String, GoalDirection> labelTimeDirections;
  final Map<String, String?> labelTimeCategoryIds;
  final GoalFormCompositeRule compositeRule;
  final int requiredSuccesses;
  final Map<String, int> habitTargets;
  final bool watchesSteps;
  final TextEditingController stepsTarget;
  final TextEditingController title;

  /// Non-null only while editing: the goal statement lives at the top of
  /// this page instead of on a wizard step of its own.
  final TextEditingController? statement;
  final String? statementError;
  final VoidCallback? onStatementChanged;
  final ValueChanged<String>? onExampleSelected;

  /// Frozen row order for the signals card; see the page state's snapshot.
  final List<String> chosenSignalOrder;
  final List<String> suggestedSignalOrder;

  /// Keys of mapping entities whose target failed validation; each renders
  /// as an error on its own input rather than one message mid-page.
  final Set<String> targetErrors;
  final GlobalKey Function(String key) anchorFor;
  final String? titleError;
  final String? validation;
  final VoidCallback onTitleChanged;
  final ValueChanged<bool> onStepsChanged;
  final VoidCallback onStepsTargetChanged;
  final void Function({required String habitId, required bool selected})
  onHabitChanged;
  final void Function(String habitId, int target) onTargetChanged;
  final void Function({required String measurableId, required bool selected})
  onMeasurableChanged;
  final void Function(String measurableId, num? target)
  onMeasurableTargetChanged;
  final ValueChanged<List<String>> onHealthSelected;
  final ValueChanged<String> onHealthRemoved;
  final void Function(String dataType, num? target) onHealthTargetChanged;
  final void Function(String dataType, GoalDirection direction)
  onHealthDirectionChanged;
  final ValueChanged<String> onCategoryTimeSelected;
  final ValueChanged<String> onCategoryTimeRemoved;
  final void Function(String categoryId, num? target)
  onCategoryTimeTargetChanged;
  final void Function(String categoryId, GoalDirection direction)
  onCategoryTimeDirectionChanged;
  final ValueChanged<String> onLabelTimeSelected;
  final ValueChanged<String> onLabelTimeRemoved;
  final void Function(String labelId, num? target) onLabelTimeTargetChanged;
  final void Function(String labelId, GoalDirection direction)
  onLabelTimeDirectionChanged;
  final void Function(String labelId, String? categoryId)
  onLabelTimeCategoryChanged;
  final void Function(GoalFormCompositeRule rule, int requiredSuccesses)
  onCompositeRuleChanged;

  /// One habit signal band: provenance glyph, emoji-free name, cadence
  /// stepper trailing on wide rows or on the secondary line on compact ones.
  Widget _habitSignalRow(
    BuildContext context,
    ({String id, String name}) habit,
  ) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final selected = habitTargets.containsKey(habit.id);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < kRowInlineControlMinWidth;
        final stepper = selected
            ? _HabitTargetStepper(
                habitId: habit.id,
                value: habitTargets[habit.id]!,
                onChanged: (value) => onTargetChanged(habit.id, value),
              )
            : null;
        final row = DesignSystemSelectionRow(
          key: ValueKey('goal-form-habit-${habit.id}'),
          title: _CreateGoalAgentPageState._plainName(habit.name),
          subtitle: messages.goalFormHabitSignal,
          titleMaxLines: 2,
          leading: Icon(
            LottiIcons.confirmCircled,
            size: IconSizes.s,
            color: tokens.colors.text.mediumEmphasis,
          ),
          type: DesignSystemSelectionRowType.multiSelect,
          selected: selected,
          showSelectedBackground: false,
          trailing: compact || stepper == null
              ? null
              : Padding(
                  padding: EdgeInsets.only(right: tokens.spacing.step1),
                  child: stepper,
                ),
          secondaryLine: compact ? stepper : null,
          onTap: () => onHabitChanged(habitId: habit.id, selected: !selected),
        );
        return Column(children: [row, _signalRowDivider(tokens)]);
      },
    );
  }

  /// The always-available automatic step count, with its target input on the
  /// secondary line while selected.
  Widget _stepsRow(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      children: [
        DesignSystemSelectionRow(
          key: const ValueKey('goal-form-steps-row'),
          title: messages.goalCreateStepsTargetLabel,
          subtitle: messages.goalFormStepsSignal,
          leading: Icon(
            LottiIcons.walk,
            size: IconSizes.s,
            color: tokens.colors.text.mediumEmphasis,
          ),
          type: DesignSystemSelectionRowType.multiSelect,
          selected: watchesSteps,
          showSelectedBackground: false,
          secondaryLine: watchesSteps
              ? KeyedSubtree(
                  key: anchorFor('steps'),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kInlineTargetInputWidth,
                    ),
                    child: DesignSystemTextInput(
                      key: const ValueKey('goal-form-steps-target'),
                      controller: stepsTarget,
                      // The row title already names the signal; repeating it
                      // as the input label read as a duplicate. The input
                      // names the number instead.
                      label: messages.goalFormStepsDailyTarget,
                      keyboardType: TextInputType.number,
                      errorText: targetErrors.contains('steps')
                          ? messages.goalFormValidationTarget
                          : null,
                      onChanged: (_) => onStepsTargetChanged(),
                    ),
                  ),
                )
              : null,
          onTap: () => onStepsChanged(!watchesSteps),
        ),
        _signalRowDivider(tokens),
      ],
    );
  }

  /// Blood pressure as ONE row: checked with paired systolic/diastolic
  /// targets and a shared direction while selected, an offer otherwise.
  Widget _bloodPressureRow(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    const types = [
      GoalHealthDataTypes.bloodPressureSystolic,
      GoalHealthDataTypes.bloodPressureDiastolic,
    ];
    // A partial pair (an edited goal carrying only one reading) is still a
    // selected blood-pressure signal: the row renders checked with the
    // value it has, and deselecting removes whatever half is present.
    final selected = types.any(healthTargets.containsKey);
    return Column(
      children: [
        DesignSystemSelectionRow(
          key: const ValueKey('goal-form-health-row-blood-pressure'),
          title: messages.dashboardHealthBloodPressure,
          subtitle: messages.goalFormHealthReadingsSignal,
          leading: Icon(
            LottiIcons.heartRate,
            size: IconSizes.s,
            color: tokens.colors.text.mediumEmphasis,
          ),
          type: DesignSystemSelectionRowType.multiSelect,
          selected: selected,
          showSelectedBackground: false,
          secondaryLine: selected ? _bloodPressureControls(context) : null,
          onTap: () {
            if (selected) {
              types.forEach(onHealthRemoved);
            } else {
              onHealthSelected(types);
            }
          },
        ),
        _signalRowDivider(tokens),
      ],
    );
  }

  Widget _bloodPressureControls(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    const systolic = GoalHealthDataTypes.bloodPressureSystolic;
    const diastolic = GoalHealthDataTypes.bloodPressureDiastolic;
    // One toggle drives both readings, so it has to read from whichever
    // half a partial pair actually carries — an edited diastolic-only "at
    // least" goal must not render as the default "at most".
    final direction =
        healthDirections[systolic] ??
        healthDirections[diastolic] ??
        GoalDirection.atMost;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kInlineTargetInputWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HealthTargetInput(
                  dataType: systolic,
                  value: healthTargets[systolic],
                  unit: 'mmHg',
                  label: messages.goalFormSystolicTarget,
                  errorText: targetErrors.contains('health:$systolic')
                      ? messages.goalFormValidationTarget
                      : null,
                  anchorKey: anchorFor('health:$systolic'),
                  onChanged: (value) => onHealthTargetChanged(systolic, value),
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: _HealthTargetInput(
                  dataType: diastolic,
                  value: healthTargets[diastolic],
                  unit: 'mmHg',
                  label: messages.goalFormDiastolicTarget,
                  errorText: targetErrors.contains('health:$diastolic')
                      ? messages.goalFormValidationTarget
                      : null,
                  anchorKey: anchorFor('health:$diastolic'),
                  onChanged: (value) => onHealthTargetChanged(diastolic, value),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          DsSegmentedToggle<GoalDirection>(
            key: const ValueKey('goal-form-health-direction-blood-pressure'),
            segments: [
              DsSegment(
                GoalDirection.atMost,
                messages.goalFormDirectionAtMost,
              ),
              DsSegment(
                GoalDirection.atLeast,
                messages.goalFormDirectionAtLeast,
              ),
            ],
            selected: direction,
            onChanged: (value) {
              onHealthDirectionChanged(systolic, value);
              onHealthDirectionChanged(diastolic, value);
            },
            expand: true,
          ),
        ],
      ),
    );
  }

  /// Weight as one row with its target and direction on the secondary line.
  Widget _weightRow(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    const weight = GoalHealthDataTypes.weight;
    final selected = healthTargets.containsKey(weight);
    return Column(
      children: [
        DesignSystemSelectionRow(
          key: const ValueKey('goal-form-health-row-weight'),
          title: messages.goalFormHealthWeight,
          subtitle: messages.goalFormHealthReadingsSignal,
          leading: Icon(
            LottiIcons.weight,
            size: IconSizes.s,
            color: tokens.colors.text.mediumEmphasis,
          ),
          type: DesignSystemSelectionRowType.multiSelect,
          selected: selected,
          showSelectedBackground: false,
          secondaryLine: selected
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: kInlineTargetInputWidth,
                      ),
                      child: _HealthTargetInput(
                        dataType: weight,
                        value: healthTargets[weight],
                        unit: 'kg',
                        errorText: targetErrors.contains('health:$weight')
                            ? messages.goalFormValidationTarget
                            : null,
                        anchorKey: anchorFor('health:$weight'),
                        onChanged: (value) =>
                            onHealthTargetChanged(weight, value),
                      ),
                    ),
                    SizedBox(height: tokens.spacing.step3),
                    DsSegmentedToggle<GoalDirection>(
                      key: const ValueKey('goal-form-health-direction-weight'),
                      segments: [
                        DsSegment(
                          GoalDirection.atMost,
                          messages.goalFormDirectionAtMost,
                        ),
                        DsSegment(
                          GoalDirection.atLeast,
                          messages.goalFormDirectionAtLeast,
                        ),
                      ],
                      selected:
                          healthDirections[weight] ?? GoalDirection.atMost,
                      onChanged: (value) =>
                          onHealthDirectionChanged(weight, value),
                      expand: true,
                    ),
                  ],
                )
              : null,
          onTap: () {
            if (selected) {
              onHealthRemoved(weight);
            } else {
              onHealthSelected(const [weight]);
            }
          },
        ),
        _signalRowDivider(tokens),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final habitsById = {for (final habit in habits) habit.id: habit};
    final selectedIds = habitTargets.keys.toSet();
    final noObservableMatch =
        mapping.isEditable &&
        !watchesSteps &&
        selectedIds.isEmpty &&
        measurableTargets.isEmpty &&
        healthTargets.isEmpty &&
        categoryTimeTargets.isEmpty &&
        labelTimeTargets.isEmpty;
    final selectedMeasurables = [
      for (final measurable in measurables)
        if (measurableTargets.containsKey(measurable.id)) measurable,
    ];
    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    final selectedCategories = [
      for (final categoryId in categoryTimeTargets.keys)
        (
          id: categoryId,
          name:
              categoriesById[categoryId]?.name ??
              mapping.categoryTimeCriterionTitles[categoryId] ??
              categoryId,
        ),
    ];
    final labelsById = {for (final label in labels) label.id: label};
    final selectedLabels = [
      for (final labelId in labelTimeTargets.keys)
        (
          id: labelId,
          name:
              labelsById[labelId]?.name ??
              mapping.labelTimeCriterionTitles[labelId] ??
              labelId,
          categoryId: labelTimeCategoryIds[labelId],
        ),
    ];
    final dimensionCount =
        selectedIds.length +
        measurableTargets.length +
        healthTargets.length +
        categoryTimeTargets.length +
        labelTimeTargets.length +
        (watchesSteps ? 1 : 0);
    // Rows render in the order frozen at step entry — a tapped row stays
    // put. The page appends a signal selected after the snapshot (via the
    // picker) to the chosen group in the same setState that selects it, and
    // intention-matched signals are re-snapshotted whenever they change, so
    // every selected or matched signal already has its place in one group.
    Widget? signalRowFor(String descriptor) {
      if (descriptor == 'blood-pressure') return _bloodPressureRow(context);
      if (descriptor == 'weight') return _weightRow(context);
      if (descriptor == 'steps') return _stepsRow(context);
      final habitId = descriptor.substring('habit:'.length);
      // A descriptor in the frozen order renders as long as the habit is
      // resolvable (or still selected under privacy): deselecting a
      // picker-added habit leaves its unchecked row until step re-entry.
      if (!habitsById.containsKey(habitId) && !selectedIds.contains(habitId)) {
        return null;
      }
      return _habitSignalRow(
        context,
        (id: habitId, name: habitsById[habitId]?.name ?? habitId),
      );
    }

    final chosenSignals = <Widget>[
      for (final descriptor in chosenSignalOrder) ?signalRowFor(descriptor),
    ];
    final suggestedSignals = <Widget>[
      for (final descriptor in suggestedSignalOrder) ?signalRowFor(descriptor),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The consolidated edit page opens with the statement — one line,
        // with the example pills inline, no dead space and no page of its
        // own.
        if (statement case final statement?) ...[
          DesignSystemTextInput(
            key: const ValueKey('goal-form-intention'),
            controller: statement,
            label: messages.goalFormStatementLabel,
            leadingIcon: LottiIcons.editNote,
            errorText: statementError,
            onChanged: (_) => onStatementChanged?.call(),
          ),
          SizedBox(height: tokens.spacing.step3),
          Wrap(
            spacing: tokens.spacing.step2,
            runSpacing: tokens.spacing.step2,
            children: [
              for (final example in _intentionExamples(context))
                DsPill(
                  variant: DsPillVariant.filled,
                  label: example,
                  bordered: true,
                  onTap: () => onExampleSelected?.call(example),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.sectionGap),
        ],
        Text(
          noObservableMatch
              ? messages.goalFormRefusalTitle
              : messages.goalFormMappingTitle,
          style: tokens.typography.styles.heading.heading3,
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          noObservableMatch
              ? messages.goalFormRefusalBody
              : messages.goalFormMappingIntro,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        if (!mapping.isEditable)
          DesignSystemSectionCard(
            child: Text(
              messages.goalFormUnsupportedCriteria,
              style: tokens.typography.styles.body.bodyMedium,
            ),
          )
        else ...[
          DesignSystemSectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ...chosenSignals,
                if (suggestedSignals.isNotEmpty) ...[
                  // The card tells one true story: rows above this caption
                  // are the goal's signals, rows below are offers.
                  Padding(
                    padding: EdgeInsets.only(
                      left: tokens.spacing.step5,
                      right: tokens.spacing.step5,
                      top: tokens.spacing.step3,
                      bottom: tokens.spacing.step1,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        messages.goalFormSuggestedSignals,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ),
                  ),
                  ...suggestedSignals,
                ],
              ],
            ),
          ),
          for (final measurable in selectedMeasurables) ...[
            SizedBox(height: tokens.spacing.cardItemSpacing),
            DesignSystemSectionCard(
              key: ValueKey('goal-form-measurable-card-${measurable.id}'),
              child: Row(
                children: [
                  Icon(
                    LottiIcons.measure,
                    color: GoalAccentHues.aurora(
                      Theme.of(context).brightness,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          measurable.displayName,
                          style: tokens.typography.styles.subtitle.subtitle2,
                        ),
                        Text(
                          context.messages.goalFormMeasurableSource(
                            measurable.unitName,
                          ),
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: _MeasurableTargetInput(
                      measurableId: measurable.id,
                      value: measurableTargets[measurable.id],
                      unitName: measurable.unitName,
                      errorText:
                          targetErrors.contains('measurable:${measurable.id}')
                          ? messages.goalFormValidationTarget
                          : null,
                      anchorKey: anchorFor('measurable:${measurable.id}'),
                      onChanged: (value) =>
                          onMeasurableTargetChanged(measurable.id, value),
                    ),
                  ),
                  DesignSystemIconAction(
                    icon: LottiIcons.close,
                    tooltip: context.messages.aiCardProposalKindRemove,
                    onPressed: () => onMeasurableChanged(
                      measurableId: measurable.id,
                      selected: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
          for (final category in selectedCategories) ...[
            SizedBox(height: tokens.spacing.cardItemSpacing),
            _CategoryTimeTargetCard(
              key: ValueKey('goal-form-category-time-card-${category.id}'),
              categoryId: category.id,
              categoryName: category.name,
              value: categoryTimeTargets[category.id],
              errorText: targetErrors.contains('category:${category.id}')
                  ? messages.goalFormValidationTarget
                  : null,
              anchorKey: anchorFor('category:${category.id}'),
              direction:
                  categoryTimeDirections[category.id] ?? GoalDirection.atMost,
              onTargetChanged: (target) =>
                  onCategoryTimeTargetChanged(category.id, target),
              onDirectionChanged: (direction) =>
                  onCategoryTimeDirectionChanged(category.id, direction),
              onRemove: () => onCategoryTimeRemoved(category.id),
            ),
          ],
          for (final label in selectedLabels) ...[
            SizedBox(height: tokens.spacing.cardItemSpacing),
            _LabelTimeTargetCard(
              key: ValueKey('goal-form-label-time-card-${label.id}'),
              labelId: label.id,
              labelName: label.name,
              categories: categories,
              categoryId: label.categoryId,
              value: labelTimeTargets[label.id],
              errorText: targetErrors.contains('label:${label.id}')
                  ? messages.goalFormValidationTarget
                  : null,
              anchorKey: anchorFor('label:${label.id}'),
              direction: labelTimeDirections[label.id] ?? GoalDirection.atLeast,
              onTargetChanged: (target) =>
                  onLabelTimeTargetChanged(label.id, target),
              onDirectionChanged: (direction) =>
                  onLabelTimeDirectionChanged(label.id, direction),
              onCategoryChanged: (categoryId) =>
                  onLabelTimeCategoryChanged(label.id, categoryId),
              onRemove: () => onLabelTimeRemoved(label.id),
            ),
          ],
          if (validation != null) ...[
            SizedBox(height: tokens.spacing.step3),
            Text(
              validation!,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.alert.error.defaultColor,
              ),
            ),
          ],
          SizedBox(height: tokens.spacing.cardItemSpacing),
          // On desktop the commit action must be the heaviest object in the
          // column, so the add affordance drops to an intrinsic tertiary.
          DesignSystemButton(
            key: const ValueKey('goal-form-add-signal'),
            label: context.messages.goalFormAddSignal,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => _DimensionSourcePicker(
                habits: habits,
                habitsFailed: habitsFailed,
                measurables: measurables,
                categories: categories,
                labels: labels,
                selectedHabitIds: habitTargets.keys.toSet(),
                selectedMeasurableIds: measurableTargets.keys.toSet(),
                selectedHealthDataTypes: healthTargets.keys.toSet(),
                selectedCategoryIds: categoryTimeTargets.keys.toSet(),
                selectedLabelIds: labelTimeTargets.keys.toSet(),
                watchesSteps: watchesSteps,
                onStepsChanged: onStepsChanged,
                onHabitChanged: onHabitChanged,
                onMeasurableChanged: onMeasurableChanged,
                onHealthSelected: onHealthSelected,
                onHealthRemoved: onHealthRemoved,
                onCategorySelected: onCategoryTimeSelected,
                onCategoryRemoved: onCategoryTimeRemoved,
                onLabelSelected: onLabelTimeSelected,
                onLabelRemoved: onLabelTimeRemoved,
              ),
            ),
            leadingIcon: LottiIcons.add,
            variant: isDesktopLayout(context)
                ? DesignSystemButtonVariant.tertiary
                : DesignSystemButtonVariant.secondary,
            fullWidth: !isDesktopLayout(context),
          ),
          if (dimensionCount > 1) ...[
            SizedBox(height: tokens.spacing.cardItemSpacing),
            DesignSystemSectionCard(
              child: Row(
                children: [
                  Icon(
                    LottiIcons.tree,
                    color: tokens.colors.interactive.enabled,
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.messages.goalFormCompositeRule,
                          style: tokens.typography.styles.subtitle.subtitle2,
                        ),
                        Text(
                          _compositeRuleLabel(
                            context,
                            compositeRule,
                            // Clamped for display: removing a dimension can
                            // strand a stored "3 of" above a 2-dimension
                            // goal, and the card must not promise the
                            // impossible while buildCriteria would silently
                            // save the clamped value anyway.
                            requiredSuccesses.clamp(1, dimensionCount),
                            dimensionCount,
                          ),
                          style: tokens.typography.styles.body.bodySmall
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                      ],
                    ),
                  ),
                  DesignSystemButton(
                    label: context.messages.insightsTableDelta,
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (context) => _CompositeRulePicker(
                        value: compositeRule,
                        requiredSuccesses: requiredSuccesses,
                        dimensionCount: dimensionCount,
                        onChanged: onCompositeRuleChanged,
                      ),
                    ),
                    variant: DesignSystemButtonVariant.tertiary,
                    size: DesignSystemButtonSize.dense,
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: tokens.spacing.sectionGap),
          // The goal's NAME is authored here, after the signals that shape
          // it — the derived value keeps following the selection until the
          // user types their own.
          DesignSystemTextInput(
            key: const ValueKey('goal-form-title-mapping'),
            controller: title,
            label: messages.goalFormGoalNameLabel,
            leadingIcon: LottiIcons.flag,
            errorText: titleError,
            onChanged: (_) => onTitleChanged(),
          ),
          SizedBox(height: tokens.spacing.sectionGap),
          // A footnote, not a card: the explainer must not impersonate a
          // second input under the goal-name field.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LottiIcons.viewColumns,
                size: IconSizes.s,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  messages.goalFormRollingNote,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
            ],
          ),
          if (noObservableMatch) ...[
            SizedBox(height: tokens.spacing.step4),
            Text(
              messages.goalFormRefusalFooter,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
