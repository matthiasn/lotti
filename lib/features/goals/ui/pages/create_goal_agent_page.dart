import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/dashboards/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/steppers/design_system_stepper.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/service/goal_spec_revision_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/pages/goal_form_mapping.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/goal_routes.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:material_ui/material_ui.dart';

part 'create_goal_agent_mapping_step_part.dart';
part 'create_goal_agent_pickers_part.dart';
part 'create_goal_agent_steps_part.dart';
part 'create_goal_agent_target_inputs_part.dart';
part 'create_goal_agent_page_composite_rule_label_part.dart';
part 'create_goal_agent_page_internals.dart';
part 'create_goal_agent_page_form_helpers.dart';

class _CreateGoalAgentPageState extends ConsumerState<CreateGoalAgentPage> {
  final _statement = TextEditingController();
  final _title = TextEditingController();
  final _persona = TextEditingController();
  final _stepsTarget = TextEditingController(text: '10000');
  late _GoalFormStep _step = _visibleSteps.first;
  var _mapping = const GoalFormMapping.empty();
  final _habitTargets = <String, int>{};
  final _measurableTargets = <String, num?>{};
  final _healthTargets = <String, num?>{};
  final _healthDirections = <String, GoalDirection>{};
  final _categoryTimeTargets = <String, num?>{};
  final _categoryTimeDirections = <String, GoalDirection>{};
  final _labelTimeTargets = <String, num?>{};
  final _labelTimeDirections = <String, GoalDirection>{};
  final _labelTimeCategoryIds = <String, String?>{};
  final _suppressedCategoryTimeIds = <String>{};
  final _suppressedLabelTimeIds = <String>{};

  /// Health signals the user explicitly deselected: an intention re-map may
  /// still surface them as suggestions, but never re-seeds them selected.
  final _suppressedHealthTypes = <String>{};
  List<HabitDefinition> _knownHabits = const [];
  List<MeasurableDataType> _knownMeasurables = const [];
  final _knownChoiceMeasurableIds = <String>{};
  List<CategoryDefinition> _knownCategories = const [];
  List<LabelDefinition> _knownLabels = const [];
  var _measurableDefinitionsLoaded = false;
  var _watchesSteps = false;
  GoalFormCompositeRule _compositeRule = GoalFormCompositeRule.all;
  var _requiredSuccesses = 1;
  final Set<String> _matchedHabitIds = {};
  final Set<String> _matchedHealthTypes = {};

  /// Cadences a deselected habit had, restored on re-check so a micro-slip
  /// never costs the user a value they already shaped.
  final _rememberedHabitTargets = <String, int>{};

  /// Mapping entities whose target failed validation, keyed
  /// `steps` / `health:{type}` / `measurable:{id}` / `category:{id}`.
  final _targetErrors = <String>{};

  /// The signals card's row order, frozen on each entry to the mapping step
  /// so a tapped row stays under the user's finger — regrouping happens on
  /// re-entry, never mid-interaction. Descriptors: `habit:{id}`,
  /// `blood-pressure`, `weight`, `steps`.
  var _chosenSignalOrder = <String>[];
  var _suggestedSignalOrder = <String>[];
  final _errorAnchors = <String, GlobalKey>{};
  String? _personaError;
  String? _titleError;
  String? _statementError;
  var _initialized = false;
  var _defaultPersonaInitialized = false;
  var _saving = false;
  String? _derivedFrom;
  String? _derivedTitle;
  String? _derivedHabitsFingerprint;
  String? _derivedCategoriesFingerprint;
  String? _derivedLabelsFingerprint;
  late String _baseVersionId;
  String? _validation;

  bool get _editing => widget.agentId != null;

  /// The wizard as the user actually walks it. Editing has no separate
  /// intention page — the statement is one field on the mapping page — so the
  /// edit flow is two steps where creation is three.
  List<_GoalFormStep> get _visibleSteps => _editing
      ? const [_GoalFormStep.mapping, _GoalFormStep.confirmation]
      : _GoalFormStep.values;

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
    final labelsAsync = ref.read(labelsStreamProvider);
    final labelsFingerprint = labelsAsync.hasError || labelsAsync.value == null
        ? null
        : _labelsFingerprint(_knownLabels);
    final labelsChanged =
        labelsFingerprint != null &&
        labelsFingerprint != _derivedLabelsFingerprint;
    final requiresFullRemap = _derivedFrom != statement || habitsChanged;
    if (!_editing && requiresFullRemap) {
      // ADDITIVE re-derive: a back-edit of the intention adds newly matched
      // signals but never clears targets the user already shaped — silent
      // full remaps destroyed cadences and selections.
      final matchedHabits = [
        for (final habit in habits)
          if (_matchesIntention(habit.name)) habit,
      ];
      _matchedHabitIds
        ..clear()
        ..addAll(matchedHabits.map((habit) => habit.id));
      final stepsLabel = context.messages.goalCreateStepsTargetLabel;
      _watchesSteps = _watchesSteps || _matchesIntention(stepsLabel);
      // Health capabilities match the intention the same way habits do, so
      // "keep my blood pressure under control" surfaces blood pressure as an
      // offer row instead of hiding it behind the picker.
      final messages = context.messages;
      _matchedHealthTypes.clear();
      if (_matchesIntention(messages.goalFormHealthWeight)) {
        _matchedHealthTypes.add(GoalHealthDataTypes.weight);
      }
      if (_matchesIntention(messages.dashboardHealthBloodPressure) ||
          _matchesIntention(messages.goalFormHealthBloodPressureSystolic)) {
        _matchedHealthTypes
          ..add(GoalHealthDataTypes.bloodPressureSystolic)
          ..add(GoalHealthDataTypes.bloodPressureDiastolic);
      }
      // The substance arrives selected: a blood-pressure intention watches
      // blood-pressure readings from the first render, not a checkbox —
      // unless the user already deselected it once; an explicit choice
      // survives intention back-edits as an unchecked suggestion.
      for (final dataType in _matchedHealthTypes) {
        if (_suppressedHealthTypes.contains(dataType)) continue;
        _healthTargets.putIfAbsent(
          dataType,
          () => _defaultHealthTarget(dataType),
        );
        _healthDirections.putIfAbsent(dataType, () => GoalDirection.atMost);
      }
      for (final habit in matchedHabits) {
        // A habit that merely names a matched health capability is its
        // bookkeeping twin: it stays visible as the unchecked sibling while
        // the readings signal carries the goal.
        if (!_overlapsMatchedHealthLabel(habit.name)) {
          _habitTargets.putIfAbsent(habit.id, () => 3);
        }
      }
      for (final measurable in _knownMeasurables) {
        if (_matchesIntention(measurable.displayName)) {
          _measurableTargets.putIfAbsent(measurable.id, () => 1);
        }
      }
      for (final category in _knownCategories) {
        if (_matchesIntention(category.name) &&
            !_suppressedCategoryTimeIds.contains(category.id)) {
          _categoryTimeTargets.putIfAbsent(category.id, () => 1);
          _categoryTimeDirections.putIfAbsent(
            category.id,
            () => GoalDirection.atMost,
          );
        }
      }
      for (final label in _knownLabels) {
        if (_matchesIntention(label.name) &&
            !_suppressedLabelTimeIds.contains(label.id)) {
          _labelTimeTargets.putIfAbsent(label.id, () => 1);
          _labelTimeDirections.putIfAbsent(
            label.id,
            () => GoalDirection.atLeast,
          );
        }
      }
      _deriveTitle(habits);
      _derivedFrom = statement;
      if (habitsFingerprint != null) {
        _derivedHabitsFingerprint = habitsFingerprint;
      }
      if (categoriesFingerprint != null) {
        _derivedCategoriesFingerprint = categoriesFingerprint;
      }
      if (labelsFingerprint != null) {
        _derivedLabelsFingerprint = labelsFingerprint;
      }
    } else if (!_editing && (categoriesChanged || labelsChanged)) {
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
      if (categoriesChanged) {
        _derivedCategoriesFingerprint = categoriesFingerprint;
      }
      if (labelsChanged) {
        for (final label in _knownLabels) {
          if (_matchesIntention(label.name) &&
              !_suppressedLabelTimeIds.contains(label.id)) {
            _labelTimeTargets.putIfAbsent(label.id, () => 1);
            _labelTimeDirections.putIfAbsent(
              label.id,
              () => GoalDirection.atLeast,
            );
          }
        }
        _derivedLabelsFingerprint = labelsFingerprint;
      }
    }

    _snapshotSignalGroups();
    setState(() {
      _validation = null;
      _targetErrors.clear();
      _step = _GoalFormStep.mapping;
    });
  }

  /// A habit name without its emoji decorations: the derived goal title is
  /// prose identity, and a red heart must not be the flow's loudest pixel.
  static String _plainName(String name) => name
      .replaceAll(
        RegExp(
          r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]',
          unicode: true,
        ),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// A picked health signal starts from a sensible default target instead of
  /// an empty value the form would reject one step later.
  static num? _defaultHealthTarget(String dataType) => switch (dataType) {
    GoalHealthDataTypes.bloodPressureSystolic => 130,
    GoalHealthDataTypes.bloodPressureDiastolic => 80,
    _ => null,
  };

  void _continueToConfirmation(List<HabitDefinition> habits) {
    // Editing carries the statement field on this page, so the emptiness
    // check the intention step performs for creation happens here.
    if (_editing && _statement.text.trim().isEmpty) {
      setState(
        () => _statementError = context.messages.goalFormValidationIntention,
      );
      return;
    }
    _reconcileHabitTargets();
    final hasMapping =
        !_mapping.isEditable ||
        _watchesSteps ||
        _habitTargets.isNotEmpty ||
        _measurableTargets.isNotEmpty ||
        _healthTargets.isNotEmpty ||
        _categoryTimeTargets.isNotEmpty ||
        _labelTimeTargets.isNotEmpty;
    final stepsTarget = _parseLocalizedTarget(_stepsTarget.text);
    final invalidKeys = <String>{
      if (_watchesSteps && (stepsTarget == null || stepsTarget <= 0)) 'steps',
      for (final entry in _healthTargets.entries)
        if (entry.value == null || entry.value! <= 0) 'health:${entry.key}',
      for (final entry in _measurableTargets.entries)
        if (entry.value == null || entry.value! <= 0) 'measurable:${entry.key}',
      for (final entry in _categoryTimeTargets.entries)
        if (entry.value == null || entry.value! <= 0) 'category:${entry.key}',
      for (final entry in _labelTimeTargets.entries)
        if (entry.value == null || entry.value! <= 0) 'label:${entry.key}',
    };
    if (!hasMapping || invalidKeys.isNotEmpty) {
      // Each missing target errors on its own card; the generic message is
      // reserved for a form with nothing mapped at all.
      setState(() {
        _targetErrors
          ..clear()
          ..addAll(invalidKeys);
        _validation = invalidKeys.isEmpty
            ? context.messages.goalFormValidationMapping
            : null;
      });
      _revealFirstTargetError();
      return;
    }
    _deriveTitle(habits);
    setState(() {
      _validation = null;
      _targetErrors.clear();
      _step = _GoalFormStep.confirmation;
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    final messages = context.messages;
    final container = ProviderScope.containerOf(context, listen: false);
    final persona = _persona.text.trim();
    final statement = _statement.text.trim();
    if (persona.isEmpty) {
      setState(() => _personaError = messages.goalFormValidationPersona);
      return;
    }
    setState(() {
      _saving = true;
      _validation = null;
      _targetErrors.clear();
      _personaError = null;
      _titleError = null;
    });
    late final List<HabitDefinition> confirmedHabits;
    late final List<CategoryDefinition> confirmedCategories;
    try {
      confirmedHabits = await _reconcileHabitTargetsForSave();
      if (!mounted) return;
      confirmedCategories = await _reconcileCategoryTimeTargetsForSave();
      if (!mounted) return;
      await _reconcileMeasurableTargetsForSave();
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
        _titleError = messages.goalFormValidationTitle;
      });
      return;
    }

    final criteria = _buildFormCriteria(confirmedCategories);
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
        if (mounted) beamToNamed(goalsRootPath);
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
        if (mounted) beamToNamed(goalDetailPath(agentId));
        return;
      } else if (outcome case GoalSpecRevisionRefused(
        :final reason,
      ) when reason != GoalSpecRevisionService.ownerNoChangesReason) {
        throw StateError(reason);
      }
      _invalidateGoalViews(container, agentId);
      if (mounted) beamToNamed(goalDetailPath(agentId));
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _validation = messages.goalCreateFailed;
        });
      }
    }
  }

  void _back() {
    if (_saving) return;

    final steps = _visibleSteps;
    final index = steps.indexOf(_step);
    if (index > 0) {
      final target = steps[index - 1];
      if (target == _GoalFormStep.mapping) _snapshotSignalGroups();
      setState(() {
        _step = target;
        _validation = null;
        _targetErrors.clear();
      });
      return;
    }
    final agentId = widget.agentId;
    beamToNamed(
      agentId == null ? goalsRootPath : goalDetailPath(agentId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;
    final habitsAsync = ref.watch(_habitDefinitionsProvider);
    final measurablesAsync = ref.watch(measurableDataTypesStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final labelsAsync = ref.watch(labelsStreamProvider);
    if (habitsAsync.value case final loaded?) {
      _knownHabits = loaded;
    }
    final habits = habitsAsync.value ?? _knownHabits;
    if (measurablesAsync.value case final loaded?) {
      // A goal criterion on a measurable is a numeric target; a choice
      // measurable has no quantity to target, so it is not on offer here.
      _rememberMeasurableDefinitions(loaded);
    }
    final measurables = _knownMeasurables;
    if (categoriesAsync.value case final loaded?) {
      _knownCategories = [
        for (final category in loaded)
          if (category.active && category.deletedAt == null) category,
      ];
    }
    final categories = _knownCategories;
    if (labelsAsync.value case final loaded?) {
      _knownLabels = [
        for (final label in loaded)
          if (label.deletedAt == null) label,
      ];
    }
    final labels = _knownLabels;
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

    _removeChoiceMeasurableTargets(_knownChoiceMeasurableIds);

    final pageTitle = _editing
        ? messages.goalFormEditTitle
        : messages.agentsCreateGoal;
    final primaryAction = DesignSystemButton(
      key: const ValueKey('goal-form-primary-action'),
      label: switch (_step) {
        _GoalFormStep.intention => messages.goalFormContinue,
        _GoalFormStep.mapping => messages.goalFormContinue,
        _GoalFormStep.confirmation =>
          _editing
              ? messages.goalFormSaveChanges
              : messages.goalCreateSaveButton,
      },
      onPressed: switch (_step) {
        _GoalFormStep.intention => () => _mapIntention(habits),
        _GoalFormStep.mapping => () => _continueToConfirmation(habits),
        _GoalFormStep.confirmation => _save,
      },
      isLoading: _saving,
      size: DesignSystemButtonSize.large,
      fullWidth: true,
    );
    return PopScope(
      canPop: _step == _visibleSteps.first,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final agentId = widget.agentId;
            beamToNamed(
              agentId == null ? goalsRootPath : goalDetailPath(agentId),
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
            // A form is a reading column, not a pane: cap it at the
            // action-list measure so desktop stops stretching rows and the
            // CTA across a void.
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: kActionListContentMaxWidth,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: tokens.spacing.step4),
                      child: _StepProgress(steps: _visibleSteps, step: _step),
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
                                  _targetErrors.clear();
                                });
                              },
                            ),
                            _GoalFormStep.mapping => _MappingStep(
                              // Editing has no intention page: the statement
                              // is a single-line field at the top of this
                              // page instead.
                              statement: _editing ? _statement : null,
                              statementError: _statementError,
                              onStatementChanged: () =>
                                  setState(() => _statementError = null),
                              onExampleSelected: (example) => setState(() {
                                _statement.text = example;
                                _statementError = null;
                              }),
                              title: _title,
                              habits: habits,
                              habitsFailed:
                                  habitsAsync.hasError &&
                                  habitsAsync.value == null,
                              mapping: _mapping,
                              measurables: measurables,
                              categories: categories,
                              labels: labels,
                              measurableTargets: _measurableTargets,
                              healthTargets: _healthTargets,
                              healthDirections: _healthDirections,
                              categoryTimeTargets: _categoryTimeTargets,
                              categoryTimeDirections: _categoryTimeDirections,
                              labelTimeTargets: _labelTimeTargets,
                              labelTimeDirections: _labelTimeDirections,
                              labelTimeCategoryIds: _labelTimeCategoryIds,
                              compositeRule: _compositeRule,
                              requiredSuccesses: _requiredSuccesses,
                              habitTargets: _habitTargets,
                              watchesSteps: _watchesSteps,
                              stepsTarget: _stepsTarget,
                              chosenSignalOrder: _chosenSignalOrder,
                              suggestedSignalOrder: _suggestedSignalOrder,
                              targetErrors: _targetErrors,
                              anchorFor: _anchorFor,
                              titleError: _titleError,
                              validation: _validation,
                              onTitleChanged: () =>
                                  setState(() => _titleError = null),
                              onStepsChanged: (selected) => setState(() {
                                _watchesSteps = selected;
                                _refreshDerivedTitle(habits);
                                _validation = null;
                                _targetErrors.remove('steps');
                              }),
                              onStepsTargetChanged: () => setState(() {
                                _validation = null;
                                _targetErrors.remove('steps');
                              }),
                              onHabitChanged:
                                  ({
                                    required habitId,
                                    required selected,
                                  }) => setState(() {
                                    if (selected) {
                                      _habitTargets.putIfAbsent(
                                        habitId,
                                        () =>
                                            _rememberedHabitTargets[habitId] ??
                                            3,
                                      );
                                      _appendHabitDescriptor(habitId);
                                    } else {
                                      final removed = _habitTargets.remove(
                                        habitId,
                                      );
                                      if (removed != null) {
                                        _rememberedHabitTargets[habitId] =
                                            removed;
                                      }
                                    }
                                    _refreshDerivedTitle(habits);
                                    _validation = null;
                                  }),
                              onTargetChanged: (habitId, target) =>
                                  setState(() {
                                    _habitTargets[habitId] = target;
                                    _validation = null;
                                  }),
                              onMeasurableChanged:
                                  ({
                                    required measurableId,
                                    required selected,
                                  }) => setState(() {
                                    if (selected) {
                                      _measurableTargets.putIfAbsent(
                                        measurableId,
                                        () => 1,
                                      );
                                    } else {
                                      _measurableTargets.remove(measurableId);
                                    }
                                    _validation = null;
                                    _targetErrors.remove(
                                      'measurable:$measurableId',
                                    );
                                  }),
                              onMeasurableTargetChanged: (id, target) =>
                                  setState(() {
                                    _measurableTargets[id] = target;
                                    _validation = null;
                                    _targetErrors.remove('measurable:$id');
                                  }),
                              onHealthSelected: (dataTypes) => setState(() {
                                for (final dataType in dataTypes) {
                                  _suppressedHealthTypes.remove(dataType);
                                  _healthTargets.putIfAbsent(
                                    dataType,
                                    () => _defaultHealthTarget(dataType),
                                  );
                                  _healthDirections.putIfAbsent(
                                    dataType,
                                    () => GoalDirection.atMost,
                                  );
                                }
                                _appendSignalDescriptors(dataTypes);
                                _validation = null;
                              }),
                              onHealthRemoved: (dataType) => setState(() {
                                _suppressedHealthTypes.add(dataType);
                                _healthTargets.remove(dataType);
                                _healthDirections.remove(dataType);
                                _validation = null;
                                _targetErrors.remove('health:$dataType');
                              }),
                              onHealthTargetChanged: (dataType, target) =>
                                  setState(() {
                                    _healthTargets[dataType] = target;
                                    _adoptSharedBloodPressureDirection(
                                      dataType,
                                    );
                                    _validation = null;
                                    _targetErrors.remove('health:$dataType');
                                  }),
                              onHealthDirectionChanged: (dataType, direction) =>
                                  setState(() {
                                    _healthDirections[dataType] = direction;
                                    _validation = null;
                                  }),
                              onCategoryTimeSelected: (categoryId) => setState(
                                () {
                                  _suppressedCategoryTimeIds.remove(categoryId);
                                  _categoryTimeTargets.putIfAbsent(
                                    categoryId,
                                    () => 1,
                                  );
                                  _categoryTimeDirections.putIfAbsent(
                                    categoryId,
                                    () => GoalDirection.atMost,
                                  );
                                  _validation = null;
                                },
                              ),
                              onCategoryTimeRemoved: (categoryId) =>
                                  setState(() {
                                    _suppressedCategoryTimeIds.add(categoryId);
                                    _categoryTimeTargets.remove(categoryId);
                                    _categoryTimeDirections.remove(categoryId);
                                    _validation = null;
                                    _targetErrors.remove(
                                      'category:$categoryId',
                                    );
                                  }),
                              onCategoryTimeTargetChanged:
                                  (categoryId, target) => setState(() {
                                    _categoryTimeTargets[categoryId] = target;
                                    _validation = null;
                                    _targetErrors.remove(
                                      'category:$categoryId',
                                    );
                                  }),
                              onCategoryTimeDirectionChanged:
                                  (categoryId, direction) => setState(() {
                                    _categoryTimeDirections[categoryId] =
                                        direction;
                                    _validation = null;
                                  }),
                              onLabelTimeSelected: (labelId) => setState(() {
                                _suppressedLabelTimeIds.remove(labelId);
                                _labelTimeTargets.putIfAbsent(
                                  labelId,
                                  () => 1,
                                );
                                _labelTimeDirections.putIfAbsent(
                                  labelId,
                                  () => GoalDirection.atLeast,
                                );
                                _labelTimeCategoryIds.putIfAbsent(
                                  labelId,
                                  () => null,
                                );
                                _validation = null;
                              }),
                              onLabelTimeRemoved: (labelId) => setState(() {
                                _suppressedLabelTimeIds.add(labelId);
                                _labelTimeTargets.remove(labelId);
                                _labelTimeDirections.remove(labelId);
                                _labelTimeCategoryIds.remove(labelId);
                                _validation = null;
                                _targetErrors.remove('label:$labelId');
                              }),
                              onLabelTimeTargetChanged: (labelId, target) =>
                                  setState(() {
                                    _labelTimeTargets[labelId] = target;
                                    _validation = null;
                                    _targetErrors.remove('label:$labelId');
                                  }),
                              onLabelTimeDirectionChanged:
                                  (labelId, direction) => setState(() {
                                    _labelTimeDirections[labelId] = direction;
                                    _validation = null;
                                  }),
                              onLabelTimeCategoryChanged:
                                  (labelId, categoryId) => setState(() {
                                    _labelTimeCategoryIds[labelId] = categoryId;
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
                              personaError: _personaError,
                              titleError: _titleError,
                              onPersonaChanged: () =>
                                  setState(() => _personaError = null),
                              onTitleChanged: () =>
                                  setState(() => _titleError = null),
                              enabled: !_saving,
                            ),
                          },
                        ],
                      ),
                    ),
                    // The primary action is always on screen, on an opaque
                    // band — scrolling content ends at a hairline instead of
                    // being guillotined behind a floating pill.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        border: Border(
                          top: BorderSide(
                            color: tokens.colors.decorative.level01,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: tokens.spacing.step4,
                          bottom:
                              tokens.spacing.step4 +
                              DesignSystemBottomNavigationBar.occupiedHeight(
                                context,
                              ),
                        ),
                        child: primaryAction,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
