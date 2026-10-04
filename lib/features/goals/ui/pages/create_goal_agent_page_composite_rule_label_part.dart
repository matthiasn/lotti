part of 'create_goal_agent_page.dart';

/// Creates or edits a goal agent through WP5's observable-mapping controls.
///
/// Creation walks three steps — intention → mapping → confirmation — because
/// the intention statement drives the observable-signal derivation for a goal
/// that does not exist yet. Passing [agentId] switches the flow into versioned
/// editing, which has no intention page: the statement is a single-line field
/// at the top of the mapping page, so editing is mapping → confirmation, two
/// steps. The current spec is mapped losslessly into the same controls used
/// for creation; saving mints a new immutable spec version rather than
/// changing history in place.
class CreateGoalAgentPage extends ConsumerStatefulWidget {
  const CreateGoalAgentPage({this.agentId, super.key});

  final String? agentId;

  @override
  ConsumerState<CreateGoalAgentPage> createState() =>
      _CreateGoalAgentPageState();
}

enum _GoalFormStep { intention, mapping, confirmation }

/// The canned example intentions, shared by the intention step and the
/// consolidated edit page.
List<String> _intentionExamples(BuildContext context) {
  final messages = context.messages;
  return [
    messages.goalFormExampleHealth,
    messages.goalFormExampleGym,
    messages.goalFormExampleWalk,
    messages.goalFormExampleRead,
  ];
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
