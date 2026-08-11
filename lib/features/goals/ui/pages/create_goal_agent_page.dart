import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
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
  List<HabitDefinition> _knownHabits = const [];
  var _watchesSteps = false;
  var _showAllHabits = false;
  var _initialized = false;
  var _defaultPersonaInitialized = false;
  var _saving = false;
  String? _derivedFrom;
  String? _derivedTitle;
  String? _derivedHabitsFingerprint;
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
    if (!_editing && (_derivedFrom != statement || habitsChanged)) {
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
      _deriveTitle(habits);
      _derivedFrom = statement;
      if (habitsFingerprint != null) {
        _derivedHabitsFingerprint = habitsFingerprint;
      }
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
        !_mapping.isEditable || _watchesSteps || _habitTargets.isNotEmpty;
    final stepsTarget = _parseLocalizedTarget(_stepsTarget.text);
    final invalidSteps =
        _watchesSteps && (stepsTarget == null || stepsTarget <= 0);
    if (!hasMapping || invalidSteps) {
      setState(() => _validation = context.messages.goalFormValidationMapping);
      return;
    }
    _deriveTitle(habits);
    setState(() {
      _validation = null;
      _step = _GoalFormStep.confirmation;
    });
  }

  void _reconcileHabitTargets() {
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
          !loadedHabitIds.contains(habitId),
    );
  }

  void _invalidateGoalViews(ProviderContainer container, String agentId) {
    container
      ..invalidate(agentIdentityProvider(agentId))
      ..invalidate(goalAgentHealthProvider(agentId))
      ..invalidate(goalAgentProgressViewProvider(agentId))
      ..invalidate(activeGoalAgentsProvider)
      ..invalidate(activeGoalNudgesProvider)
      ..invalidate(goalNudgeHistoryProvider(agentId));
  }

  String _signalDescription(List<HabitDefinition> habits) {
    final names = {for (final habit in habits) habit.id: habit.name};
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
    ];
    return signals.join(' · ');
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final persona = _persona.text.trim();
    final statement = _statement.text.trim();
    if (title.isEmpty || persona.isEmpty) {
      setState(() => _validation = context.messages.goalFormValidationIdentity);
      return;
    }
    _reconcileHabitTargets();
    final stepsTarget = _parseLocalizedTarget(_stepsTarget.text);
    final criteria = _watchesSteps && (stepsTarget == null || stepsTarget <= 0)
        ? null
        : _mapping.buildCriteria(
            stepsTitle: context.messages.goalCreateStepsTargetLabel,
            habitTargets: _habitTargets,
            watchesSteps: _watchesSteps,
            stepsTarget: stepsTarget,
          );
    if (criteria == null) {
      setState(() => _validation = context.messages.goalFormValidationMapping);
      return;
    }

    setState(() {
      _saving = true;
      _validation = null;
    });
    final container = ProviderScope.containerOf(context, listen: false);
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
          _validation = context.messages.goalCreateFailed;
        });
      }
    }
  }

  void _back() {
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
    if (habitsAsync.value case final loaded?) {
      _knownHabits = loaded;
    }
    final habits = habitsAsync.value ?? _knownHabits;
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
          leading: BackButton(onPressed: _back),
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
                        ),
                        _GoalFormStep.confirmation => _ConfirmationStep(
                          title: _title,
                          persona: _persona,
                          signalDescription: _signalDescription(habits),
                          preservesCriteria: !_mapping.isEditable,
                          editVersion: editSpec?.version,
                          validation: _validation,
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

class _MappingStep extends StatelessWidget {
  const _MappingStep({
    required this.habits,
    required this.habitsFailed,
    required this.mapping,
    required this.habitTargets,
    required this.watchesSteps,
    required this.stepsTarget,
    required this.showAllHabits,
    required this.validation,
    required this.onStepsChanged,
    required this.onHabitChanged,
    required this.onTargetChanged,
    required this.onShowAll,
  });

  final List<HabitDefinition> habits;
  final bool habitsFailed;
  final GoalFormMapping mapping;
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
        mapping.isEditable && !watchesSteps && selectedIds.isEmpty;

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
  });

  final TextEditingController title;
  final TextEditingController persona;
  final String signalDescription;
  final bool preservesCriteria;
  final int? editVersion;
  final String? validation;

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
        ),
        SizedBox(height: tokens.spacing.step4),
        DesignSystemTextInput(
          key: const ValueKey('goal-form-title'),
          controller: title,
          label: messages.goalCreateNameLabel,
          leadingIcon: Icons.flag_outlined,
          errorText: validation,
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
