import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/dashboards/config/dashboard_workout_config.dart';
import 'package:lotti/features/dashboards/state/survey_data.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/chart_multi_select.dart';
import 'package:lotti/features/settings/ui/widgets/entity_detail_card.dart';
import 'package:lotti/features/settings/ui/widgets/form/form_switch.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:uuid/uuid.dart';

class DashboardDefinitionPage extends StatefulWidget {
  const DashboardDefinitionPage({
    required this.dashboard,
    super.key,
    this.formKey,
  });

  final DashboardDefinition dashboard;
  final GlobalKey<FormBuilderState>? formKey;

  @override
  State<DashboardDefinitionPage> createState() =>
      _DashboardDefinitionPageState();
}

class _DashboardDefinitionPageState extends State<DashboardDefinitionPage> {
  final JournalDb _db = getIt<JournalDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();
  final _uuid = const Uuid();

  bool dirty = false;

  late List<DashboardItem> dashboardItems;
  String? categoryId;

  @override
  void initState() {
    super.initState();
    dashboardItems = [...widget.dashboard.items];
    categoryId = widget.dashboard.categoryId;
  }

  void onConfirmAddMeasurement(List<MeasurableDataType?> selection) {
    for (final selected in selection) {
      if (selected != null) {
        setState(() {
          dashboardItems.add(
            DashboardItem.measurement(
              id: selected.id,
              aggregationType:
                  selected.aggregationType ?? AggregationType.dailySum,
            ),
          );
          dirty = true;
        });
      }
    }
  }

  void onConfirmAddHabit(List<HabitDefinition?> selection) {
    for (final selected in selection) {
      if (selected != null) {
        setState(() {
          dashboardItems.add(
            DashboardItem.habitChart(habitId: selected.id),
          );
          dirty = true;
        });
      }
    }
  }

  void onConfirmAddHealthType(List<HealthTypeConfig?> selection) {
    for (final selected in selection) {
      if (selected != null) {
        setState(() {
          dashboardItems.add(
            DashboardItem.healthChart(
              color: 'color',
              healthType: selected.healthType,
            ),
          );
          dirty = true;
        });
      }
    }
  }

  void onConfirmAddSurveyType(List<DashboardSurveyItem?> selection) {
    for (final selected in selection) {
      if (selected != null) {
        setState(() {
          dashboardItems.add(selected);
          dirty = true;
        });
      }
    }
  }

  void onConfirmAddWorkoutType(List<DashboardWorkoutItem?> selection) {
    for (final selected in selection) {
      if (selected != null) {
        setState(() {
          dashboardItems.add(selected);
          dirty = true;
        });
      }
    }
  }

  void updateItem(DashboardItem item, int index) {
    setState(() {
      dashboardItems[index] = item;
      dirty = true;
    });
  }

  void dismissItem(int index) {
    setState(() {
      dashboardItems.removeAt(index);
      dirty = true;
    });
  }

  String _getItemTitle(DashboardItem item) {
    return item.when(
      measurement: (id, aggregationType) => 'Measurement',
      habitChart: (habitId) => 'Habit Chart',
      healthChart: (color, healthType) => healthTypes[healthType]?.displayName ?? healthType,
      surveyChart: (colorsByScoreKey, surveyType, surveyName) => surveyName,
      workoutChart: (workoutType, displayName, color, valueType) => displayName,
      storyTimeChart: (storyTagId, color) => 'Story Time Chart',
      wildcardStoryTimeChart: (storySubstring, color) => 'Story Time Chart',
    );
  }

  String _getItemSubtitle(DashboardItem item) {
    return item.when(
      measurement: (id, aggregationType) => 'Aggregation: ${aggregationType?.toString().split('.').last ?? 'Default'}',
      habitChart: (habitId) => 'Habit tracking',
      healthChart: (color, healthType) => 'Health data',
      surveyChart: (colorsByScoreKey, surveyType, surveyName) => 'Survey responses',
      workoutChart: (workoutType, displayName, color, valueType) => 'Workout data',
      storyTimeChart: (storyTagId, color) => 'Story time tracking',
      wildcardStoryTimeChart: (storySubstring, color) => 'Story time tracking',
    );
  }

  @override
  Widget build(BuildContext context) {
    void maybePop() => Navigator.of(context).maybePop();

    final formKey = widget.formKey ?? _formKey;

    return StreamBuilder<List<HabitDefinition>>(
      stream: getIt<JournalDb>().watchHabitDefinitions(),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<HabitDefinition>> snapshot,
      ) {
        final habitSelectItems = [
          ...?snapshot.data?.map(
            (item) => MultiSelectItem<HabitDefinition>(
              item,
              item.name,
            ),
          ),
        ];

        return StreamBuilder<List<MeasurableDataType>>(
          stream: _db.watchMeasurableDataTypes(),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<MeasurableDataType>> snapshot,
          ) {
            final measurableDataTypes = snapshot.data ?? [];

            final measurableSelectItems = [
              ...measurableDataTypes.map(
                (item) => MultiSelectItem<MeasurableDataType>(
                  item,
                  item.displayName,
                ),
              ),
            ];

            final healthSelectItems = healthTypes.keys.map((String typeName) {
              final item = healthTypes[typeName];
              return MultiSelectItem<HealthTypeConfig>(
                item!,
                item.displayName,
              );
            }).toList();

            final surveySelectItems = surveyTypes.keys.map((String typeName) {
              final item = surveyTypes[typeName];
              return MultiSelectItem<DashboardSurveyItem>(
                item!,
                item.surveyName,
              );
            }).toList();

            final workoutSelectItems = workoutTypes.keys.map((String typeName) {
              final item = workoutTypes[typeName];
              return MultiSelectItem<DashboardWorkoutItem>(
                item!,
                item.displayName,
              );
            }).toList();

            void setCategory(String? newCategoryId) {
              debugPrint('setCategory $newCategoryId');
              categoryId = newCategoryId;
              setState(() {
                dirty = true;
              });
            }

            Future<DashboardDefinition> saveDashboard() async {
              formKey.currentState!.save();
              if (formKey.currentState!.validate()) {
                final formData = formKey.currentState?.value;

                final private = formData?['private'] as bool? ?? false;
                final active = formData?['active'] as bool? ?? false;

                final dashboard = widget.dashboard.copyWith(
                  name: '${formData!['name']}'.trim(),
                  description: '${formData['description']}'.trim(),
                  private: private,
                  active: active,
                  reviewAt: formData['review_at'] as DateTime?,
                  categoryId: categoryId,
                  updatedAt: DateTime.now(),
                  items: dashboardItems,
                );

                await persistenceLogic.upsertDashboardDefinition(dashboard);
                return dashboard;
              }
              return widget.dashboard;
            }

            Future<void> saveDashboardPress() async {
              await saveDashboard();
              setState(() {
                dirty = false;
              });
              maybePop();
            }

            return Scaffold(
              body: CustomScrollView(
                slivers: <Widget>[
                  SliverAppBar(
                    title: Text(
                      context.messages.settingsDashboardDetailsLabel,
                      style: appBarTextStyleNewLarge.copyWith(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    pinned: true,
                    actions: [
                      if (dirty)
                        TextButton(
                          key: const Key(
                            'dashboard_save',
                          ),
                          onPressed: saveDashboardPress,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            child: Text(
                              context.messages.settingsDashboardSaveLabel,
                              style: saveButtonStyle(
                                Theme.of(
                                  context,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: EntityDetailCard(
                      child: Column(
                        children: [
                          FormBuilder(
                            key: formKey,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            onChanged: () {
                              formKey.currentState?.save();
                              setState(() {
                                dirty = true;
                              });
                            },
                            child: Column(
                              children: <Widget>[
                                FormBuilderTextField(
                                  name: 'name',
                                  key: const Key('dashboard_name_field'),
                                  initialValue: widget.dashboard.name,
                                  decoration: InputDecoration(
                                    labelText:
                                        context.messages.dashboardNameLabel,
                                    hintText: 'Enter dashboard name',
                                  ),
                                  onChanged: (_) {
                                    setState(() {
                                      dirty = true;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                FormBuilderTextField(
                                  name: 'description',
                                  key: const Key(
                                      'dashboard_description_field'),
                                  initialValue:
                                      widget.dashboard.description,
                                  decoration: InputDecoration(
                                    labelText: context
                                        .messages.dashboardDescriptionLabel,
                                    hintText: 'Enter dashboard description',
                                  ),
                                  onChanged: (_) {
                                    setState(() {
                                      dirty = true;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                FormSwitch(
                                    name: 'private',
                                    initialValue: widget.dashboard.private,
                                  title: context.messages.dashboardPrivateLabel,
                                    activeColor: context.colorScheme.error,
                                ),
                                FormSwitch(
                                    name: 'active',
                                    initialValue: widget.dashboard.active,
                                  title: context.messages.dashboardActiveLabel,
                                    activeColor: starredGold,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child:
                                      StreamBuilder<List<CategoryDefinition>>(
                                    stream: _db.watchCategories(),
                                    builder: (
                                      BuildContext context,
                                      AsyncSnapshot<List<CategoryDefinition>>
                                          snapshot,
                                    ) {
                                      final categories = snapshot.data ?? [];

                                      // Create dropdown items from actual categories
                                      final categoryItems = [
                                        const DropdownMenuItem<String>(
                                          child: Text('Select a category'),
                                        ),
                                        ...categories.map((category) =>
                                            DropdownMenuItem<String>(
                                              value: category.id,
                                              child: Text(category.name),
                                            )),
                                      ];

                                      return DropdownButtonFormField<String>(
                                        decoration: InputDecoration(
                                          labelText: context
                                              .messages.dashboardCategoryLabel,
                                          hintText: 'Select a category',
                                        ),
                                        value: categories.any(
                                                (cat) => cat.id == categoryId)
                                            ? categoryId
                                            : null,
                                        items: categoryItems,
                                        onChanged: setCategory,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Theme(
                            data: Theme.of(context).copyWith(
                              cardTheme: Theme.of(context).cardTheme.copyWith(
                                    color: Theme.of(context).primaryColorLight,
                                  ),
                            ),
                            child: ReorderableListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              onReorder: (int oldIndex, int newIndex) {
                                setState(() {
                                  dirty = true;

                                  final movedItem = dashboardItems.removeAt(
                                    oldIndex,
                                  );
                                  final insertionIndex = newIndex > oldIndex
                                      ? newIndex - 1
                                      : newIndex;
                                  dashboardItems.insert(
                                    insertionIndex,
                                    movedItem,
                                  );
                                });
                              },
                              children: List.generate(
                                dashboardItems.length,
                                (int index) {
                                  final items = dashboardItems;
                                  final item = items.elementAt(
                                    index,
                                  );

                                  return Dismissible(
                                    onDismissed: (_) {
                                      dismissItem(index);
                                    },
                                    key: Key(
                                      'dashboard-item-${item.hashCode}-$index',
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            Theme.of(context).cardTheme.color,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListTile(
                                        title: Text(_getItemTitle(item)),
                                        subtitle: Text(_getItemSubtitle(item)),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit),
                                              onPressed: () async {
                                                final item =
                                                    dashboardItems[index];
                                                if (item
                                                    is DashboardMeasurementItem) {
                                                  final newAggregation =
                                                      await showDialog<
                                                          AggregationType>(
                                                    context: context,
                                                    builder: (context) {
                                                      AggregationType?
                                                          selected =
                                                          item.aggregationType ??
                                                              AggregationType
                                                                  .dailySum;
                                                      return AlertDialog(
                                                        title: const Text(
                                                            'Edit Measurement'),
                                                        content: DropdownButton<
                                                            AggregationType>(
                                                          value: selected,
                                                          items: AggregationType
                                                              .values
                                                              .map((agg) =>
                                                                  DropdownMenuItem(
                                                                    value: agg,
                                                                    child: Text(agg
                                                                        .toString()
                                                                        .split(
                                                                            '.')
                                                                        .last),
                                                                  ))
                                                              .toList(),
                                                          onChanged: (agg) {
                                                            selected = agg;
                                                            (context as Element)
                                                                .markNeedsBuild();
                                                          },
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                        context)
                                                                    .pop(),
                                                            child: const Text(
                                                                'Cancel'),
                                                          ),
                                                          ElevatedButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                        context)
                                                                    .pop(
                                                                        selected),
                                                            child: const Text(
                                                                'Save'),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                  if (newAggregation != null) {
                                                    updateItem(
                                                      item.copyWith(
                                                          aggregationType:
                                                              newAggregation),
                                                      index,
                                                    );
                                                  }
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                MdiIcons.trashCanOutline,
                                              ),
                                              onPressed: () {
                                                dismissItem(index);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Text(
                            context.messages.dashboardAddChartsTitle,
                          ),
                          if (habitSelectItems.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                children: [
                                  Text(
                                    context.messages.dashboardAddHabitTitle,
                                  ),
                                  ...habitSelectItems.map(
                                    (item) => CheckboxListTile(
                                      value: false,
                                      // No multi-select, so no selected value
                                      onChanged: (value) {
                                        if (value!) {
                                          onConfirmAddHabit([item.value]);
                                        }
                                      },
                                      title: Text(item.value.name),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (measurableSelectItems.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                children: [
                                  Text(
                                    context
                                        .messages.dashboardAddMeasurementTitle,
                                  ),
                                  ...measurableSelectItems.map(
                                    (item) => CheckboxListTile(
                                      value: false,
                                      // No multi-select, so no selected value
                                      onChanged: (value) {
                                        if (value!) {
                                          onConfirmAddMeasurement([item.value]);
                                        }
                                      },
                                      title: Text(item.value.displayName),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ChartMultiSelect<HealthTypeConfig>(
                              multiSelectItems: healthSelectItems,
                              onConfirm: onConfirmAddHealthType,
                              title: context.messages.dashboardAddHealthTitle,
                              buttonText:
                                  context.messages.dashboardAddHealthButton,
                              semanticsLabel: 'Add Health Chart',
                              iconData: MdiIcons.stethoscope,
                            ),
                          ChartMultiSelect<DashboardSurveyItem>(
                              multiSelectItems: surveySelectItems,
                              onConfirm: onConfirmAddSurveyType,
                              title: context.messages.dashboardAddSurveyTitle,
                              buttonText:
                                  context.messages.dashboardAddSurveyButton,
                              semanticsLabel: 'Add Survey Chart',
                              iconData: MdiIcons.clipboardOutline,
                            ),
                          ChartMultiSelect<DashboardWorkoutItem>(
                              multiSelectItems: workoutSelectItems,
                              onConfirm: onConfirmAddWorkoutType,
                              title: context.messages.dashboardAddWorkoutTitle,
                              buttonText:
                                  context.messages.dashboardAddWorkoutButton,
                              semanticsLabel: 'Add Workout Chart',
                              iconData: Icons.sports_gymnastics,
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Spacer(),
                                const SizedBox(
                                  width: 8,
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                        icon: const Icon(Icons.copy),
                                        iconSize: settingsIconSize,
                                        tooltip:
                                            context.messages.dashboardCopyHint,
                                      onPressed: () async {
                                        // Save current dashboard first
                                        await saveDashboard();

                                        // Create a copy of the dashboard with a new ID
                                        final copiedDashboard =
                                            widget.dashboard.copyWith(
                                          id: _uuid.v1(),
                                          name:
                                              '${widget.dashboard.name} (Copy)',
                                          createdAt: DateTime.now(),
                                          updatedAt: DateTime.now(),
                                          lastReviewed: DateTime.now(),
                                        );

                                        // Save the copied dashboard
                                        await persistenceLogic
                                            .upsertDashboardDefinition(
                                                copiedDashboard);

                                        // Navigate back to the dashboards list
                                        maybePop();
                                      },
                                    ),
                                    IconButton(
                                        icon: Icon(
                                          MdiIcons.trashCanOutline,
                                        ),
                                        iconSize: settingsIconSize,
                                      tooltip:
                                          context.messages.dashboardDeleteHint,
                                        color: context.colorScheme.outline,
                                        onPressed: () async {
                                          const deleteKey = 'deleteKey';
                                          final result =
                                            await showModalActionSheet<String>(
                                            context: context,
                                          title: context
                                              .messages.dashboardDeleteQuestion,
                                            actions: [
                                              ModalSheetAction(
                                                icon: Icons.warning,
                                                label: context.messages
                                                    .dashboardDeleteConfirm,
                                                key: deleteKey,
                                                isDestructiveAction: true,
                                                isDefaultAction: true,
                                              ),
                                            ],
                                          );

                                          if (result == deleteKey) {
                                            await persistenceLogic
                                                .deleteDashboardDefinition(
                                              widget.dashboard,
                                            );
                                            maybePop();
                                          }
                                        },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class EditDashboardPage extends StatelessWidget {
  EditDashboardPage({
    required this.dashboardId,
    super.key,
  });

  final JournalDb _db = getIt<JournalDb>();
  final String dashboardId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _db.watchDashboardById(dashboardId),
      builder: (
        BuildContext context,
        AsyncSnapshot<DashboardDefinition?> snapshot,
      ) {
        final dashboard = snapshot.data;

        if (dashboard == null) {
          return EmptyScaffoldWithTitle(context.messages.dashboardNotFound);
        }

        return DashboardDefinitionPage(
            dashboard: dashboard,
        );
      },
    );
  }
}
