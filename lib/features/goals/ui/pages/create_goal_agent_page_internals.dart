part of 'create_goal_agent_page.dart';

/// Private helpers of [_CreateGoalAgentPageState] that hold no state of their own; kept beside the class as an extension so the library stays readable.
extension _CreateGoalAgentPageStateInternals on _CreateGoalAgentPageState {
  void _initializeEdit(
    AgentIdentityEntity identity,
    GoalSpecVersionEntity spec,
  ) {
    if (_initialized) return;
    _initialized = true;
    _statement.text = spec.statement;
    _title.text = spec.title;
    _persona.text = identity.displayName;
    _baseVersionId = spec.id;
    _mapping = GoalFormMapping.fromCriteria(spec.criteria);
    _watchesSteps = _mapping.watchesSteps;
    _stepsTarget.text = NumberFormat.decimalPattern(
      context.messages.localeName,
    ).format(_mapping.stepsTarget);
    _habitTargets.addAll(_mapping.habitTargets);
    _measurableTargets.addAll(_mapping.measurableTargets);
    _healthTargets.addAll(_mapping.healthTargets);
    _healthDirections.addAll(_mapping.healthDirections);
    _categoryTimeTargets.addAll(_mapping.categoryTimeTargets);
    _categoryTimeDirections.addAll(_mapping.categoryTimeDirections);
    _labelTimeTargets.addAll(_mapping.labelTimeTargets);
    _labelTimeDirections.addAll(_mapping.labelTimeDirections);
    _labelTimeCategoryIds.addAll(_mapping.labelTimeCategoryIds);
    _compositeRule = _mapping.compositeRule;
    _requiredSuccesses = _mapping.requiredSuccesses;
    // Editing lands directly on the mapping page, so the signal-row order
    // that creation freezes on step entry is frozen here instead.
    _snapshotSignalGroups();
  }

  void _rememberMeasurableDefinitions(
    List<MeasurableDataType> measurables,
  ) {
    _knownMeasurables = [
      for (final measurable in measurables)
        if (!measurable.isChoice) measurable,
    ];
    _knownChoiceMeasurableIds
      ..clear()
      ..addAll(
        measurables
            .where((measurable) => measurable.isChoice)
            .map(
              (measurable) => measurable.id,
            ),
      );
    _measurableDefinitionsLoaded = true;
  }

  num? _parseLocalizedTarget(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    try {
      return NumberFormat.decimalPattern(
        context.messages.localeName,
      ).parse(text);
    } on FormatException {
      return num.tryParse(text);
    }
  }

  Set<String> _words(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.length >= 3)
      .toSet();

  bool _matchesIntention(String label) {
    final intention = _statement.text.trim().toLowerCase();
    final normalizedLabel = label.trim().toLowerCase();
    if (normalizedLabel.isEmpty) return false;
    if (intention == normalizedLabel) return true;
    final distinctiveLabelWords = _words(
      normalizedLabel,
    ).difference(_genericIntentionWords(context));
    return distinctiveLabelWords.intersection(_words(intention)).isNotEmpty;
  }

  String _categoriesFingerprint(List<CategoryDefinition> categories) =>
      categories
          .map((category) => '${category.id}\u0000${category.name}')
          .join('\u0001');

  /// Signals selected after the snapshot (via the picker) join the chosen
  /// group for the lifetime of the current mapping-step entry, so
  /// deselecting one leaves an unchecked row instead of deleting it.
  void _appendSignalDescriptors(Iterable<String> healthDataTypes) {
    final descriptors = <String>{
      for (final dataType in healthDataTypes)
        if (dataType == GoalHealthDataTypes.weight)
          'weight'
        else
          'blood-pressure',
    };
    for (final descriptor in descriptors) {
      if (!_chosenSignalOrder.contains(descriptor) &&
          !_suggestedSignalOrder.contains(descriptor)) {
        _chosenSignalOrder.add(descriptor);
      }
    }
  }

  void _appendHabitDescriptor(String habitId) {
    final descriptor = 'habit:$habitId';
    if (!_chosenSignalOrder.contains(descriptor) &&
        !_suggestedSignalOrder.contains(descriptor)) {
      _chosenSignalOrder.add(descriptor);
    }
  }

  void _snapshotSignalGroups() {
    final selectedHabitIds = _habitTargets.keys.toList();
    final bloodPressureSelected =
        _healthTargets.containsKey(GoalHealthDataTypes.bloodPressureSystolic) ||
        _healthTargets.containsKey(GoalHealthDataTypes.bloodPressureDiastolic);
    final bloodPressureMatched = _matchedHealthTypes.contains(
      GoalHealthDataTypes.bloodPressureSystolic,
    );
    final weightSelected = _healthTargets.containsKey(
      GoalHealthDataTypes.weight,
    );
    final weightMatched = _matchedHealthTypes.contains(
      GoalHealthDataTypes.weight,
    );
    _chosenSignalOrder = [
      for (final id in selectedHabitIds) 'habit:$id',
      if (bloodPressureSelected) 'blood-pressure',
      if (weightSelected) 'weight',
      if (_watchesSteps) 'steps',
    ];
    _suggestedSignalOrder = [
      for (final id in _matchedHabitIds)
        if (!_habitTargets.containsKey(id)) 'habit:$id',
      if (!bloodPressureSelected && bloodPressureMatched) 'blood-pressure',
      if (!weightSelected && weightMatched) 'weight',
      if (!_watchesSteps) 'steps',
    ];
  }

  void _deriveTitle(List<HabitDefinition> habits) {
    final currentTitle = _title.text.trim();
    if (currentTitle.isNotEmpty && currentTitle != _derivedTitle) return;
    final selectedNames = [
      for (final habit in habits)
        if (_habitTargets.containsKey(habit.id))
          _CreateGoalAgentPageState._plainName(habit.name),
    ];
    final derivedTitle = selectedNames.isNotEmpty
        ? selectedNames.join(' & ')
        : _watchesSteps
        ? context.messages.goalCreateTypeSteps
        : _statement.text.trim();
    _title.text = derivedTitle;
    _derivedTitle = derivedTitle;
  }

  void _reconcileHabitTargets({
    Set<String> preservedHabitIds = const <String>{},
  }) {
    final habitsAsync = ref.read(_habitDefinitionsProvider);
    final currentHabits = habitsAsync.value;
    if (currentHabits == null || habitsAsync.hasError) return;
    final activeHabitIds = {for (final habit in currentHabits) habit.id};
    final loadedHabitIds = _editing
        ? _mapping.habitTargets.keys.toSet()
        : const <String>{};
    _habitTargets.removeWhere(
      (habitId, _) =>
          !activeHabitIds.contains(habitId) &&
          !loadedHabitIds.contains(habitId) &&
          !preservedHabitIds.contains(habitId),
    );
  }

  Future<List<HabitDefinition>> _reconcileHabitTargetsForSave() async {
    final selectedHabitIds = _habitTargets.keys.toList(growable: false);
    if (selectedHabitIds.isEmpty) return const [];

    final repository = ref.read(habitsRepositoryProvider);
    final resolvedHabits = await Future.wait([
      for (final habitId in selectedHabitIds)
        repository.getHabitByIdForIntegrity(habitId),
    ]);
    final confirmedHabits = <HabitDefinition>[];
    for (var index = 0; index < selectedHabitIds.length; index++) {
      final habitId = selectedHabitIds[index];
      final habit = resolvedHabits[index];
      if (habit == null || !habit.active || habit.deletedAt != null) {
        _habitTargets.remove(habitId);
      } else {
        confirmedHabits.add(habit);
      }
    }
    if (!mounted) return confirmedHabits;

    // The visible stream can refresh while integrity reads are in flight.
    // Preserve every selection the unfiltered integrity lookup confirmed as
    // active; a newly-private habit may legitimately disappear from the
    // discovery stream during this await.
    _reconcileHabitTargets(
      preservedHabitIds: {
        for (final habit in confirmedHabits) habit.id,
      },
    );
    return confirmedHabits;
  }

  Future<void> _reconcileMeasurableTargetsForSave() async {
    if (_measurableTargets.isEmpty) return;
    if (!_measurableDefinitionsLoaded) {
      _rememberMeasurableDefinitions(
        await ref.read(measurableDataTypesStreamProvider.future),
      );
    }
    _removeChoiceMeasurableTargets(_knownChoiceMeasurableIds);
  }

  void _invalidateGoalViews(ProviderContainer container, String agentId) {
    container
      ..invalidate(agentIdentityProvider(agentId))
      ..invalidate(goalAgentHealthProvider(agentId))
      ..invalidate(goalAgentProgressViewProvider(agentId))
      ..invalidate(goalAgentProgressViewForSpanProvider)
      ..invalidate(selfTargetedPendingChangeSetsProvider(agentId))
      ..invalidate(activeGoalAgentsProvider)
      ..invalidate(activeGoalNudgesProvider)
      ..invalidate(goalNudgeHistoryProvider(agentId));
  }

  String _signalDescription(List<HabitDefinition> habits) {
    final names = {for (final habit in habits) habit.id: habit.name};
    final measurableNames = {
      for (final measurable in _knownMeasurables)
        measurable.id: measurable.displayName,
    };
    final categoryNames = {
      for (final category in _knownCategories) category.id: category.name,
    };
    final labelNames = {
      for (final label in _knownLabels) label.id: label.name,
    };
    final signals = <String>[
      if (_watchesSteps)
        context.messages.goalFormStepsCadence(
          NumberFormat.decimalPattern(
            context.messages.localeName,
          ).format(_parseLocalizedTarget(_stepsTarget.text) ?? 0),
        ),
      for (final entry in _habitTargets.entries)
        context.messages.goalFormHabitCadence(
          _CreateGoalAgentPageState._plainName(names[entry.key] ?? entry.key),
          entry.value,
        ),
      for (final entry in _measurableTargets.entries)
        if (entry.value case final target?)
          context.messages.goalFormMeasurableCadence(
            measurableNames[entry.key] ?? entry.key,
            NumberFormat.decimalPattern(
              context.messages.localeName,
            ).format(target),
          ),
      for (final entry in _healthTargets.entries)
        if (entry.value case final target?)
          context.messages.goalFormHealthCadence(
            _healthDimensionName(context, entry.key),
            _goalDirectionLabel(
              context,
              _healthDirections[entry.key] ?? GoalDirection.atMost,
            ),
            NumberFormat.decimalPattern(
              context.messages.localeName,
            ).format(target),
            _healthDimensionUnit(entry.key),
          ),
      for (final entry in _categoryTimeTargets.entries)
        if (entry.value case final target?)
          context.messages.goalFormCategoryTimeCadence(
            categoryNames[entry.key] ??
                _mapping.categoryTimeCriterionTitles[entry.key] ??
                entry.key,
            _goalDirectionLabel(
              context,
              _categoryTimeDirections[entry.key] ?? GoalDirection.atMost,
            ),
            NumberFormat.decimalPattern(
              context.messages.localeName,
            ).format(target),
          ),
      for (final entry in _labelTimeTargets.entries)
        if (entry.value case final target?)
          context.messages.goalFormLabelTimeCadence(
            labelNames[entry.key] ??
                _mapping.labelTimeCriterionTitles[entry.key] ??
                entry.key,
            _goalDirectionLabel(
              context,
              _labelTimeDirections[entry.key] ?? GoalDirection.atLeast,
            ),
            NumberFormat.decimalPattern(
              context.messages.localeName,
            ).format(target),
          ),
    ];
    return signals.join(' · ');
  }
}
