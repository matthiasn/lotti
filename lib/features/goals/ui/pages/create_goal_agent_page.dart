import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The dogfooding creation form: a steps goal (daily average over a
/// rolling week) or a habit routine watching ONE OR MORE habits, each
/// completed N times per calendar week (an `allOf` composite — the
/// multi-habit shape the criteria model always supported).
class CreateGoalAgentPage extends ConsumerStatefulWidget {
  const CreateGoalAgentPage({super.key});

  @override
  ConsumerState<CreateGoalAgentPage> createState() =>
      _CreateGoalAgentPageState();
}

enum _GoalKind { steps, habits }

class _CreateGoalAgentPageState extends ConsumerState<CreateGoalAgentPage> {
  final _name = TextEditingController();
  final _statement = TextEditingController();
  final _stepsTarget = TextEditingController(text: '10000');
  final _habitCount = TextEditingController(text: '3');
  _GoalKind _kind = _GoalKind.steps;
  final _selectedHabitIds = <String>{};
  String? _validation;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _statement.dispose();
    _stepsTarget.dispose();
    _habitCount.dispose();
    super.dispose();
  }

  GoalCriterion? _buildCriteria() {
    switch (_kind) {
      case _GoalKind.steps:
        final target = num.tryParse(_stepsTarget.text.trim());
        if (target == null || target <= 0) return null;
        return GoalCriterion.metric(
          criterionId: 'steps',
          dataType: 'cumulative_step_count',
          window: const GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: target,
        );
      case _GoalKind.habits:
        final count = int.tryParse(_habitCount.text.trim());
        if (count == null || count < 1 || _selectedHabitIds.isEmpty) {
          return null;
        }
        final leaves = [
          for (final habitId in _selectedHabitIds)
            GoalCriterion.habit(
              criterionId: 'habit-$habitId',
              habitId: habitId,
              window: const GoalWindow.calendarWeek(),
              targetCount: count,
            ),
        ];
        return leaves.length == 1
            ? leaves.single
            : GoalCriterion.allOf(criterionId: 'routine', criteria: leaves);
    }
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final criteria = _buildCriteria();
    if (name.isEmpty || criteria == null) {
      setState(
        () => _validation = context.messages.goalCreateValidationMissing,
      );
      return;
    }
    setState(() {
      _validation = null;
      _saving = true;
    });
    try {
      final statement = _statement.text.trim();
      await ref
          .read(goalAgentServiceProvider)
          .createGoalAgent(
            title: name,
            statement: statement.isEmpty ? name : statement,
            criteria: criteria,
          );
      if (mounted) context.beamToNamed('/agents');
    } on Object {
      // Validation already passed — this is an operational failure, and
      // saying "pick a name" would misdiagnose it.
      if (mounted) {
        setState(() {
          _saving = false;
          _validation = context.messages.goalCreateFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final habits = ref.watch(_habitDefinitionsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(messages.agentsCreateGoal)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tokens.spacing.step5),
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: messages.goalCreateNameLabel,
              ),
            ),
            SizedBox(height: tokens.spacing.step4),
            TextField(
              controller: _statement,
              decoration: InputDecoration(
                labelText: messages.goalCreateStatementLabel,
              ),
            ),
            SizedBox(height: tokens.spacing.step5),
            SegmentedButton<_GoalKind>(
              segments: [
                ButtonSegment(
                  value: _GoalKind.steps,
                  label: Text(messages.goalCreateTypeSteps),
                ),
                ButtonSegment(
                  value: _GoalKind.habits,
                  label: Text(messages.goalCreateTypeHabits),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) =>
                  setState(() => _kind = selection.single),
            ),
            SizedBox(height: tokens.spacing.step5),
            if (_kind == _GoalKind.steps)
              TextField(
                controller: _stepsTarget,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: messages.goalCreateStepsTargetLabel,
                ),
              )
            else ...[
              TextField(
                controller: _habitCount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: messages.goalCreateHabitCountLabel,
                ),
              ),
              SizedBox(height: tokens.spacing.step4),
              Text(
                messages.goalCreateHabitsLabel,
                style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
              for (final habit in habits)
                CheckboxListTile(
                  value: _selectedHabitIds.contains(habit.id),
                  title: Text(habit.name),
                  onChanged: (checked) => setState(() {
                    if (checked ?? false) {
                      _selectedHabitIds.add(habit.id);
                    } else {
                      _selectedHabitIds.remove(habit.id);
                    }
                  }),
                ),
            ],
            if (_validation != null) ...[
              SizedBox(height: tokens.spacing.step3),
              Text(
                _validation!,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.alert.error.defaultColor,
                ),
              ),
            ],
            SizedBox(height: tokens.spacing.sectionGap),
            FilledButton(
              onPressed: _saving ? null : _create,
              child: Text(messages.goalCreateSaveButton),
            ),
          ],
        ),
      ),
    );
  }
}

final StreamProvider<List<HabitDefinition>> _habitDefinitionsProvider =
    StreamProvider.autoDispose<List<HabitDefinition>>(
      // Active only, matching the habits UI: a goal watching a paused
      // habit would report false lack of progress forever.
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
