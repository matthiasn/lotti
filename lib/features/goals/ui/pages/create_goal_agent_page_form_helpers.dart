part of 'create_goal_agent_page.dart';

/// Form helpers of the goal create and edit page that read or adjust its state without rebuilding it: intention-word matching, catalog fingerprints, criteria assembly and save-time target reconciliation.
extension _GoalFormHelpers on _CreateGoalAgentPageState {
  /// Drops numeric goal targets whose measurable has since been converted to
  /// choices. Keeping one would compare the choice occurrence marker (`1`)
  /// with an old quantity, and filtering the definition alone would leave an
  /// invisible target that the edit silently saved again.
  void _removeChoiceMeasurableTargets(Set<String> choiceIds) {
    for (final id in choiceIds) {
      _measurableTargets.remove(id);
      _targetErrors.remove('measurable:$id');
      _chosenSignalOrder.remove('measurable:$id');
      _suggestedSignalOrder.remove('measurable:$id');
    }
  }

  /// Gives a newly filled half of the blood-pressure pair the direction the
  /// shared toggle is already showing.
  ///
  /// One toggle drives both readings, so typing into the blank systolic
  /// input of an edited diastolic-only "at least" goal must not persist a
  /// systolic leaf as the default "at most" — the row would claim one
  /// direction while the saved criterion carried the other.
  void _adoptSharedBloodPressureDirection(String dataType) {
    const systolic = GoalHealthDataTypes.bloodPressureSystolic;
    const diastolic = GoalHealthDataTypes.bloodPressureDiastolic;
    if (dataType != systolic && dataType != diastolic) return;
    if (_healthDirections.containsKey(dataType)) return;
    final counterpart = dataType == systolic ? diastolic : systolic;
    final shared = _healthDirections[counterpart];
    if (shared == null) return;
    _healthDirections[dataType] = shared;
  }

  /// Parses one of the matcher's comma-separated catalog word lists.
  ///
  /// Both lists are matched against words the *user* wrote — a goal
  /// statement, a habit name — so they have to be in the user's language.
  /// A hardcoded English list silently disables the matcher everywhere
  /// else, which is why the forms live in the catalogs.
  Set<String> _catalogWords(String value) => value
      .toLowerCase()
      .split(',')
      .map((word) => word.trim())
      .where((word) => word.isNotEmpty)
      .toSet();

  /// Words too common to make a label distinctive ("daily", "routine").
  Set<String> _genericIntentionWords(BuildContext context) =>
      _catalogWords(context.messages.goalFormGenericIntentionWords);

  /// Bookkeeping verbs that don't make a habit more than a record of the
  /// measurement it names ("Measure Blood Pressure", "Gewicht messen").
  Set<String> _measurementVerbs(BuildContext context) =>
      _catalogWords(context.messages.goalFormMeasurementVerbs);

  /// Whether this habit is a bookkeeping twin of an intention-matched
  /// health capability: every distinctive word in its name is either part
  /// of the health label or a measurement verb ("Measure Blood Pressure"
  /// beside the blood-pressure readings signal). A habit that merely shares
  /// one word with a label ("Weight training", "Pressure wash patio") is a
  /// real habit and keeps its default selection.
  bool _overlapsMatchedHealthLabel(String habitName) {
    if (_matchedHealthTypes.isEmpty) return false;
    final habitWords = _words(
      _CreateGoalAgentPageState._plainName(habitName),
    ).difference(_genericIntentionWords(context));
    if (habitWords.isEmpty) return false;
    final measurementVerbs = _measurementVerbs(context);
    for (final dataType in _matchedHealthTypes) {
      final labelWords = _words(_healthDimensionName(context, dataType));
      final leftover = habitWords
          .difference(labelWords)
          .difference(measurementVerbs);
      if (leftover.isEmpty && habitWords.intersection(labelWords).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  String _habitsFingerprint(List<HabitDefinition> habits) =>
      habits.map((habit) => '${habit.id}\u0000${habit.name}').join('\u0001');

  String _labelsFingerprint(List<LabelDefinition> labels) =>
      labels.map((label) => '${label.id}\u0000${label.name}').join('\u0001');

  /// Re-derives the title after a selection change, but only while the
  /// form still owns it — a user-authored (or deliberately cleared-and-
  /// retyped) title is never overwritten.
  void _refreshDerivedTitle(List<HabitDefinition> habits) {
    if (_title.text.trim() != _derivedTitle) return;
    _title.text = '';
    _deriveTitle(habits);
  }

  GlobalKey _anchorFor(String key) =>
      _errorAnchors.putIfAbsent(key, GlobalKey.new);

  /// Scrolls the first offending target card into view, so a failed
  /// validation is never an invisible message elsewhere on the page.
  void _revealFirstTargetError() {
    final orderedKeys = [
      'steps',
      for (final dataType in _healthTargets.keys) 'health:$dataType',
      for (final id in _measurableTargets.keys) 'measurable:$id',
      for (final id in _categoryTimeTargets.keys) 'category:$id',
      for (final id in _labelTimeTargets.keys) 'label:$id',
    ];
    String? first;
    for (final key in orderedKeys) {
      if (_targetErrors.contains(key)) {
        first = key;
        break;
      }
    }
    if (first == null) return;
    final anchor = _errorAnchors[first];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchorContext = anchor?.currentContext;
      if (!mounted || anchorContext == null) return;
      Scrollable.ensureVisible(
        anchorContext,
        duration: MotionDurations.medium2,
        curve: MotionCurves.emphasizedDecelerate,
        alignment: 0.2,
      );
    });
  }

  /// The goal's criteria from the confirmed form, or null when steps are
  /// watched without a positive target. [confirmedCategories] are the
  /// categories the save just reconciled, named alongside the known ones.
  GoalCriterion? _buildFormCriteria(
    List<CategoryDefinition> confirmedCategories,
  ) {
    final messages = context.messages;
    final stepsTarget = _parseLocalizedTarget(_stepsTarget.text);
    return _watchesSteps && (stepsTarget == null || stepsTarget <= 0)
        ? null
        : _mapping.buildCriteria(
            stepsTitle: messages.goalCreateStepsTargetLabel,
            habitTargets: _habitTargets,
            measurableTargets: {
              for (final entry in _measurableTargets.entries)
                entry.key: ?entry.value,
            },
            measurableTitles: {
              for (final measurable in _knownMeasurables)
                measurable.id: measurable.displayName,
            },
            healthTargets: {
              for (final entry in _healthTargets.entries)
                entry.key: ?entry.value,
            },
            healthDirections: _healthDirections,
            healthTitles: {
              for (final dataType in _healthTargets.keys)
                dataType: _healthDimensionName(context, dataType),
            },
            categoryTimeTargets: {
              for (final entry in _categoryTimeTargets.entries)
                entry.key: ?entry.value,
            },
            categoryTimeDirections: _categoryTimeDirections,
            categoryTimeTitles: {
              for (final category in confirmedCategories)
                category.id: category.name,
              for (final category in _knownCategories)
                category.id: category.name,
            },
            labelTimeTargets: {
              for (final entry in _labelTimeTargets.entries)
                entry.key: ?entry.value,
            },
            labelTimeDirections: _labelTimeDirections,
            labelTimeTitles: {
              for (final label in _knownLabels) label.id: label.name,
            },
            labelTimeCategoryIds: _labelTimeCategoryIds,
            watchesSteps: _watchesSteps,
            stepsTarget: stepsTarget,
            compositeRule: _compositeRule,
            requiredSuccesses: _requiredSuccesses,
          );
  }

  Future<List<CategoryDefinition>>
  _reconcileCategoryTimeTargetsForSave() async {
    final selectedCategoryIds = _categoryTimeTargets.keys.toList();
    if (selectedCategoryIds.isEmpty) return const [];
    final repository = ref.read(categoryRepositoryProvider);
    final categoriesById = {
      for (final category in await repository.getAllCategoriesIncludingHidden())
        category.id: category,
    };
    final confirmedCategories = <CategoryDefinition>[];
    for (final categoryId in selectedCategoryIds) {
      final category = categoriesById[categoryId];
      if (category != null && category.active && category.deletedAt == null) {
        confirmedCategories.add(category);
      }
    }
    final activeCategoryIds = {
      for (final category in confirmedCategories) category.id,
    };
    final preservedCategoryIds = _editing
        ? _mapping.categoryTimeTargets.keys.toSet()
        : const <String>{};
    _categoryTimeTargets.removeWhere(
      (categoryId, _) =>
          !activeCategoryIds.contains(categoryId) &&
          !preservedCategoryIds.contains(categoryId),
    );
    _categoryTimeDirections.removeWhere(
      (categoryId, _) => !_categoryTimeTargets.containsKey(categoryId),
    );
    return confirmedCategories;
  }
}
