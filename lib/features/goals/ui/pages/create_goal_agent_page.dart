import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/service/goal_spec_revision_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/pages/goal_form_mapping.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// Creates or edits a goal agent through WP5's intention → observable mapping
/// → confirmation flow.
///
/// Passing [agentId] switches the flow into versioned editing. The current
/// spec is mapped losslessly into the same controls used for creation; saving
/// mints a new immutable spec version rather than changing history in place.
class CreateGoalAgentPage extends ConsumerStatefulWidget {
  const CreateGoalAgentPage({this.agentId, super.key});

  final String? agentId;

  @override
  ConsumerState<CreateGoalAgentPage> createState() =>
      _CreateGoalAgentPageState();
}

enum _GoalFormStep { intention, mapping, confirmation }

class _CreateGoalAgentPageState extends ConsumerState<CreateGoalAgentPage> {
  static const _genericIntentionWords = {
    'and',
    'consistent',
    'consistently',
    'daily',
    'day',
    'days',
    'each',
    'every',
    'goal',
    'habit',
    'month',
    'monthly',
    'months',
    'per',
    'regular',
    'regularly',
    'routine',
    'time',
    'times',
    'week',
    'weekly',
    'weeks',
    'year',
    'yearly',
    'years',
  };

  final _statement = TextEditingController();
  final _title = TextEditingController();
  final _persona = TextEditingController();
  final _stepsTarget = TextEditingController(text: '10000');
  _GoalFormStep _step = _GoalFormStep.intention;
  var _mapping = const GoalFormMapping.empty();
  final _habitTargets = <String, int>{};
  final _measurableTargets = <String, num?>{};
  final _healthTargets = <String, num?>{};
  final _healthDirections = <String, GoalDirection>{};
  final _categoryTimeTargets = <String, num?>{};
  final _categoryTimeDirections = <String, GoalDirection>{};
  final _suppressedCategoryTimeIds = <String>{};
  List<HabitDefinition> _knownHabits = const [];
  List<MeasurableDataType> _knownMeasurables = const [];
  List<CategoryDefinition> _knownCategories = const [];
  var _watchesSteps = false;
  GoalFormCompositeRule _compositeRule = GoalFormCompositeRule.all;
  var _requiredSuccesses = 1;
  var _showAllHabits = false;
  var _initialized = false;
  var _defaultPersonaInitialized = false;
  var _saving = false;
  String? _derivedFrom;
  String? _derivedTitle;
  String? _derivedHabitsFingerprint;
  String? _derivedCategoriesFingerprint;
  late String _baseVersionId;
  String? _validation;

  bool get _editing => widget.agentId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_editing && !_defaultPersonaInitialized) {
      _persona.text = context.messages.goalFormDefaultPersonaName;
      _defaultPersonaInitialized = true;
    }
  }

  @override
  void dispose() {
    _statement.dispose();
    _title.dispose();
    _persona.dispose();
    _stepsTarget.dispose();
    super.dispose();
  }

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
    _compositeRule = _mapping.compositeRule;
    _requiredSuccesses = _mapping.requiredSuccesses;
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
    ).difference(_genericIntentionWords);
    return distinctiveLabelWords.intersection(_words(intention)).isNotEmpty;
  }

  String _habitsFingerprint(List<HabitDefinition> habits) =>
      habits.map((habit) => '${habit.id}\u0000${habit.name}').join('\u0001');

  String _categoriesFingerprint(List<CategoryDefinition> categories) =>
      categories
          .map((category) => '${category.id}\u0000${category.name}')
          .join('\u0001');

  void _mapIntention(List<HabitDefinition> habits) {
    final statement = _statement.text.trim();
    if (statement.isEmpty) {
      setState(
        () => _validation = context.messages.goalFormValidationIntention,
      );
      return;
    }

    final habitsAsync = ref.read(_habitDefinitionsProvider);
    final habitsFingerprint = habitsAsync.hasError || habitsAsync.value == null
        ? null
        : _habitsFingerprint(habits);
    final habitsChanged =
        habitsFingerprint != null &&
        habitsFingerprint != _derivedHabitsFingerprint;
    final categoriesAsync = ref.read(categoriesStreamProvider);
    final categoriesFingerprint =
        categoriesAsync.hasError || categoriesAsync.value == null
        ? null
        : _categoriesFingerprint(_knownCategories);
    final categoriesChanged =
        categoriesFingerprint != null &&
        categoriesFingerprint != _derivedCategoriesFingerprint;
    final requiresFullRemap = _derivedFrom != statement || habitsChanged;
    if (!_editing && requiresFullRemap) {
      _suppressedCategoryTimeIds.clear();
      final matchedHabits = [
        for (final habit in habits)
          if (_matchesIntention(habit.name)) habit,
      ];
      final stepsLabel = context.messages.goalCreateStepsTargetLabel;
      _watchesSteps = _matchesIntention(stepsLabel);
      _habitTargets
        ..clear()
        ..addEntries(
          matchedHabits.map((habit) => MapEntry(habit.id, 3)),
        );
      final matchedMeasurables = [
        for (final measurable in _knownMeasurables)
          if (_matchesIntention(measurable.displayName)) measurable,
      ];
      _measurableTargets
        ..clear()
        ..addEntries(
          matchedMeasurables.map((measurable) => MapEntry(measurable.id, 1)),
        );
      final matchedCategories = [
        for (final category in _knownCategories)
          if (_matchesIntention(category.name)) category,
      ];
      _categoryTimeTargets
        ..clear()
        ..addEntries(
          matchedCategories.map((category) => MapEntry(category.id, 1)),
        );
      _categoryTimeDirections
        ..clear()
        ..addEntries(
          matchedCategories.map(
            (category) => MapEntry(category.id, GoalDirection.atMost),
          ),
        );
      _deriveTitle(habits);
      _derivedFrom = statement;
      if (habitsFingerprint != null) {
        _derivedHabitsFingerprint = habitsFingerprint;
      }
      if (categoriesFingerprint != null) {
        _derivedCategoriesFingerprint = categoriesFingerprint;
      }
    } else if (!_editing && categoriesChanged) {
      final matchedCategories = [
        for (final category in _knownCategories)
          if (_matchesIntention(category.name) &&
              !_suppressedCategoryTimeIds.contains(category.id))
            category,
      ];
      for (final category in matchedCategories) {
        _categoryTimeTargets.putIfAbsent(category.id, () => 1);
        _categoryTimeDirections.putIfAbsent(
          category.id,
          () => GoalDirection.atMost,
        );
      }
      _derivedCategoriesFingerprint = categoriesFingerprint;
    }

    setState(() {
      _validation = null;
      _step = _GoalFormStep.mapping;
    });
  }

  void _deriveTitle(List<HabitDefinition> habits) {
    final currentTitle = _title.text.trim();
    if (currentTitle.isNotEmpty && currentTitle != _derivedTitle) return;
    final selectedNames = [
      for (final habit in habits)
        if (_habitTargets.containsKey(habit.id)) habit.name,
    ];
    final derivedTitle = selectedNames.isNotEmpty
        ? selectedNames.join(' + ')
        : _watchesSteps
        ? context.messages.goalCreateTypeSteps
        : _statement.text.trim();
    _title.text = derivedTitle;
    _derivedTitle = derivedTitle;
  }

  void _continueToConfirmation(List<HabitDefinition> habits) {
    _reconcileHabitTargets();
    final hasMapping =
        !_mapping.isEditable ||
        _watchesSteps ||
        _habitTargets.isNotEmpty ||
        _measurableTargets.isNotEmpty ||
        _healthTargets.isNotEmpty ||
        _categoryTimeTargets.isNotEmpty;
    final stepsTarget = _parseLocalizedTarget(_stepsTarget.text);
    final invalidSteps =
        _watchesSteps && (stepsTarget == null || stepsTarget <= 0);
    final invalidHealthTargets = _healthTargets.values.any(
      (target) => target == null || target <= 0,
    );
    final invalidMeasurableTargets = _measurableTargets.values.any(
      (target) => target == null || target <= 0,
    );
    final invalidCategoryTimeTargets = _categoryTimeTargets.values.any(
      (target) => target == null || target <= 0,
    );
    if (!hasMapping ||
        invalidSteps ||
        invalidMeasurableTargets ||
        invalidCategoryTimeTargets ||
        invalidHealthTargets) {
      setState(() => _validation = context.messages.goalFormValidationMapping);
      return;
    }
    _deriveTitle(habits);
    setState(() {
      _validation = null;
      _step = _GoalFormStep.confirmation;
    });
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

  void _invalidateGoalViews(ProviderContainer container, String agentId) {
    container
      ..invalidate(agentIdentityProvider(agentId))
      ..invalidate(goalAgentHealthProvider(agentId))
      ..invalidate(goalAgentProgressViewProvider(agentId))
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
    final signals = <String>[
      if (_watchesSteps)
        context.messages.goalFormStepsCadence(
          NumberFormat.decimalPattern(
            context.messages.localeName,
          ).format(_parseLocalizedTarget(_stepsTarget.text) ?? 0),
        ),
      for (final entry in _habitTargets.entries)
        context.messages.goalFormHabitCadence(
          names[entry.key] ?? entry.key,
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
    ];
    return signals.join(' · ');
  }

  Future<void> _save() async {
    if (_saving) return;

    final messages = context.messages;
    final container = ProviderScope.containerOf(context, listen: false);
    final persona = _persona.text.trim();
    final statement = _statement.text.trim();
    if (persona.isEmpty) {
      setState(() => _validation = messages.goalFormValidationIdentity);
      return;
    }
    setState(() {
      _saving = true;
      _validation = null;
    });
    late final List<HabitDefinition> confirmedHabits;
    late final List<CategoryDefinition> confirmedCategories;
    try {
      confirmedHabits = await _reconcileHabitTargetsForSave();
      if (!mounted) return;
      confirmedCategories = await _reconcileCategoryTimeTargetsForSave();
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _validation = messages.goalCreateFailed;
        });
      }
      return;
    }
    if (!mounted) return;

    // Only refresh a title the form still owns. A manually changed (including
    // deliberately blank) title remains untouched, while an auto-derived
    // "Gym + Run" title follows integrity cleanup down to "Gym".
    if (_title.text.trim() == _derivedTitle) {
      final visibleHabits =
          ref.read(_habitDefinitionsProvider).value ?? _knownHabits;
      final visibleById = {
        for (final habit in visibleHabits) habit.id: habit,
      };
      _deriveTitle([
        for (final habit in confirmedHabits) visibleById[habit.id] ?? habit,
      ]);
    }
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() {
        _saving = false;
        _validation = messages.goalFormValidationIdentity;
      });
      return;
    }

    final stepsTarget = _parseLocalizedTarget(_stepsTarget.text);
    final criteria = _watchesSteps && (stepsTarget == null || stepsTarget <= 0)
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
            watchesSteps: _watchesSteps,
            stepsTarget: stepsTarget,
            compositeRule: _compositeRule,
            requiredSuccesses: _requiredSuccesses,
          );
    if (criteria == null) {
      setState(() {
        _saving = false;
        _validation = messages.goalFormValidationMapping;
      });
      return;
    }
    final goalAgentService = container.read(goalAgentServiceProvider);
    try {
      final agentId = widget.agentId;
      if (agentId == null) {
        await goalAgentService.createGoalAgent(
          title: title,
          displayName: persona,
          statement: statement,
          criteria: criteria,
        );
        container
          ..invalidate(activeGoalAgentsProvider)
          ..invalidate(activeGoalNudgesProvider);
        if (mounted) beamToNamed('/agents');
        return;
      }

      final revisionService = container.read(goalSpecRevisionServiceProvider);
      final outcome = await revisionService.reviseFromOwner(
        agentId: agentId,
        baseVersionId: _baseVersionId,
        displayName: persona,
        title: title,
        statement: statement,
        criteria: criteria,
      );
      if (outcome case GoalSpecRevisionMinted(:final version)) {
        goalAgentService.refreshAfterRevision(
          agentId: agentId,
          criteria: version.criteria,
        );
      } else if (outcome case GoalSpecRevisionRefused(
        :final reason,
      ) when reason == GoalSpecRevisionService.ownerStaleVersionReason) {
        _invalidateGoalViews(container, agentId);
        if (mounted) beamToNamed('/agents/details/$agentId');
        return;
      } else if (outcome case GoalSpecRevisionRefused(
        :final reason,
      ) when reason != GoalSpecRevisionService.ownerNoChangesReason) {
        throw StateError(reason);
      }
      _invalidateGoalViews(container, agentId);
      if (mounted) beamToNamed('/agents/details/$agentId');
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _validation = messages.goalCreateFailed;
        });
      }
    }
  }

  Future<List<CategoryDefinition>>
  _reconcileCategoryTimeTargetsForSave() async {
    final selectedCategoryIds = _categoryTimeTargets.keys.toList();
    final repository = ref.read(categoryRepositoryProvider);
    final resolvedCategories = await Future.wait([
      for (final categoryId in selectedCategoryIds)
        repository.getCategoryById(categoryId),
    ]);
    final confirmedCategories = <CategoryDefinition>[];
    for (final category in resolvedCategories) {
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

  void _back() {
    if (_saving) return;

    if (_step.index > _GoalFormStep.intention.index) {
      setState(() {
        _step = _GoalFormStep.values[_step.index - 1];
        _validation = null;
      });
      return;
    }
    final agentId = widget.agentId;
    beamToNamed(agentId == null ? '/agents' : '/agents/details/$agentId');
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;
    final habitsAsync = ref.watch(_habitDefinitionsProvider);
    final measurablesAsync = ref.watch(measurableDataTypesStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    if (habitsAsync.value case final loaded?) {
      _knownHabits = loaded;
    }
    final habits = habitsAsync.value ?? _knownHabits;
    if (measurablesAsync.value case final loaded?) {
      _knownMeasurables = loaded;
    }
    final measurables = measurablesAsync.value ?? _knownMeasurables;
    if (categoriesAsync.value case final loaded?) {
      _knownCategories = [
        for (final category in loaded)
          if (category.active && category.deletedAt == null) category,
      ];
    }
    final categories = _knownCategories;
    GoalSpecVersionEntity? editSpec;

    if (_editing) {
      final identityAsync = ref.watch(agentIdentityProvider(widget.agentId!));
      final healthAsync = ref.watch(goalAgentHealthProvider(widget.agentId!));
      final identity = identityAsync.value;
      editSpec = healthAsync.value?.spec;
      final isActiveGoal =
          identity is AgentIdentityEntity &&
          identity.kind == AgentKinds.goalAgent &&
          identity.lifecycle == AgentLifecycle.active;
      if (isActiveGoal && editSpec != null) {
        _initializeEdit(identity, editSpec);
      } else if (identityAsync.hasError ||
          healthAsync.hasError ||
          (identity != null && !isActiveGoal) ||
          (!identityAsync.isLoading && identity == null) ||
          (!healthAsync.isLoading && editSpec == null)) {
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: _back),
            title: Text(messages.goalFormEditTitle),
          ),
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step5),
              child: Text(
                messages.goalDetailHealthUnavailable,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      } else {
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: _back),
            title: Text(messages.goalFormEditTitle),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
    }

    final pageTitle = _editing
        ? messages.goalFormEditTitle
        : messages.agentsCreateGoal;
    return PopScope(
      canPop: _step == _GoalFormStep.intention,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final agentId = widget.agentId;
            beamToNamed(
              agentId == null ? '/agents' : '/agents/details/$agentId',
            );
          });
        } else {
          _back();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _saving ? null : _back),
          title: Text(pageTitle),
        ),
        body: SafeArea(
          child: DetailContentWidth(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: tokens.spacing.step4),
                  child: _StepProgress(step: _step),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      vertical: tokens.spacing.step5,
                    ),
                    children: [
                      switch (_step) {
                        _GoalFormStep.intention => _IntentionStep(
                          controller: _statement,
                          validation: _validation,
                          onExampleSelected: (example) {
                            setState(() {
                              _statement.text = example;
                              _validation = null;
                            });
                          },
                        ),
                        _GoalFormStep.mapping => _MappingStep(
                          habits: habits,
                          habitsFailed:
                              habitsAsync.hasError && habitsAsync.value == null,
                          mapping: _mapping,
                          measurables: measurables,
                          categories: categories,
                          measurableTargets: _measurableTargets,
                          healthTargets: _healthTargets,
                          healthDirections: _healthDirections,
                          categoryTimeTargets: _categoryTimeTargets,
                          categoryTimeDirections: _categoryTimeDirections,
                          compositeRule: _compositeRule,
                          requiredSuccesses: _requiredSuccesses,
                          habitTargets: _habitTargets,
                          watchesSteps: _watchesSteps,
                          stepsTarget: _stepsTarget,
                          showAllHabits: _showAllHabits,
                          validation: _validation,
                          onStepsChanged: (selected) => setState(() {
                            _watchesSteps = selected;
                            _validation = null;
                          }),
                          onHabitChanged:
                              ({required habitId, required selected}) =>
                                  setState(() {
                                    if (selected) {
                                      _habitTargets.putIfAbsent(
                                        habitId,
                                        () => 3,
                                      );
                                    } else {
                                      _habitTargets.remove(habitId);
                                    }
                                    _validation = null;
                                  }),
                          onTargetChanged: (habitId, target) => setState(() {
                            _habitTargets[habitId] = target;
                            _validation = null;
                          }),
                          onShowAll: () =>
                              setState(() => _showAllHabits = true),
                          onMeasurableChanged:
                              ({required measurableId, required selected}) =>
                                  setState(() {
                                    if (selected) {
                                      _measurableTargets.putIfAbsent(
                                        measurableId,
                                        () => 1,
                                      );
                                    } else {
                                      _measurableTargets.remove(measurableId);
                                    }
                                    _validation = null;
                                  }),
                          onMeasurableTargetChanged: (id, target) =>
                              setState(() {
                                _measurableTargets[id] = target;
                                _validation = null;
                              }),
                          onHealthSelected: (dataTypes) => setState(() {
                            for (final dataType in dataTypes) {
                              _healthTargets.putIfAbsent(dataType, () => null);
                              _healthDirections.putIfAbsent(
                                dataType,
                                () => GoalDirection.atMost,
                              );
                            }
                            _validation = null;
                          }),
                          onHealthRemoved: (dataType) => setState(() {
                            _healthTargets.remove(dataType);
                            _healthDirections.remove(dataType);
                            _validation = null;
                          }),
                          onHealthTargetChanged: (dataType, target) =>
                              setState(() {
                                _healthTargets[dataType] = target;
                                _validation = null;
                              }),
                          onHealthDirectionChanged: (dataType, direction) =>
                              setState(() {
                                _healthDirections[dataType] = direction;
                                _validation = null;
                              }),
                          onCategoryTimeSelected: (categoryId) => setState(() {
                            _suppressedCategoryTimeIds.remove(categoryId);
                            _categoryTimeTargets.putIfAbsent(
                              categoryId,
                              () => null,
                            );
                            _categoryTimeDirections.putIfAbsent(
                              categoryId,
                              () => GoalDirection.atMost,
                            );
                            _validation = null;
                          }),
                          onCategoryTimeRemoved: (categoryId) => setState(() {
                            _suppressedCategoryTimeIds.add(categoryId);
                            _categoryTimeTargets.remove(categoryId);
                            _categoryTimeDirections.remove(categoryId);
                            _validation = null;
                          }),
                          onCategoryTimeTargetChanged: (categoryId, target) =>
                              setState(() {
                                _categoryTimeTargets[categoryId] = target;
                                _validation = null;
                              }),
                          onCategoryTimeDirectionChanged:
                              (categoryId, direction) => setState(() {
                                _categoryTimeDirections[categoryId] = direction;
                                _validation = null;
                              }),
                          onCompositeRuleChanged: (rule, required) =>
                              setState(() {
                                _compositeRule = rule;
                                _requiredSuccesses = required;
                              }),
                        ),
                        _GoalFormStep.confirmation => _ConfirmationStep(
                          title: _title,
                          persona: _persona,
                          signalDescription: _signalDescription(habits),
                          preservesCriteria: !_mapping.isEditable,
                          editVersion: editSpec?.version,
                          validation: _validation,
                          enabled: !_saving,
                        ),
                      },
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        tokens.spacing.step4 +
                        DesignSystemBottomNavigationBar.occupiedHeight(context),
                  ),
                  child: DesignSystemButton(
                    key: const ValueKey('goal-form-primary-action'),
                    label: switch (_step) {
                      _GoalFormStep.intention => messages.goalFormContinue,
                      _GoalFormStep.mapping => messages.goalFormLooksRight,
                      _GoalFormStep.confirmation =>
                        _editing
                            ? messages.goalFormSaveChanges
                            : messages.goalCreateSaveButton,
                    },
                    onPressed: switch (_step) {
                      _GoalFormStep.intention => () => _mapIntention(habits),
                      _GoalFormStep.mapping => () => _continueToConfirmation(
                        habits,
                      ),
                      _GoalFormStep.confirmation => _save,
                    },
                    isLoading: _saving,
                    size: DesignSystemButtonSize.large,
                    fullWidth: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step});

  final _GoalFormStep step;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      label: context.messages.goalFormProgress(step.index + 1),
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final candidate in _GoalFormStep.values) ...[
              AnimatedContainer(
                duration: MotionDurations.short4,
                width: candidate == step
                    ? tokens.spacing.step5
                    : tokens.spacing.step2,
                height: tokens.spacing.step2,
                decoration: BoxDecoration(
                  color: candidate.index <= step.index
                      ? tokens.colors.interactive.enabled
                      : tokens.colors.decorative.level02,
                  borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
                ),
              ),
              if (candidate != _GoalFormStep.values.last)
                SizedBox(width: tokens.spacing.step2),
            ],
          ],
        ),
      ),
    );
  }
}

class _IntentionStep extends StatelessWidget {
  const _IntentionStep({
    required this.controller,
    required this.validation,
    required this.onExampleSelected,
  });

  final TextEditingController controller;
  final String? validation;
  final ValueChanged<String> onExampleSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final examples = [
      messages.goalFormExampleGym,
      messages.goalFormExampleWalk,
      messages.goalFormExampleRead,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          messages.goalFormIntentionPrompt,
          style: tokens.typography.styles.heading.heading3,
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          messages.goalFormIntentionHelper,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        DesignSystemTextarea(
          fieldKey: const ValueKey('goal-form-intention'),
          controller: controller,
          hintText: messages.goalFormIntentionHint,
          errorText: validation,
          minLines: 4,
          growWithContent: true,
        ),
        SizedBox(height: tokens.spacing.step4),
        Wrap(
          spacing: tokens.spacing.step2,
          runSpacing: tokens.spacing.step2,
          children: [
            for (final example in examples)
              DsPill(
                variant: DsPillVariant.filled,
                label: example,
                bordered: true,
                onTap: () => onExampleSelected(example),
              ),
          ],
        ),
      ],
    );
  }
}

String _healthDimensionName(BuildContext context, String dataType) =>
    switch (dataType) {
      GoalHealthDataTypes.weight => context.messages.goalFormHealthWeight,
      GoalHealthDataTypes.bloodPressureSystolic =>
        context.messages.goalFormHealthBloodPressureSystolic,
      GoalHealthDataTypes.bloodPressureDiastolic =>
        context.messages.goalFormHealthBloodPressureDiastolic,
      _ => dataType,
    };

String _healthDimensionUnit(String dataType) => switch (dataType) {
  GoalHealthDataTypes.weight => 'kg',
  GoalHealthDataTypes.bloodPressureSystolic ||
  GoalHealthDataTypes.bloodPressureDiastolic => 'mmHg',
  _ => '',
};

String _goalDirectionLabel(BuildContext context, GoalDirection direction) =>
    switch (direction) {
      GoalDirection.atLeast => context.messages.goalFormDirectionAtLeast,
      GoalDirection.atMost => context.messages.goalFormDirectionAtMost,
    };

class _MappingStep extends StatelessWidget {
  const _MappingStep({
    required this.habits,
    required this.habitsFailed,
    required this.mapping,
    required this.measurables,
    required this.categories,
    required this.measurableTargets,
    required this.healthTargets,
    required this.healthDirections,
    required this.categoryTimeTargets,
    required this.categoryTimeDirections,
    required this.compositeRule,
    required this.requiredSuccesses,
    required this.habitTargets,
    required this.watchesSteps,
    required this.stepsTarget,
    required this.showAllHabits,
    required this.validation,
    required this.onStepsChanged,
    required this.onHabitChanged,
    required this.onTargetChanged,
    required this.onShowAll,
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
    required this.onCompositeRuleChanged,
  });

  final List<HabitDefinition> habits;
  final bool habitsFailed;
  final GoalFormMapping mapping;
  final List<MeasurableDataType> measurables;
  final List<CategoryDefinition> categories;
  final Map<String, num?> measurableTargets;
  final Map<String, num?> healthTargets;
  final Map<String, GoalDirection> healthDirections;
  final Map<String, num?> categoryTimeTargets;
  final Map<String, GoalDirection> categoryTimeDirections;
  final GoalFormCompositeRule compositeRule;
  final int requiredSuccesses;
  final Map<String, int> habitTargets;
  final bool watchesSteps;
  final TextEditingController stepsTarget;
  final bool showAllHabits;
  final String? validation;
  final ValueChanged<bool> onStepsChanged;
  final void Function({required String habitId, required bool selected})
  onHabitChanged;
  final void Function(String habitId, int target) onTargetChanged;
  final VoidCallback onShowAll;
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
  final void Function(GoalFormCompositeRule rule, int requiredSuccesses)
  onCompositeRuleChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final habitsById = {for (final habit in habits) habit.id: habit};
    final selectedIds = habitTargets.keys.toSet();
    final visibleHabits = <({String id, String name})>[
      for (final id in selectedIds) (id: id, name: habitsById[id]?.name ?? id),
      if (showAllHabits)
        for (final habit in habits)
          if (!selectedIds.contains(habit.id)) (id: habit.id, name: habit.name),
    ];
    final noObservableMatch =
        mapping.isEditable &&
        !watchesSteps &&
        selectedIds.isEmpty &&
        measurableTargets.isEmpty &&
        healthTargets.isEmpty &&
        categoryTimeTargets.isEmpty;
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
    final dimensionCount =
        selectedIds.length +
        measurableTargets.length +
        healthTargets.length +
        categoryTimeTargets.length +
        (watchesSteps ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          if (watchesSteps || selectedIds.isNotEmpty || showAllHabits)
            DesignSystemSectionCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (!watchesSteps && showAllHabits)
                    DesignSystemSelectionRow(
                      key: const ValueKey('goal-form-steps-row'),
                      title: messages.goalCreateStepsTargetLabel,
                      subtitle: messages.goalFormStepsSignal,
                      type: DesignSystemSelectionRowType.multiSelect,
                      showSelectedBackground: false,
                      onTap: () => onStepsChanged(true),
                    ),
                  if (watchesSteps) ...[
                    DesignSystemSelectionRow(
                      key: const ValueKey('goal-form-steps-row'),
                      title: messages.goalCreateStepsTargetLabel,
                      subtitle: messages.goalFormStepsSignal,
                      type: DesignSystemSelectionRowType.multiSelect,
                      selected: true,
                      showSelectedBackground: false,
                      onTap: () => onStepsChanged(false),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        left: tokens.spacing.step5,
                        right: tokens.spacing.step5,
                        bottom: tokens.spacing.step4,
                      ),
                      child: DesignSystemTextInput(
                        key: const ValueKey('goal-form-steps-target'),
                        controller: stepsTarget,
                        label: messages.goalCreateStepsTargetLabel,
                        leadingIcon: Icons.directions_walk_rounded,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                  for (final habit in visibleHabits)
                    DesignSystemSelectionRow(
                      key: ValueKey('goal-form-habit-${habit.id}'),
                      title: habit.name,
                      subtitle: messages.goalFormHabitSignal,
                      titleMaxLines: 2,
                      type: DesignSystemSelectionRowType.multiSelect,
                      selected: selectedIds.contains(habit.id),
                      showSelectedBackground: false,
                      trailing: selectedIds.contains(habit.id)
                          ? _HabitTargetStepper(
                              habitId: habit.id,
                              value: habitTargets[habit.id]!,
                              onChanged: (value) =>
                                  onTargetChanged(habit.id, value),
                            )
                          : null,
                      onTap: () => onHabitChanged(
                        habitId: habit.id,
                        selected: !selectedIds.contains(habit.id),
                      ),
                    ),
                ],
              ),
            ),
          if (!showAllHabits) ...[
            SizedBox(height: tokens.spacing.step3),
            DesignSystemButton(
              label: messages.goalFormChooseHabit,
              onPressed: onShowAll,
              leadingIcon: Icons.add_rounded,
              variant: DesignSystemButtonVariant.secondary,
              size: DesignSystemButtonSize.medium,
              fullWidth: true,
            ),
          ],
          for (final measurable in selectedMeasurables) ...[
            SizedBox(height: tokens.spacing.step3),
            DesignSystemSectionCard(
              key: ValueKey('goal-form-measurable-card-${measurable.id}'),
              child: Row(
                children: [
                  Icon(
                    Icons.straighten_rounded,
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
                  _MeasurableTargetInput(
                    measurableId: measurable.id,
                    value: measurableTargets[measurable.id],
                    unitName: measurable.unitName,
                    onChanged: (value) =>
                        onMeasurableTargetChanged(measurable.id, value),
                  ),
                  DesignSystemIconAction(
                    icon: Icons.close_rounded,
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
          for (final entry in healthTargets.entries) ...[
            SizedBox(height: tokens.spacing.step3),
            _HealthTargetCard(
              key: ValueKey('goal-form-health-card-${entry.key}'),
              dataType: entry.key,
              value: entry.value,
              direction: healthDirections[entry.key] ?? GoalDirection.atMost,
              onTargetChanged: (target) =>
                  onHealthTargetChanged(entry.key, target),
              onDirectionChanged: (direction) =>
                  onHealthDirectionChanged(entry.key, direction),
              onRemove: () => onHealthRemoved(entry.key),
            ),
          ],
          for (final category in selectedCategories) ...[
            SizedBox(height: tokens.spacing.step3),
            _CategoryTimeTargetCard(
              key: ValueKey('goal-form-category-time-card-${category.id}'),
              categoryId: category.id,
              categoryName: category.name,
              value: categoryTimeTargets[category.id],
              direction:
                  categoryTimeDirections[category.id] ?? GoalDirection.atMost,
              onTargetChanged: (target) =>
                  onCategoryTimeTargetChanged(category.id, target),
              onDirectionChanged: (direction) =>
                  onCategoryTimeDirectionChanged(category.id, direction),
              onRemove: () => onCategoryTimeRemoved(category.id),
            ),
          ],
          SizedBox(height: tokens.spacing.step3),
          DesignSystemButton(
            label: context.messages.goalFormAddDimension,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => _DimensionSourcePicker(
                measurables: measurables,
                categories: categories,
                selectedMeasurableIds: measurableTargets.keys.toSet(),
                selectedHealthDataTypes: healthTargets.keys.toSet(),
                selectedCategoryIds: categoryTimeTargets.keys.toSet(),
                onMeasurableSelected: (id) {
                  Navigator.of(context).pop();
                  onMeasurableChanged(measurableId: id, selected: true);
                },
                onHealthSelected: (dataTypes) {
                  Navigator.of(context).pop();
                  onHealthSelected(dataTypes);
                },
                onCategorySelected: (categoryId) {
                  Navigator.of(context).pop();
                  onCategoryTimeSelected(categoryId);
                },
              ),
            ),
            leadingIcon: Icons.add_rounded,
            variant: DesignSystemButtonVariant.secondary,
            fullWidth: true,
          ),
          if (dimensionCount > 1) ...[
            SizedBox(height: tokens.spacing.step4),
            DesignSystemSectionCard(
              child: Row(
                children: [
                  Icon(
                    Icons.account_tree_outlined,
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
                            requiredSuccesses,
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
                        onChanged: (rule, required) {
                          Navigator.of(context).pop();
                          onCompositeRuleChanged(rule, required);
                        },
                      ),
                    ),
                    variant: DesignSystemButtonVariant.tertiary,
                    size: DesignSystemButtonSize.dense,
                  ),
                ],
              ),
            ),
          ],
          if (showAllHabits && habits.isEmpty) ...[
            SizedBox(height: tokens.spacing.step3),
            Text(
              habitsFailed
                  ? messages.goalCreateHabitsLoadFailed
                  : messages.goalFormNoHabits,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            DesignSystemButton(
              label: messages.goalFormOpenHabits,
              onPressed: () => beamToNamed('/habits'),
              variant: DesignSystemButtonVariant.secondary,
              fullWidth: true,
            ),
          ],
          SizedBox(height: tokens.spacing.step4),
          DesignSystemSectionCard(
            padding: EdgeInsets.all(tokens.spacing.step4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.calendar_view_week_rounded,
                  color: tokens.colors.interactive.enabled,
                ),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Text(
                    messages.goalFormRollingNote,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ),
              ],
            ),
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
        if (validation != null) ...[
          SizedBox(height: tokens.spacing.step3),
          Text(
            validation!,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.alert.error.defaultColor,
            ),
          ),
        ],
      ],
    );
  }
}

String _compositeRuleLabel(
  BuildContext context,
  GoalFormCompositeRule rule,
  int requiredSuccesses,
  int dimensionCount,
) => switch (rule) {
  GoalFormCompositeRule.all => context.messages.goalFormCompositeAll,
  GoalFormCompositeRule.any => context.messages.goalFormCompositeAny,
  GoalFormCompositeRule.atLeast => context.messages.goalFormCompositeAtLeast(
    requiredSuccesses,
    dimensionCount,
  ),
};

class _MeasurableTargetInput extends StatefulWidget {
  const _MeasurableTargetInput({
    required this.measurableId,
    required this.value,
    required this.unitName,
    required this.onChanged,
  });

  final String measurableId;
  final num? value;
  final String unitName;
  final ValueChanged<num?> onChanged;

  @override
  State<_MeasurableTargetInput> createState() => _MeasurableTargetInputState();
}

class _MeasurableTargetInputState extends State<_MeasurableTargetInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SizedBox(
      width: tokens.spacing.step13 * 2,
      child: DesignSystemTextInput(
        key: ValueKey('goal-form-measurable-target-${widget.measurableId}'),
        controller: _controller,
        label: widget.unitName,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (raw) {
          final value = num.tryParse(raw.replaceAll(',', '.'));
          widget.onChanged(value);
        },
      ),
    );
  }
}

class _HealthTargetCard extends StatelessWidget {
  const _HealthTargetCard({
    required this.dataType,
    required this.value,
    required this.direction,
    required this.onTargetChanged,
    required this.onDirectionChanged,
    required this.onRemove,
    super.key,
  });

  final String dataType;
  final num? value;
  final GoalDirection direction;
  final ValueChanged<num?> onTargetChanged;
  final ValueChanged<GoalDirection> onDirectionChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final unit = _healthDimensionUnit(dataType);
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.monitor_heart_outlined,
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
                      _healthDimensionName(context, dataType),
                      style: tokens.typography.styles.subtitle.subtitle2,
                    ),
                    Text(
                      context.messages.goalFormHealthSource(unit),
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
              DesignSystemIconAction(
                icon: Icons.close_rounded,
                tooltip: context.messages.aiCardProposalKindRemove,
                onPressed: onRemove,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          DsSegmentedToggle<GoalDirection>(
            key: ValueKey('goal-form-health-direction-$dataType'),
            segments: [
              DsSegment(
                GoalDirection.atMost,
                context.messages.goalFormDirectionAtMost,
              ),
              DsSegment(
                GoalDirection.atLeast,
                context.messages.goalFormDirectionAtLeast,
              ),
            ],
            selected: direction,
            onChanged: onDirectionChanged,
            expand: true,
          ),
          SizedBox(height: tokens.spacing.step3),
          _HealthTargetInput(
            dataType: dataType,
            value: value,
            unit: unit,
            onChanged: onTargetChanged,
          ),
        ],
      ),
    );
  }
}

class _HealthTargetInput extends StatefulWidget {
  const _HealthTargetInput({
    required this.dataType,
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  final String dataType;
  final num? value;
  final String unit;
  final ValueChanged<num?> onChanged;

  @override
  State<_HealthTargetInput> createState() => _HealthTargetInputState();
}

class _HealthTargetInputState extends State<_HealthTargetInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DesignSystemTextInput(
    key: ValueKey('goal-form-health-target-${widget.dataType}'),
    controller: _controller,
    label: context.messages.goalFormHealthTarget(widget.unit),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (raw) => widget.onChanged(
      num.tryParse(raw.trim().replaceAll(',', '.')),
    ),
  );
}

class _CategoryTimeTargetCard extends StatelessWidget {
  const _CategoryTimeTargetCard({
    required this.categoryId,
    required this.categoryName,
    required this.value,
    required this.direction,
    required this.onTargetChanged,
    required this.onDirectionChanged,
    required this.onRemove,
    super.key,
  });

  final String categoryId;
  final String categoryName;
  final num? value;
  final GoalDirection direction;
  final ValueChanged<num?> onTargetChanged;
  final ValueChanged<GoalDirection> onDirectionChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                color: tokens.colors.alert.warning.defaultColor,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName,
                      style: tokens.typography.styles.subtitle.subtitle2,
                    ),
                    Text(
                      context.messages.goalFormCategoryTimeSource,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
              DesignSystemIconAction(
                icon: Icons.close_rounded,
                tooltip: context.messages.aiCardProposalKindRemove,
                onPressed: onRemove,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          DsSegmentedToggle<GoalDirection>(
            key: ValueKey('goal-form-category-time-direction-$categoryId'),
            segments: [
              DsSegment(
                GoalDirection.atMost,
                context.messages.goalFormDirectionAtMost,
              ),
              DsSegment(
                GoalDirection.atLeast,
                context.messages.goalFormDirectionAtLeast,
              ),
            ],
            selected: direction,
            onChanged: onDirectionChanged,
            expand: true,
          ),
          SizedBox(height: tokens.spacing.step3),
          _CategoryTimeTargetInput(
            categoryId: categoryId,
            value: value,
            onChanged: onTargetChanged,
          ),
        ],
      ),
    );
  }
}

class _CategoryTimeTargetInput extends StatefulWidget {
  const _CategoryTimeTargetInput({
    required this.categoryId,
    required this.value,
    required this.onChanged,
  });

  final String categoryId;
  final num? value;
  final ValueChanged<num?> onChanged;

  @override
  State<_CategoryTimeTargetInput> createState() =>
      _CategoryTimeTargetInputState();
}

class _CategoryTimeTargetInputState extends State<_CategoryTimeTargetInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DesignSystemTextInput(
    key: ValueKey('goal-form-category-time-target-${widget.categoryId}'),
    controller: _controller,
    label: context.messages.goalFormCategoryTimeTarget,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (raw) => widget.onChanged(
      num.tryParse(raw.trim().replaceAll(',', '.')),
    ),
  );
}

class _DimensionSourcePicker extends StatefulWidget {
  const _DimensionSourcePicker({
    required this.measurables,
    required this.categories,
    required this.selectedMeasurableIds,
    required this.selectedHealthDataTypes,
    required this.selectedCategoryIds,
    required this.onMeasurableSelected,
    required this.onHealthSelected,
    required this.onCategorySelected,
  });

  final List<MeasurableDataType> measurables;
  final List<CategoryDefinition> categories;
  final Set<String> selectedMeasurableIds;
  final Set<String> selectedHealthDataTypes;
  final Set<String> selectedCategoryIds;
  final ValueChanged<String> onMeasurableSelected;
  final ValueChanged<List<String>> onHealthSelected;
  final ValueChanged<String> onCategorySelected;

  @override
  State<_DimensionSourcePicker> createState() => _DimensionSourcePickerState();
}

class _DimensionSourcePickerState extends State<_DimensionSourcePicker> {
  final _search = TextEditingController();
  var _query = '';

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
    final visible = widget.measurables.where((measurable) {
      return query.isEmpty ||
          measurable.displayName.toLowerCase().contains(query) ||
          measurable.unitName.toLowerCase().contains(query);
    }).toList();
    final visibleCategories = widget.categories.where((category) {
      return query.isEmpty || category.name.toLowerCase().contains(query);
    }).toList();
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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              messages.goalFormAddDimension,
              style: tokens.typography.styles.heading.heading3,
            ),
            SizedBox(height: tokens.spacing.step3),
            DesignSystemTextInput(
              controller: _search,
              hintText: context.messages.searchHint,
              leadingIcon: Icons.search_rounded,
              onChanged: (value) => setState(() => _query = value),
            ),
            SizedBox(height: tokens.spacing.step3),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (showsHealth) ...[
                    Text(
                      messages.goalFormHealthData,
                      style: tokens.typography.styles.subtitle.subtitle2,
                    ),
                    SizedBox(height: tokens.spacing.step2),
                    if (weightMatches)
                      DesignSystemSelectionRow(
                        key: const ValueKey(
                          'goal-form-health-source-weight',
                        ),
                        title: messages.goalFormHealthWeight,
                        subtitle: messages.goalFormHealthSource('kg'),
                        selected: widget.selectedHealthDataTypes.contains(
                          GoalHealthDataTypes.weight,
                        ),
                        type: DesignSystemSelectionRowType.singleSelect,
                        onTap:
                            widget.selectedHealthDataTypes.contains(
                              GoalHealthDataTypes.weight,
                            )
                            ? null
                            : () => widget.onHealthSelected(
                                const [GoalHealthDataTypes.weight],
                              ),
                      ),
                    if (bloodPressureMatches)
                      DesignSystemSelectionRow(
                        key: const ValueKey(
                          'goal-form-health-source-blood-pressure',
                        ),
                        title: messages.dashboardHealthBloodPressure,
                        subtitle: messages.goalFormBloodPressureSource,
                        selected: bloodPressureTypes.every(
                          widget.selectedHealthDataTypes.contains,
                        ),
                        type: DesignSystemSelectionRowType.singleSelect,
                        onTap:
                            bloodPressureTypes.every(
                              widget.selectedHealthDataTypes.contains,
                            )
                            ? null
                            : () => widget.onHealthSelected(
                                bloodPressureTypes,
                              ),
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
                        selected: widget.selectedCategoryIds.contains(
                          category.id,
                        ),
                        type: DesignSystemSelectionRowType.singleSelect,
                        onTap: widget.selectedCategoryIds.contains(category.id)
                            ? null
                            : () => widget.onCategorySelected(category.id),
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
                      selected: widget.selectedMeasurableIds.contains(
                        measurable.id,
                      ),
                      type: DesignSystemSelectionRowType.singleSelect,
                      onTap:
                          widget.selectedMeasurableIds.contains(measurable.id)
                          ? null
                          : () => widget.onMeasurableSelected(measurable.id),
                    ),
                  if (visible.isEmpty && query.isEmpty)
                    DesignSystemButton(
                      label: context.messages.settingsMeasurablesCreateTitle,
                      leadingIcon: Icons.add_rounded,
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
          ],
        ),
      ),
    );
  }
}

class _CompositeRulePicker extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final required = requiredSuccesses.clamp(1, dimensionCount);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.messages.goalFormCompositeRule,
              style: tokens.typography.styles.heading.heading3,
            ),
            SizedBox(height: tokens.spacing.step3),
            for (final rule in GoalFormCompositeRule.values)
              DesignSystemSelectionRow(
                title: _compositeRuleLabel(
                  context,
                  rule,
                  required,
                  dimensionCount,
                ),
                subtitle: switch (rule) {
                  GoalFormCompositeRule.all =>
                    context.messages.goalFormCompositeAllHint,
                  GoalFormCompositeRule.any =>
                    context.messages.goalFormCompositeAnyHint,
                  GoalFormCompositeRule.atLeast =>
                    context.messages.goalFormCompositeAtLeastHint,
                },
                selected: value == rule,
                type: DesignSystemSelectionRowType.singleSelect,
                trailing: rule == GoalFormCompositeRule.atLeast
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DesignSystemIconAction(
                            icon: Icons.remove_rounded,
                            tooltip: context.messages.goalFormDecreaseTarget,
                            onPressed: required > 1
                                ? () => onChanged(rule, required - 1)
                                : null,
                          ),
                          Text(
                            '$required / $dimensionCount',
                            style: tokens.typography.styles.subtitle.subtitle2,
                          ),
                          DesignSystemIconAction(
                            icon: Icons.add_rounded,
                            tooltip: context.messages.goalFormIncreaseTarget,
                            onPressed: required < dimensionCount
                                ? () => onChanged(rule, required + 1)
                                : null,
                          ),
                        ],
                      )
                    : null,
                onTap: () => onChanged(rule, required),
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
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DesignSystemIconAction(
          key: ValueKey('goal-form-decrease-$habitId'),
          icon: Icons.remove_rounded,
          tooltip: context.messages.goalFormDecreaseTarget,
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        Text(
          context.messages.goalFormWeeklyTarget(value),
          style: tokens.typography.styles.subtitle.subtitle2,
        ),
        DesignSystemIconAction(
          key: ValueKey('goal-form-increase-$habitId'),
          icon: Icons.add_rounded,
          tooltip: context.messages.goalFormIncreaseTarget,
          onPressed: value < 7 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _ConfirmationStep extends StatelessWidget {
  const _ConfirmationStep({
    required this.title,
    required this.persona,
    required this.signalDescription,
    required this.preservesCriteria,
    required this.editVersion,
    required this.validation,
    required this.enabled,
  });

  final TextEditingController title;
  final TextEditingController persona;
  final String signalDescription;
  final bool preservesCriteria;
  final int? editVersion;
  final String? validation;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          messages.goalFormConfirmTitle,
          style: tokens.typography.styles.heading.heading3,
        ),
        SizedBox(height: tokens.spacing.step5),
        DesignSystemTextInput(
          key: const ValueKey('goal-form-persona'),
          controller: persona,
          label: messages.goalFormPersonaLabel,
          leadingIcon: Icons.auto_awesome_rounded,
          enabled: enabled,
        ),
        SizedBox(height: tokens.spacing.step4),
        DesignSystemTextInput(
          key: const ValueKey('goal-form-title'),
          controller: title,
          label: messages.goalCreateNameLabel,
          leadingIcon: Icons.flag_outlined,
          errorText: validation,
          enabled: enabled,
        ),
        SizedBox(height: tokens.spacing.step5),
        DesignSystemSectionCard(
          child: Text(
            preservesCriteria
                ? messages.goalFormPreservedCriteriaSummary
                : messages.goalFormRestatement(signalDescription),
            style: tokens.typography.styles.body.bodyLarge,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        DesignSystemSectionCard(
          padding: EdgeInsets.all(tokens.spacing.step4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.eco_outlined,
                color: tokens.colors.interactive.enabled,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  messages.goalFormCostHonesty,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (editVersion != null) ...[
          SizedBox(height: tokens.spacing.step4),
          Text(
            messages.goalFormEditVersion(editVersion! + 1),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
        SizedBox(height: tokens.spacing.step4),
        Text(
          messages.goalFormFooter,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ],
    );
  }
}

final StreamProvider<List<HabitDefinition>> _habitDefinitionsProvider =
    StreamProvider.autoDispose<List<HabitDefinition>>(
      (ref) => ref
          .watch(habitsRepositoryProvider)
          .watchHabitDefinitions()
          .map(
            (habits) => [
              for (final habit in habits)
                if (habit.active) habit,
            ],
          ),
      name: 'goalCreateHabitDefinitionsProvider',
    );
