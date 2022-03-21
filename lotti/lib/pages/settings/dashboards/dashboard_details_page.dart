import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/settings/dashboards/chart_multi_select.dart';
import 'package:lotti/pages/settings/dashboards/dashboard_item_card.dart';
import 'package:lotti/pages/settings/form_text_field.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_config.dart';
import 'package:lotti/widgets/charts/dashboard_survey_data.dart';
import 'package:lotti/widgets/charts/dashboard_workout_config.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class DashboardDetailPage extends StatefulWidget {
  const DashboardDetailPage({
    Key? key,
    required this.dashboard,
  }) : super(key: key);

  final DashboardDefinition dashboard;

  @override
  _DashboardDetailPageState createState() {
    return _DashboardDetailPageState();
  }
}

class _DashboardDetailPageState extends State<DashboardDetailPage> {
  final TagsService tagsService = getIt<TagsService>();
  final JournalDb _db = getIt<JournalDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();

  late final Stream<List<MeasurableDataType>> stream =
      _db.watchMeasurableDataTypes();

  List<DashboardItem>? dashboardItems;

  void onConfirmAddMeasurement(List<MeasurableDataType?> selection) {
    dashboardItems = dashboardItems ?? widget.dashboard.items;

    for (MeasurableDataType? selected in selection) {
      if (selected != null) {
        bool exists = dashboardItems!.where(
          (DashboardItem item) {
            return item.maybeMap(
              measurement: (m) => m.id == selected.id,
              orElse: () => false,
            );
          },
        ).isNotEmpty;

        if (!exists) {
          setState(() {
            dashboardItems?.add(DashboardItem.measurement(id: selected.id));
          });
        }
      }
    }
  }

  void onConfirmAddHealthType(List<HealthTypeConfig?> selection) {
    dashboardItems = dashboardItems ?? widget.dashboard.items;

    for (HealthTypeConfig? selected in selection) {
      if (selected != null) {
        bool exists = dashboardItems!.where(
          (DashboardItem item) {
            return item.maybeMap(
              healthChart: (m) => m.healthType == selected.healthType,
              orElse: () => false,
            );
          },
        ).isNotEmpty;

        if (!exists) {
          setState(() {
            dashboardItems?.add(
              DashboardItem.healthChart(
                color: 'color',
                healthType: selected.healthType,
              ),
            );
          });
        }
      }
    }
  }

  void onConfirmAddSurveyType(List<DashboardSurveyItem?> selection) {
    dashboardItems = dashboardItems ?? widget.dashboard.items;

    for (DashboardSurveyItem? selected in selection) {
      if (selected != null) {
        bool exists = dashboardItems!.where(
          (DashboardItem item) {
            return item.maybeMap(
              surveyChart: (survey) => survey.surveyType == selected.surveyType,
              orElse: () => false,
            );
          },
        ).isNotEmpty;

        if (!exists) {
          setState(() {
            dashboardItems?.add(
              selected,
            );
          });
        }
      }
    }
  }

  void onConfirmAddWorkoutType(List<DashboardWorkoutItem?> selection) {
    dashboardItems = dashboardItems ?? widget.dashboard.items;

    for (DashboardWorkoutItem? selected in selection) {
      if (selected != null) {
        bool exists = dashboardItems!.where(
          (DashboardItem item) {
            return item.maybeMap(
              workoutChart: (workout) =>
                  workout.workoutType == selected.workoutType &&
                  workout.valueType == selected.valueType,
              orElse: () => false,
            );
          },
        ).isNotEmpty;

        if (!exists) {
          setState(() {
            dashboardItems?.add(
              selected,
            );
          });
        }
      }
    }
  }

  void onConfirmAddStoryTimeType(List<DashboardStoryTimeItem?> selection) {
    dashboardItems = dashboardItems ?? widget.dashboard.items;

    for (DashboardStoryTimeItem? selected in selection) {
      if (selected != null) {
        bool exists = dashboardItems!.where(
          (DashboardItem item) {
            return item.maybeMap(
              storyTimeChart: (storyTime) =>
                  storyTime.storyTagId == selected.storyTagId,
              orElse: () => false,
            );
          },
        ).isNotEmpty;

        if (!exists) {
          setState(() {
            dashboardItems?.add(
              selected,
            );
          });
        }
      }
    }
  }

  void dismissItem(int index) {
    setState(() {
      dashboardItems = dashboardItems ?? widget.dashboard.items;
      dashboardItems!.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MeasurableDataType>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<MeasurableDataType>> snapshot,
      ) {
        List<MeasurableDataType> measurableDataTypes = snapshot.data ?? [];

        final List<MultiSelectItem<MeasurableDataType>> measurableSelectItems =
            measurableDataTypes
                .map((item) => MultiSelectItem<MeasurableDataType>(
                      item,
                      item.displayName,
                    ))
                .toList();

        final List<MultiSelectItem<HealthTypeConfig>> healthSelectItems =
            healthTypes.keys.map((String typeName) {
          HealthTypeConfig? item = healthTypes[typeName];
          return MultiSelectItem<HealthTypeConfig>(
            item!,
            item.displayName,
          );
        }).toList();

        final List<MultiSelectItem<DashboardSurveyItem>> surveySelectItems =
            surveyTypes.keys.map((String typeName) {
          DashboardSurveyItem? item = surveyTypes[typeName];
          return MultiSelectItem<DashboardSurveyItem>(
            item!,
            item.surveyName,
          );
        }).toList();

        final List<MultiSelectItem<DashboardWorkoutItem>> workoutSelectItems =
            workoutTypes.keys.map((String typeName) {
          DashboardWorkoutItem? item = workoutTypes[typeName];
          return MultiSelectItem<DashboardWorkoutItem>(
            item!,
            item.displayName,
          );
        }).toList();

        final List<MultiSelectItem<DashboardStoryTimeItem>> storySelectItems =
            tagsService.getAllStoryTags().map((StoryTag storyTag) {
          return MultiSelectItem<DashboardStoryTimeItem>(
            DashboardStoryTimeItem(
              storyTagId: storyTag.id,
              color: '#0000FF',
            ),
            storyTag.tag,
          );
        }).toList();

        Future<void> saveDashboard() async {
          _formKey.currentState!.save();
          if (_formKey.currentState!.validate()) {
            final formData = _formKey.currentState?.value;
            DashboardDefinition dashboard = widget.dashboard.copyWith(
              name: '${formData!['name']}'.trim(),
              description: '${formData['description']}'.trim(),
              private: formData['private'],
              active: formData['active'],
              updatedAt: DateTime.now(),
              items: dashboardItems ?? widget.dashboard.items,
            );

            persistenceLogic.upsertDashboardDefinition(dashboard);
          }
        }

        Future<void> saveDashboardPress() async {
          await saveDashboard();
          context.router.pop();
        }

        Future<void> saveAndViewDashboard() async {
          await saveDashboard();
          context.router.pushNamed('/dashboards/${widget.dashboard.id}');
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: AppColors.headerBgColor,
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        FormBuilder(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            children: <Widget>[
                              FormTextField(
                                initialValue: widget.dashboard.name,
                                labelText: 'Name',
                                name: 'name',
                                key: const Key('dashboard_name_field'),
                              ),
                              FormTextField(
                                initialValue: widget.dashboard.description,
                                labelText: 'Description',
                                name: 'description',
                                key: const Key('dashboard_description_field'),
                              ),
                              FormBuilderSwitch(
                                name: 'private',
                                initialValue: widget.dashboard.private,
                                title: Text(
                                  'Private: ',
                                  style: formLabelStyle,
                                ),
                                activeColor: AppColors.private,
                              ),
                              FormBuilderSwitch(
                                name: 'active',
                                initialValue: widget.dashboard.active,
                                title: Text(
                                  'Active: ',
                                  style: formLabelStyle,
                                ),
                                activeColor: AppColors.starredGold,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Theme(
                          data: ThemeData(canvasColor: Colors.transparent),
                          child: ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            onReorder: (int oldIndex, int newIndex) {
                              setState(() {
                                dashboardItems =
                                    dashboardItems ?? widget.dashboard.items;
                                final movedItem =
                                    dashboardItems!.removeAt(oldIndex);
                                final insertionIndex = newIndex > oldIndex
                                    ? newIndex - 1
                                    : newIndex;
                                dashboardItems!
                                    .insert(insertionIndex, movedItem);
                              });
                            },
                            children: List.generate(
                              (dashboardItems ?? widget.dashboard.items).length,
                              (int index) {
                                List<DashboardItem> items =
                                    dashboardItems ?? widget.dashboard.items;
                                DashboardItem item = items.elementAt(index);

                                return Dismissible(
                                  onDismissed: (_) {
                                    dismissItem(index);
                                  },
                                  key: Key('dashboard-item-${item.hashCode}'),
                                  child: DashboardItemCard(
                                    item: item,
                                    measurableTypes: measurableDataTypes,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        if (measurableSelectItems.isNotEmpty)
                          ChartMultiSelect<MeasurableDataType>(
                            multiSelectItems: measurableSelectItems,
                            onConfirm: onConfirmAddMeasurement,
                            title: 'Add Measurement Charts',
                            buttonText: 'Add Measurement Charts',
                            iconData: MdiIcons.tapeMeasure,
                          ),
                        ChartMultiSelect<HealthTypeConfig>(
                          multiSelectItems: healthSelectItems,
                          onConfirm: onConfirmAddHealthType,
                          title: 'Add Health Charts',
                          buttonText: 'Add Health Charts',
                          iconData: MdiIcons.stethoscope,
                        ),
                        ChartMultiSelect<DashboardSurveyItem>(
                          multiSelectItems: surveySelectItems,
                          onConfirm: onConfirmAddSurveyType,
                          title: 'Add Survey Charts',
                          buttonText: 'Add Survey Charts',
                          iconData: MdiIcons.clipboardOutline,
                        ),
                        ChartMultiSelect<DashboardWorkoutItem>(
                          multiSelectItems: workoutSelectItems,
                          onConfirm: onConfirmAddWorkoutType,
                          title: 'Add Workout Charts',
                          buttonText: 'Add Workout Charts',
                          iconData: Icons.sports_gymnastics,
                        ),
                        ChartMultiSelect<DashboardStoryTimeItem>(
                          multiSelectItems: storySelectItems,
                          onConfirm: onConfirmAddStoryTimeType,
                          title: 'Add Story/Time Charts',
                          buttonText: 'Add Story/Time Charts',
                          iconData: MdiIcons.watch,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                key: const Key('dashboard_save'),
                                onPressed: saveDashboardPress,
                                child: const Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 24.0),
                                  child: Text(
                                    'Save & Close',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontFamily: 'Oswald',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              TextButton(
                                key: const Key('dashboard_view'),
                                onPressed: saveAndViewDashboard,
                                child: const Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 24.0),
                                  child: Text(
                                    'Save & View',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontFamily: 'Oswald',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(MdiIcons.trashCanOutline),
                                iconSize: 24,
                                tooltip: 'Delete',
                                color: AppColors.appBarFgColor,
                                onPressed: () async {
                                  const deleteKey = 'deleteKey';
                                  final result =
                                      await showModalActionSheet<String>(
                                    context: context,
                                    title:
                                        'Do you want to delete this dashboard?',
                                    actions: [
                                      const SheetAction(
                                        icon: Icons.warning,
                                        label: 'Delete dashboard',
                                        key: deleteKey,
                                      ),
                                    ],
                                  );

                                  if (result == deleteKey) {
                                    persistenceLogic.upsertDashboardDefinition(
                                      widget.dashboard.copyWith(
                                        deletedAt: DateTime.now(),
                                      ),
                                    );
                                    context.router.pop();
                                  }
                                },
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
          ),
        );
      },
    );
  }
}

class EditDashboardPage extends StatelessWidget {
  final JournalDb _db = getIt<JournalDb>();
  final String dashboardId;

  EditDashboardPage({
    Key? key,
    @PathParam() required this.dashboardId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _db.watchDashboardById(dashboardId),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<DashboardDefinition>> snapshot,
      ) {
        DashboardDefinition? dashboard;
        var data = snapshot.data ?? [];
        if (data.isNotEmpty) {
          dashboard = data.first;
        }

        if (dashboard == null) {
          return const SizedBox.shrink();
        }

        return DashboardDetailPage(
          dashboard: dashboard,
        );
      },
    );
  }
}
