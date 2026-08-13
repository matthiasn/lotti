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
import 'package:lotti/features/design_system/components/steppers/design_system_stepper.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
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
  final Set<String> _matchedHabitIds = {};
  final Set<String> _matchedHealthTypes = {};

  /// Cadences a deselected habit had, restored on re-check so a micro-slip
  /// never costs the user a value they already shaped.
  final _rememberedHabitTargets = <String, int>{};

  /// Mapping entities whose target failed validation, keyed
  /// `steps` / `health:{type}` / `measurable:{id}` / `category:{id}`.
  final _targetErrors = <String>{};
  final _errorAnchors = <String, GlobalKey>{};
  String? _personaError;
  String? _titleError;
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
      for (final habit in matchedHabits) {
        _habitTargets.putIfAbsent(habit.id, () => 3);
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
      _targetErrors.clear();
      _step = _GoalFormStep.mapping;
    });
  }

  /// Re-derives the title after a selection change, but only while the
  /// form still owns it — a user-authored (or deliberately cleared-and-
  /// retyped) title is never overwritten.
  void _refreshDerivedTitle(List<HabitDefinition> habits) {
    if (_title.text.trim() != _derivedTitle) return;
    _title.text = '';
    _deriveTitle(habits);
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

  void _deriveTitle(List<HabitDefinition> habits) {
    final currentTitle = _title.text.trim();
    if (currentTitle.isNotEmpty && currentTitle != _derivedTitle) return;
    final selectedNames = [
      for (final habit in habits)
        if (_habitTargets.containsKey(habit.id)) _plainName(habit.name),
    ];
    final derivedTitle = selectedNames.isNotEmpty
        ? selectedNames.join(' & ')
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
    final invalidKeys = <String>{
      if (_watchesSteps && (stepsTarget == null || stepsTarget <= 0)) 'steps',
      for (final entry in _healthTargets.entries)
        if (entry.value == null || entry.value! <= 0) 'health:${entry.key}',
      for (final entry in _measurableTargets.entries)
        if (entry.value == null || entry.value! <= 0) 'measurable:${entry.key}',
      for (final entry in _categoryTimeTargets.entries)
        if (entry.value == null || entry.value! <= 0) 'category:${entry.key}',
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
          _plainName(names[entry.key] ?? entry.key),
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

  void _back() {
    if (_saving) return;

    if (_step.index > _GoalFormStep.intention.index) {
      setState(() {
        _step = _GoalFormStep.values[_step.index - 1];
        _validation = null;
        _targetErrors.clear();
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
    final desktop = isDesktopLayout(context);
    // On wide layouts the CTA lives in the reading column, below the last
    // card; the bottom-pinned bar is a phone pattern only.
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
      fullWidth: !desktop,
    );
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
                                  _targetErrors.clear();
                                });
                              },
                            ),
                            _GoalFormStep.mapping => _MappingStep(
                              title: _title,
                              habits: habits,
                              habitsFailed:
                                  habitsAsync.hasError &&
                                  habitsAsync.value == null,
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
                              matchedHabitIds: _matchedHabitIds,
                              matchedHealthTypes: _matchedHealthTypes,
                              targetErrors: _targetErrors,
                              anchorFor: _anchorFor,
                              titleError: _titleError,
                              validation: _validation,
                              onStepsChanged: (selected) => setState(() {
                                _watchesSteps = selected;
                                _refreshDerivedTitle(habits);
                                _validation = null;
                                _targetErrors.clear();
                              }),
                              onStepsTargetChanged: () => setState(() {
                                _validation = null;
                                _targetErrors.clear();
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
                                    _targetErrors.clear();
                                  }),
                              onTargetChanged: (habitId, target) =>
                                  setState(() {
                                    _habitTargets[habitId] = target;
                                    _validation = null;
                                    _targetErrors.clear();
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
                                    _targetErrors.clear();
                                  }),
                              onMeasurableTargetChanged: (id, target) =>
                                  setState(() {
                                    _measurableTargets[id] = target;
                                    _validation = null;
                                    _targetErrors.clear();
                                  }),
                              onHealthSelected: (dataTypes) => setState(() {
                                for (final dataType in dataTypes) {
                                  _healthTargets.putIfAbsent(
                                    dataType,
                                    () => _defaultHealthTarget(dataType),
                                  );
                                  _healthDirections.putIfAbsent(
                                    dataType,
                                    () => GoalDirection.atMost,
                                  );
                                }
                                _validation = null;
                                _targetErrors.clear();
                              }),
                              onHealthRemoved: (dataType) => setState(() {
                                _healthTargets.remove(dataType);
                                _healthDirections.remove(dataType);
                                _validation = null;
                                _targetErrors.clear();
                              }),
                              onHealthTargetChanged: (dataType, target) =>
                                  setState(() {
                                    _healthTargets[dataType] = target;
                                    _validation = null;
                                    _targetErrors.clear();
                                  }),
                              onHealthDirectionChanged: (dataType, direction) =>
                                  setState(() {
                                    _healthDirections[dataType] = direction;
                                    _validation = null;
                                    _targetErrors.clear();
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
                                  _targetErrors.clear();
                                },
                              ),
                              onCategoryTimeRemoved: (categoryId) =>
                                  setState(() {
                                    _suppressedCategoryTimeIds.add(categoryId);
                                    _categoryTimeTargets.remove(categoryId);
                                    _categoryTimeDirections.remove(categoryId);
                                    _validation = null;
                                    _targetErrors.clear();
                                  }),
                              onCategoryTimeTargetChanged:
                                  (categoryId, target) => setState(() {
                                    _categoryTimeTargets[categoryId] = target;
                                    _validation = null;
                                    _targetErrors.clear();
                                  }),
                              onCategoryTimeDirectionChanged:
                                  (categoryId, direction) => setState(() {
                                    _categoryTimeDirections[categoryId] =
                                        direction;
                                    _validation = null;
                                    _targetErrors.clear();
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
                              enabled: !_saving,
                            ),
                          },
                          if (desktop) ...[
                            SizedBox(height: tokens.spacing.sectionGap),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: primaryAction,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!desktop)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              tokens.spacing.step4 +
                              DesignSystemBottomNavigationBar.occupiedHeight(
                                context,
                              ),
                        ),
                        child: primaryAction,
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
    required this.title,
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
    required this.matchedHabitIds,
    required this.matchedHealthTypes,
    required this.targetErrors,
    required this.anchorFor,
    required this.titleError,
    required this.validation,
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
  final TextEditingController title;
  final Set<String> matchedHabitIds;
  final Set<String> matchedHealthTypes;

  /// Keys of mapping entities whose target failed validation; each renders
  /// as an error on its own input rather than one message mid-page.
  final Set<String> targetErrors;
  final GlobalKey Function(String key) anchorFor;
  final String? titleError;
  final String? validation;
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
      // Intention-matched habits stay visible when unchecked — a checkbox
      // must not delete its own row.
      for (final id in matchedHabitIds)
        if (!selectedIds.contains(id))
          (id: id, name: habitsById[id]?.name ?? id),
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
    // Intention-matched health capabilities surface as unchecked offer rows
    // in the signals card until picked, like the steps offer.
    final offersBloodPressure =
        matchedHealthTypes.contains(
          GoalHealthDataTypes.bloodPressureSystolic,
        ) &&
        !healthTargets.containsKey(GoalHealthDataTypes.bloodPressureSystolic);
    final offersWeight =
        matchedHealthTypes.contains(GoalHealthDataTypes.weight) &&
        !healthTargets.containsKey(GoalHealthDataTypes.weight);

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
          DesignSystemSectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final habit in visibleHabits)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final selected = selectedIds.contains(habit.id);
                      // Compact widths give the title its full measure and
                      // drop the cadence stepper to the row's secondary
                      // line; the trailing slot returns where the width
                      // earns it.
                      final compact =
                          constraints.maxWidth < kRowInlineControlMinWidth;
                      final stepper = selected
                          ? _HabitTargetStepper(
                              habitId: habit.id,
                              value: habitTargets[habit.id]!,
                              onChanged: (value) =>
                                  onTargetChanged(habit.id, value),
                            )
                          : null;
                      final row = DesignSystemSelectionRow(
                        key: ValueKey('goal-form-habit-${habit.id}'),
                        title: _CreateGoalAgentPageState._plainName(
                          habit.name,
                        ),
                        subtitle: messages.goalFormHabitSignal,
                        titleMaxLines: 2,
                        type: DesignSystemSelectionRowType.multiSelect,
                        selected: selected,
                        showSelectedBackground: false,
                        trailing: compact || stepper == null
                            ? null
                            : Padding(
                                padding: EdgeInsets.only(
                                  right: tokens.spacing.step1,
                                ),
                                child: stepper,
                              ),
                        secondaryLine: compact ? stepper : null,
                        onTap: () => onHabitChanged(
                          habitId: habit.id,
                          selected: !selected,
                        ),
                      );
                      return Column(
                        children: [row, _signalRowDivider(tokens)],
                      );
                    },
                  ),
                // The steps offer trails the user's own signals.
                DesignSystemSelectionRow(
                  key: const ValueKey('goal-form-steps-row'),
                  title: messages.goalCreateStepsTargetLabel,
                  subtitle: messages.goalFormStepsSignal,
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
                              label: messages.goalCreateStepsTargetLabel,
                              leadingIcon: Icons.directions_walk_rounded,
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
                if (offersBloodPressure)
                  DesignSystemSelectionRow(
                    key: const ValueKey('goal-form-offer-blood-pressure'),
                    title: messages.dashboardHealthBloodPressure,
                    subtitle: messages.goalFormBloodPressureSource,
                    type: DesignSystemSelectionRowType.multiSelect,
                    showSelectedBackground: false,
                    onTap: () => onHealthSelected(const [
                      GoalHealthDataTypes.bloodPressureSystolic,
                      GoalHealthDataTypes.bloodPressureDiastolic,
                    ]),
                  ),
                if (offersWeight)
                  DesignSystemSelectionRow(
                    key: const ValueKey('goal-form-offer-weight'),
                    title: messages.goalFormHealthWeight,
                    subtitle: messages.goalFormHealthSource('kg'),
                    type: DesignSystemSelectionRowType.multiSelect,
                    showSelectedBackground: false,
                    onTap: () => onHealthSelected(
                      const [GoalHealthDataTypes.weight],
                    ),
                  ),
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
                    errorText:
                        targetErrors.contains('measurable:${measurable.id}')
                        ? messages.goalFormValidationTarget
                        : null,
                    anchorKey: anchorFor('measurable:${measurable.id}'),
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
            SizedBox(height: tokens.spacing.cardItemSpacing),
            _HealthTargetCard(
              key: ValueKey('goal-form-health-card-${entry.key}'),
              dataType: entry.key,
              value: entry.value,
              direction: healthDirections[entry.key] ?? GoalDirection.atMost,
              errorText: targetErrors.contains('health:${entry.key}')
                  ? messages.goalFormValidationTarget
                  : null,
              anchorKey: anchorFor('health:${entry.key}'),
              onTargetChanged: (target) =>
                  onHealthTargetChanged(entry.key, target),
              onDirectionChanged: (direction) =>
                  onHealthDirectionChanged(entry.key, direction),
              onRemove: () => onHealthRemoved(entry.key),
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
                selectedHabitIds: habitTargets.keys.toSet(),
                selectedMeasurableIds: measurableTargets.keys.toSet(),
                selectedHealthDataTypes: healthTargets.keys.toSet(),
                selectedCategoryIds: categoryTimeTargets.keys.toSet(),
                onHabitChanged: onHabitChanged,
                onMeasurableChanged: onMeasurableChanged,
                onHealthSelected: onHealthSelected,
                onHealthRemoved: onHealthRemoved,
                onCategorySelected: onCategoryTimeSelected,
                onCategoryRemoved: onCategoryTimeRemoved,
              ),
            ),
            leadingIcon: Icons.add_rounded,
            variant: DesignSystemButtonVariant.secondary,
            fullWidth: true,
          ),
          if (dimensionCount > 1) ...[
            SizedBox(height: tokens.spacing.cardItemSpacing),
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
          SizedBox(height: tokens.spacing.sectionGap),
          // The goal's NAME is authored here, after the signals that shape
          // it — the derived value keeps following the selection until the
          // user types their own.
          DesignSystemTextInput(
            key: const ValueKey('goal-form-title-mapping'),
            controller: title,
            label: messages.goalFormGoalNameLabel,
            leadingIcon: Icons.flag_outlined,
            errorText: titleError,
          ),
          SizedBox(height: tokens.spacing.sectionGap),
          // A footnote, not a card: the explainer must not impersonate a
          // second input under the goal-name field.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.calendar_view_week_rounded,
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

/// The hairline that closes each signal band inside the signals card.
Widget _signalRowDivider(DsTokens tokens) => Padding(
  padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
  child: Divider(
    height: BorderWidths.hairline,
    color: tokens.colors.decorative.level01,
  ),
);

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
    required this.errorText,
    required this.anchorKey,
    required this.onChanged,
  });

  final String measurableId;
  final num? value;
  final String unitName;
  final String? errorText;

  /// Scroll anchor for validation: the page scrolls this input into view
  /// when its target fails the continue check.
  final Key anchorKey;
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
    return KeyedSubtree(
      key: widget.anchorKey,
      child: SizedBox(
        width: kInlineTargetInputWidth,
        child: DesignSystemTextInput(
          key: ValueKey('goal-form-measurable-target-${widget.measurableId}'),
          controller: _controller,
          label: widget.unitName,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          errorText: widget.errorText,
          onChanged: (raw) {
            final value = num.tryParse(raw.replaceAll(',', '.'));
            widget.onChanged(value);
          },
        ),
      ),
    );
  }
}

class _HealthTargetCard extends StatelessWidget {
  const _HealthTargetCard({
    required this.dataType,
    required this.value,
    required this.direction,
    required this.errorText,
    required this.anchorKey,
    required this.onTargetChanged,
    required this.onDirectionChanged,
    required this.onRemove,
    super.key,
  });

  final String dataType;
  final num? value;
  final GoalDirection direction;
  final String? errorText;
  final Key anchorKey;
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
            errorText: errorText,
            anchorKey: anchorKey,
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
    required this.errorText,
    required this.anchorKey,
    required this.onChanged,
  });

  final String dataType;
  final num? value;
  final String unit;
  final String? errorText;
  final Key anchorKey;
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
  Widget build(BuildContext context) => KeyedSubtree(
    key: widget.anchorKey,
    child: DesignSystemTextInput(
      key: ValueKey('goal-form-health-target-${widget.dataType}'),
      controller: _controller,
      label: context.messages.goalFormHealthTarget(widget.unit),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      errorText: widget.errorText,
      onChanged: (raw) => widget.onChanged(
        num.tryParse(raw.trim().replaceAll(',', '.')),
      ),
    ),
  );
}

class _CategoryTimeTargetCard extends StatelessWidget {
  const _CategoryTimeTargetCard({
    required this.categoryId,
    required this.categoryName,
    required this.value,
    required this.direction,
    required this.errorText,
    required this.anchorKey,
    required this.onTargetChanged,
    required this.onDirectionChanged,
    required this.onRemove,
    super.key,
  });

  final String categoryId;
  final String categoryName;
  final num? value;
  final GoalDirection direction;
  final String? errorText;
  final Key anchorKey;
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
                color: tokens.colors.text.mediumEmphasis,
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
            errorText: errorText,
            anchorKey: anchorKey,
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
    required this.errorText,
    required this.anchorKey,
    required this.onChanged,
  });

  final String categoryId;
  final num? value;
  final String? errorText;
  final Key anchorKey;
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
  Widget build(BuildContext context) => KeyedSubtree(
    key: widget.anchorKey,
    child: DesignSystemTextInput(
      key: ValueKey('goal-form-category-time-target-${widget.categoryId}'),
      controller: _controller,
      label: context.messages.goalFormCategoryTimeTarget,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      errorText: widget.errorText,
      onChanged: (raw) => widget.onChanged(
        num.tryParse(raw.trim().replaceAll(',', '.')),
      ),
    ),
  );
}

class _DimensionSourcePicker extends StatefulWidget {
  const _DimensionSourcePicker({
    required this.habits,
    required this.habitsFailed,
    required this.measurables,
    required this.categories,
    required this.selectedHabitIds,
    required this.selectedMeasurableIds,
    required this.selectedHealthDataTypes,
    required this.selectedCategoryIds,
    required this.onHabitChanged,
    required this.onMeasurableChanged,
    required this.onHealthSelected,
    required this.onHealthRemoved,
    required this.onCategorySelected,
    required this.onCategoryRemoved,
  });

  final List<HabitDefinition> habits;
  final bool habitsFailed;
  final List<MeasurableDataType> measurables;
  final List<CategoryDefinition> categories;
  final Set<String> selectedHabitIds;
  final Set<String> selectedMeasurableIds;
  final Set<String> selectedHealthDataTypes;
  final Set<String> selectedCategoryIds;
  final void Function({required String habitId, required bool selected})
  onHabitChanged;
  final void Function({required String measurableId, required bool selected})
  onMeasurableChanged;
  final ValueChanged<List<String>> onHealthSelected;
  final ValueChanged<String> onHealthRemoved;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onCategoryRemoved;

  @override
  State<_DimensionSourcePicker> createState() => _DimensionSourcePickerState();
}

/// The ONE place every watchable signal lives — habits, steps aside (it has
/// its own always-visible row), weight, blood pressure, measurables and
/// tracked time — searchable in plain language, multi-select, and it stays
/// open until Done so composing a goal is one visit, not four.
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
    final bloodPressureSelected = bloodPressureTypes.every(
      _healthTypes.contains,
    );
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
              leadingIcon: Icons.search_rounded,
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
                          beamToNamed('/habits');
                        },
                        variant: DesignSystemButtonVariant.secondary,
                        fullWidth: true,
                      ),
                    ],
                    SizedBox(height: tokens.spacing.step4),
                  ],
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

class _ConfirmationStep extends StatefulWidget {
  const _ConfirmationStep({
    required this.title,
    required this.persona,
    required this.signalDescription,
    required this.preservesCriteria,
    required this.editVersion,
    required this.validation,
    required this.personaError,
    required this.titleError,
    required this.enabled,
  });

  final TextEditingController title;
  final TextEditingController persona;
  final String signalDescription;
  final bool preservesCriteria;
  final int? editVersion;
  final String? validation;
  final String? personaError;
  final String? titleError;
  final bool enabled;

  @override
  State<_ConfirmationStep> createState() => _ConfirmationStepState();
}

/// A CONFIRMATION, not more form: the plain-language summary is the hero,
/// the goal name reads as a text row with an edit affordance (it was fully
/// editable one step ago), the persona field follows, and the cost note is
/// a caption, not a card competing with the summary.
class _ConfirmationStepState extends State<_ConfirmationStep> {
  bool _editingTitle = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // A validation error re-opens the field so the fix is one tap closer.
    final editingTitle = _editingTitle || widget.titleError != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          messages.goalFormConfirmTitle,
          style: tokens.typography.styles.heading.heading3,
        ),
        SizedBox(height: tokens.spacing.step5),
        DesignSystemSectionCard(
          padding: EdgeInsets.all(tokens.spacing.step4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.preservesCriteria
                    ? messages.goalFormPreservedCriteriaSummary
                    : messages.goalFormRestatement(widget.signalDescription),
                style: tokens.typography.styles.subtitle.subtitle1,
              ),
              SizedBox(height: tokens.spacing.step4),
              // ONE field grammar across steps: the same labelled input as
              // the mapping step, read-only until the pencil (or a
              // validation error) unlocks it.
              DesignSystemTextInput(
                key: const ValueKey('goal-form-title'),
                controller: widget.title,
                label: messages.goalFormGoalNameLabel,
                leadingIcon: Icons.flag_outlined,
                errorText: widget.titleError,
                enabled: widget.enabled,
                readOnly: !editingTitle,
                trailingIcon: editingTitle ? null : Icons.edit_outlined,
                trailingIconTooltip: editingTitle
                    ? null
                    : messages.goalFormGoalNameLabel,
                trailingIconKey: const ValueKey('goal-form-title-edit'),
                onTrailingIconTap: editingTitle
                    ? null
                    : () => setState(() => _editingTitle = true),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        DesignSystemTextInput(
          key: const ValueKey('goal-form-persona'),
          controller: widget.persona,
          label: messages.goalFormPersonaLabel,
          leadingIcon: Icons.auto_awesome_rounded,
          errorText: widget.personaError,
          enabled: widget.enabled,
        ),
        SizedBox(height: tokens.spacing.step4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.eco_outlined,
              size: IconSizes.s,
              color: tokens.colors.text.mediumEmphasis,
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Text(
                messages.goalFormCostHonesty,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          ],
        ),
        if (widget.validation != null) ...[
          SizedBox(height: tokens.spacing.step3),
          Text(
            widget.validation!,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.alert.error.defaultColor,
            ),
          ),
        ],
        if (widget.editVersion != null) ...[
          SizedBox(height: tokens.spacing.step4),
          Text(
            messages.goalFormEditVersion(widget.editVersion! + 1),
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
