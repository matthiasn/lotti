import 'dart:convert';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/settings/dashboards/chart_multi_select.dart';
import 'package:lotti/pages/settings/dashboards/dashboard_item_card.dart';
import 'package:lotti/pages/settings/form_text_field.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_config.dart';
import 'package:lotti/widgets/charts/dashboard_survey_data.dart';
import 'package:lotti/widgets/charts/dashboard_workout_config.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class DashboardDetailPage extends StatefulWidget {
  const DashboardDetailPage({
    Key? key,
    required this.dashboard,
  }) : super(key: key);

  final DashboardDefinition dashboard;

  @override
  State<DashboardDetailPage> createState() => _DashboardDetailPageState();
}

class _DashboardDetailPageState extends State<DashboardDetailPage> {
  final TagsService tagsService = getIt<TagsService>();
  final JournalDb _db = getIt<JournalDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();

  late final Stream<List<MeasurableDataType>> stream =
      _db.watchMeasurableDataTypes();

  late List<DashboardItem> dashboardItems;

  @override
  void initState() {
    super.initState();
    dashboardItems = [...widget.dashboard.items];
  }

  void onConfirmAddMeasurement(List<MeasurableDataType?> selection) {
    for (MeasurableDataType? selected in selection) {
      if (selected != null) {
        bool exists = dashboardItems.where(
          (DashboardItem item) {
            return item.maybeMap(
              measurement: (m) => m.id == selected.id,
              orElse: () => false,
            );
          },
        ).isNotEmpty;

        if (!exists) {
          setState(() {
            dashboardItems.add(DashboardItem.measurement(id: selected.id));
          });
        }
      }
    }
  }

  void onConfirmAddHealthType(List<HealthTypeConfig?> selection) {
    dashboardItems = dashboardItems;
    for (HealthTypeConfig? selected in selection) {
      if (selected != null) {
        bool exists = dashboardItems.where(
          (DashboardItem item) {
            return item.maybeMap(
              healthChart: (h) => h.healthType == selected.healthType,
              orElse: () => false,
            );
          },
        ).isNotEmpty;

        if (!exists) {
          setState(() {
            dashboardItems.add(DashboardItem.healthChart(
              color: 'color',
              healthType: selected.healthType,
            ));
          });
        }
      }
    }
  }

  void onConfirmAddSurveyType(List<DashboardSurveyItem?> selection) {
    for (DashboardSurveyItem? selected in selection) {
      if (selected != null) {
        bool exists = dashboardItems.where(
          (DashboardItem item) {
            return item.maybeMap(
              surveyChart: (survey) => survey.surveyType == selected.surveyType,
              orElse: () => false,
            );
          },
        ).isNotEmpty;

        if (!exists) {
          setState(() {
            dashboardItems.add(selected);
          });
        }
      }
    }
  }

  void onConfirmAddWorkoutType(List<DashboardWorkoutItem?> selection) {
    for (DashboardWorkoutItem? selected in selection) {
      if (selected != null) {
        bool exists = dashboardItems.where(
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
            dashboardItems.add(selected);
          });
        }
      }
    }
  }

  void onConfirmAddStoryTimeType(List<DashboardStoryTimeItem?> selection) {
    for (DashboardStoryTimeItem? selected in selection) {
      if (selected != null) {
        bool exists = dashboardItems.where(
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
            dashboardItems.add(selected);
          });
        }
      }
    }
  }

  void dismissItem(int index) {
    setState(() {
      dashboardItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
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

        Future<DashboardDefinition> saveDashboard() async {
          _formKey.currentState!.save();
          if (_formKey.currentState!.validate()) {
            final formData = _formKey.currentState?.value;
            DashboardDefinition dashboard = widget.dashboard.copyWith(
              name: '${formData!['name']}'.trim(),
              description: '${formData['description']}'.trim(),
              private: formData['private'],
              active: formData['active'],
              reviewAt: formData['review_at'],
              updatedAt: DateTime.now(),
              items: dashboardItems ?? widget.dashboard.items,
            );

            await persistenceLogic.upsertDashboardDefinition(dashboard);
            return dashboard;
          }
          return widget.dashboard;
        }

        Future<void> saveDashboardPress() async {
          await saveDashboard();
          context.router.pop();
        }

        Future<void> saveAndViewDashboard() async {
          await saveDashboard();
          pushNamedRoute('/dashboards/${widget.dashboard.id}');
        }

        Future<void> copyDashboard() async {
          DashboardDefinition dashboard = await saveDashboard();
          List<EntityDefinition> entityDefinitions = [dashboard];

          for (DashboardItem item in dashboard.items) {
            await item.map(
              measurement: (DashboardMeasurementItem measurementItem) async {
                MeasurableDataType? dataType =
                    await _db.getMeasurableDataTypeById(measurementItem.id);
                if (dataType != null) {
                  entityDefinitions.add(dataType);
                }
              },
              healthChart: (_) {},
              workoutChart: (_) {},
              surveyChart: (_) {},
              storyTimeChart: (_) {},
            );
          }
          Clipboard.setData(
              ClipboardData(text: json.encode(entityDefinitions)));
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
                                labelText: localizations.dashboardNameLabel,
                                name: 'name',
                                key: const Key('dashboard_name_field'),
                              ),
                              FormTextField(
                                initialValue: widget.dashboard.description,
                                labelText:
                                    localizations.dashboardDescriptionLabel,
                                name: 'description',
                                key: const Key('dashboard_description_field'),
                              ),
                              FormBuilderSwitch(
                                name: 'private',
                                initialValue: widget.dashboard.private,
                                title: Text(
                                  localizations.dashboardPrivateLabel,
                                  style: formLabelStyle,
                                ),
                                activeColor: AppColors.private,
                              ),
                              FormBuilderSwitch(
                                name: 'active',
                                initialValue: widget.dashboard.active,
                                title: Text(
                                  localizations.dashboardActiveLabel,
                                  style: formLabelStyle,
                                ),
                                activeColor: AppColors.starredGold,
                              ),
                              FormBuilderCupertinoDateTimePicker(
                                name: 'review_at',
                                alwaysUse24HourFormat: true,
                                format: DateFormat('HH:mm'),
                                inputType:
                                    CupertinoDateTimePickerInputType.time,
                                style: inputStyle.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w300,
                                  fontFamily: 'Oswald',
                                ),
                                initialValue: widget.dashboard.reviewAt,
                                decoration: InputDecoration(
                                  labelText:
                                      localizations.dashboardReviewTimeLabel,
                                  labelStyle: labelStyle,
                                ),
                                theme: DatePickerTheme(
                                  headerColor: AppColors.headerBgColor,
                                  backgroundColor: AppColors.bodyBgColor,
                                  itemStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                  doneStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
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
                        Text(
                          localizations.dashboardAddChartsTitle,
                          style: formLabelStyle,
                        ),
                        if (measurableSelectItems.isNotEmpty)
                          ChartMultiSelect<MeasurableDataType>(
                            multiSelectItems: measurableSelectItems,
                            onConfirm: onConfirmAddMeasurement,
                            title: localizations.dashboardAddMeasurementTitle,
                            buttonText:
                                localizations.dashboardAddMeasurementButton,
                            iconData: MdiIcons.tapeMeasure,
                          ),
                        ChartMultiSelect<HealthTypeConfig>(
                          multiSelectItems: healthSelectItems,
                          onConfirm: onConfirmAddHealthType,
                          title: localizations.dashboardAddHealthTitle,
                          buttonText: localizations.dashboardAddHealthButton,
                          iconData: MdiIcons.stethoscope,
                        ),
                        ChartMultiSelect<DashboardSurveyItem>(
                          multiSelectItems: surveySelectItems,
                          onConfirm: onConfirmAddSurveyType,
                          title: localizations.dashboardAddSurveyTitle,
                          buttonText: localizations.dashboardAddSurveyButton,
                          iconData: MdiIcons.clipboardOutline,
                        ),
                        ChartMultiSelect<DashboardWorkoutItem>(
                          multiSelectItems: workoutSelectItems,
                          onConfirm: onConfirmAddWorkoutType,
                          title: localizations.dashboardAddWorkoutTitle,
                          buttonText: localizations.dashboardAddWorkoutButton,
                          iconData: Icons.sports_gymnastics,
                        ),
                        ChartMultiSelect<DashboardStoryTimeItem>(
                          multiSelectItems: storySelectItems,
                          onConfirm: onConfirmAddStoryTimeType,
                          title: localizations.dashboardAddStoryTitle,
                          buttonText: localizations.dashboardAddStoryButton,
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
                                child: Text(
                                  localizations.dashboardSaveLabel,
                                  style: saveButtonStyle,
                                ),
                              ),
                              TextButton(
                                key: const Key('dashboard_view'),
                                onPressed: saveAndViewDashboard,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: Text(
                                    localizations.dashboardSaveViewLabel,
                                    style: saveButtonStyle,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    iconSize: 24,
                                    tooltip: localizations.dashboardCopyHint,
                                    color: AppColors.appBarFgColor,
                                    onPressed: copyDashboard,
                                  ),
                                  IconButton(
                                    icon: const Icon(MdiIcons.trashCanOutline),
                                    iconSize: 24,
                                    tooltip: localizations.dashboardDeleteHint,
                                    color: AppColors.appBarFgColor,
                                    onPressed: () async {
                                      const deleteKey = 'deleteKey';
                                      final result =
                                          await showModalActionSheet<String>(
                                        context: context,
                                        title: localizations
                                            .dashboardDeleteQuestion,
                                        actions: [
                                          SheetAction(
                                            icon: Icons.warning,
                                            label: localizations
                                                .dashboardDeleteConfirm,
                                            key: deleteKey,
                                          ),
                                        ],
                                      );

                                      if (result == deleteKey) {
                                        persistenceLogic
                                            .upsertDashboardDefinition(
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
