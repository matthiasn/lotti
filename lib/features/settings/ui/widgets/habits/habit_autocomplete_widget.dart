// ignore_for_file: unused-code

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/blocs/settings/habits/habit_settings_cubit.dart';
import 'package:lotti/blocs/settings/habits/habit_settings_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

const testAutoComplete = AutoCompleteRule.and(
  title: 'Physical Exercises and Hydration',
  rules: [
    AutoCompleteRule.or(
      title: 'Body weight exercises or Gym',
      rules: [
        AutoCompleteRule.multiple(
          successes: 5,
          title: 'Daily body weight exercises',
          rules: [
            AutoCompleteRule.measurable(
              dataTypeId: 'push-ups',
              minimum: 25,
            ),
            AutoCompleteRule.measurable(
              dataTypeId: 'pull-ups',
              minimum: 10,
            ),
            AutoCompleteRule.measurable(
              dataTypeId: 'sit-ups',
              minimum: 70,
            ),
            AutoCompleteRule.measurable(
              dataTypeId: 'lunges',
              minimum: 30,
            ),
            AutoCompleteRule.measurable(
              dataTypeId: 'plank',
              minimum: 70,
            ),
            AutoCompleteRule.measurable(
              dataTypeId: 'squats',
              minimum: 10,
            ),
          ],
        ),
        AutoCompleteRule.workout(
          dataType: 'functionalStrengthTraining.duration',
          title: 'Gym workout without tracking exercises',
          minimum: 30,
        ),
      ],
    ),
    AutoCompleteRule.or(
      title: 'Daily Cardio',
      rules: [
        AutoCompleteRule.health(
          dataType: 'cumulative_step_count',
          minimum: 10000,
        ),
        AutoCompleteRule.workout(
          dataType: 'walking.duration',
          minimum: 60,
        ),
        AutoCompleteRule.workout(
          dataType: 'swimming.duration',
          minimum: 20,
        ),
        AutoCompleteRule.workout(
          dataType: 'cycling.duration',
          minimum: 120,
        ),
      ],
    ),
    AutoCompleteRule.measurable(
      dataTypeId: 'water',
      minimum: 2000,
      title: 'Stay hydrated.',
    ),
  ],
);

class HabitAutocompleteWidget extends StatefulWidget {
  const HabitAutocompleteWidget(
    this.autoCompleteRule, {
    required this.path,
    super.key,
  });

  final AutoCompleteRule? autoCompleteRule;
  final List<int> path;

  @override
  State<HabitAutocompleteWidget> createState() =>
      _HabitAutocompleteWidgetState();
}

class _HabitAutocompleteWidgetState extends State<HabitAutocompleteWidget> {
  HabitAutocompleteWidget indexedChild(int idx, AutoCompleteRule rule) {
    return HabitAutocompleteWidget(
      rule,
      path: [...widget.path, idx],
    );
  }

  @override
  Widget build(BuildContext context) {
    const spacer = SizedBox(height: 10, width: 15);
    final cubit = context.read<HabitSettingsCubit>();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: Colors.grey.withAlpha(152),
        child: Column(
          children: [
            Row(
              children: [
                Text('Path ${widget.path}'),
                IconButton(
                  icon: Icon(MdiIcons.delete),
                  iconSize: settingsIconSize,
                  color: Colors.black38,
                  onPressed: () {
                    cubit.removeAutoCompleteRuleAt(widget.path);
                  },
                ),
              ],
            ),
            if (widget.autoCompleteRule != null)
              switch (widget.autoCompleteRule!) {
                AutoCompleteRuleHealth(
                  :final title,
                  :final dataType,
                  :final minimum,
                  :final maximum
                ) =>
                  Container(
                    color: Colors.blue.withAlpha(127),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RuleTitleWidget(title, bottomPadding: 4),
                        RuleInfoWidget(
                          '$dataType'
                          '${minimum != null ? ', min: $minimum' : ''}'
                          '${maximum != null ? ', max: $maximum' : ''}',
                        ),
                      ],
                    ),
                  ),
                AutoCompleteRuleHabit(:final title, :final habitId) =>
                  Container(
                    color: Colors.blue.withAlpha(127),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RuleTitleWidget(title, bottomPadding: 4),
                        RuleInfoWidget(habitId),
                      ],
                    ),
                  ),
                AutoCompleteRuleWorkout(
                  :final title,
                  :final dataType,
                  :final minimum,
                  :final maximum
                ) =>
                  Container(
                    color: Colors.blue.withAlpha(127),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RuleTitleWidget(title, bottomPadding: 4),
                        RuleInfoWidget(
                          '$dataType'
                          '${minimum != null ? ', min: $minimum' : ''}'
                          '${maximum != null ? ', max: $maximum' : ''}',
                        ),
                      ],
                    ),
                  ),
                AutoCompleteRuleMeasurable(
                  :final title,
                  :final dataTypeId,
                  :final minimum,
                  :final maximum
                ) =>
                  Container(
                    color: Colors.green.withAlpha(127),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RuleTitleWidget(title, bottomPadding: 4),
                        RuleInfoWidget(
                          '$dataTypeId'
                          '${minimum != null ? ', min: $minimum' : ''}'
                          '${maximum != null ? ', max: $maximum' : ''}',
                        ),
                      ],
                    ),
                  ),
                AutoCompleteRuleAnd(:final title, :final rules) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RuleTitleWidget(title),
                        Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: RuleListInfoWidget('AND'),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                spacer,
                                ...intersperse(
                                  spacer,
                                  rules.mapIndexed(indexedChild),
                                ),
                                spacer,
                              ],
                            ),
                            spacer,
                          ],
                        ),
                      ],
                    ),
                  ),
                AutoCompleteRuleOr(:final title, :final rules) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RuleTitleWidget(title),
                        Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: RuleListInfoWidget('OR'),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                spacer,
                                ...intersperse(
                                  spacer,
                                  rules.mapIndexed(indexedChild),
                                ),
                                spacer,
                              ],
                            ),
                            spacer,
                          ],
                        ),
                      ],
                    ),
                  ),
                AutoCompleteRuleMultiple(
                  :final rules,
                  :final successes,
                  :final title
                ) =>
                  () {
                    final n = rules.length;
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RuleTitleWidget(title),
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: RuleListInfoWidget(
                                  '$successes/$n',
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  spacer,
                                  ...intersperse(
                                    spacer,
                                    rules.mapIndexed(indexedChild),
                                  ),
                                  spacer,
                                ],
                              ),
                              spacer,
                            ],
                          ),
                        ],
                      ),
                    );
                  }(),
              }
          ],
        ),
      ),
    );
  }
}

class RuleInfoWidget extends StatelessWidget {
  const RuleInfoWidget(
    this.info, {
    super.key,
  });

  final String info;

  @override
  Widget build(BuildContext context) {
    return Text(
      info,
      style: monoTabularStyle(
        fontSize: fontSizeMedium,
        fontWeight: FontWeight.normal,
      ),
    );
  }
}

class RuleListInfoWidget extends StatelessWidget {
  const RuleListInfoWidget(
    this.info, {
    super.key,
  });

  final String info;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 3,
      child: Text(
        info,
        style: monoTabularStyle(
          fontSize: fontSizeLarge,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}

class RuleTitleWidget extends StatelessWidget {
  const RuleTitleWidget(
    this.title, {
    this.bottomPadding = 0,
    super.key,
  });

  final String? title;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    if (title != null) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Text(title!),
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}

class HabitAutocompleteWrapper extends StatelessWidget {
  const HabitAutocompleteWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HabitSettingsCubit, HabitSettingsState>(
      builder: (
        context,
        HabitSettingsState state,
      ) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              const Text('AutoCompleteRules editor playground, not saving yet'),
              const SizedBox(height: 10),
              HabitAutocompleteWidget(
                state.autoCompleteRule,
                path: const <int>[0],
              ),
            ],
          ),
        );
      },
    );
  }
}
