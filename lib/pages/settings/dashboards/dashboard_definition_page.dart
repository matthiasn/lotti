import 'dart:convert';
import 'dart:io';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/pages/settings/dashboards/chart_multi_select.dart';
import 'package:lotti/pages/settings/dashboards/dashboard_item_card.dart';
import 'package:lotti/pages/settings/form_text_field.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/charts/dashboard_health_config.dart';
import 'package:lotti/widgets/charts/dashboard_survey_data.dart';
import 'package:lotti/widgets/charts/dashboard_workout_config.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class DashboardDefinitionPage extends StatefulWidget {
  const DashboardDefinitionPage({
    super.key,
    required this.dashboard,
    this.formKey,
  });

  final DashboardDefinition dashboard;
  final GlobalKey<FormBuilderState>? formKey;

  @override
  State<DashboardDefinitionPage> createState() =>
      _DashboardDefinitionPageState();
}

class _DashboardDefinitionPageState extends State<DashboardDefinitionPage> {
  final TagsService tagsService = getIt<TagsService>();
  final JournalDb _db = getIt<JournalDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();
  bool dirty = false;

  late final Stream<List<MeasurableDataType>> stream =
      _db.watchMeasurableDataTypes();

  late List<DashboardItem> dashboardItems;

  @override
  void initState() {
    super.initState();
    dashboardItems = [...widget.dashboard.items];
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

  void onConfirmAddHealthType(List<HealthTypeConfig?> selection) {
    dashboardItems = dashboardItems;
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

  void onConfirmAddStoryTimeType(List<DashboardStoryTimeItem?> selection) {
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

  @override
  Widget build(BuildContext context) {
    final formKey = widget.formKey ?? _formKey;
    final localizations = AppLocalizations.of(context)!;
    return StreamBuilder<List<MeasurableDataType>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<MeasurableDataType>> snapshot,
      ) {
        final measurableDataTypes = snapshot.data ?? [];

        final measurableSelectItems = measurableDataTypes
            .map(
              (item) => MultiSelectItem<MeasurableDataType>(
                item,
                item.displayName,
              ),
            )
            .toList();

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

        final storySelectItems =
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
          // TODO: mock the router & remove
          if (!Platform.environment.containsKey('FLUTTER_TEST')) {
            await context.router.pop();
          }
        }

        Future<void> copyDashboard() async {
          final dashboard = await saveDashboard();
          final entityDefinitions = <EntityDefinition>[dashboard];

          for (final item in dashboard.items) {
            await item.map(
              measurement: (DashboardMeasurementItem measurementItem) async {
                final dataType =
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
          await Clipboard.setData(
            ClipboardData(text: json.encode(entityDefinitions)),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.bodyBgColor,
          appBar: TitleAppBar(
            title: localizations.settingsDashboardsTitle,
            actions: [
              if (dirty)
                TextButton(
                  key: const Key('dashboard_save'),
                  onPressed: saveDashboardPress,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      localizations.dashboardSaveLabel,
                      style: saveButtonStyle,
                    ),
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: AppColors.headerBgColor,
                      padding: const EdgeInsets.all(24),
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
                                  fieldRequired: false,
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
                                  format: hhMmFormat,
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
                                  dashboardItems = dashboardItems;
                                  final movedItem =
                                      dashboardItems.removeAt(oldIndex);
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
                                  final item = items.elementAt(index);

                                  return Dismissible(
                                    onDismissed: (_) {
                                      dismissItem(index);
                                    },
                                    key: Key(
                                      'dashboard-item-${item.hashCode}-$index',
                                    ),
                                    child: DashboardItemCard(
                                      item: item,
                                      index: index,
                                      updateItemFn: updateItem,
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
                              iconData: Icons.insights,
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
                            padding: const EdgeInsets.only(top: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Spacer(),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy),
                                      iconSize: settingsIconSize,
                                      tooltip: localizations.dashboardCopyHint,
                                      color: AppColors.appBarFgColor,
                                      onPressed: copyDashboard,
                                    ),
                                    IconButton(
                                      icon:
                                          const Icon(MdiIcons.trashCanOutline),
                                      iconSize: settingsIconSize,
                                      tooltip:
                                          localizations.dashboardDeleteHint,
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
                                              isDestructiveAction: true,
                                              isDefaultAction: true,
                                            ),
                                          ],
                                        );

                                        if (result == deleteKey) {
                                          await persistenceLogic
                                              .upsertDashboardDefinition(
                                            widget.dashboard.copyWith(
                                              deletedAt: DateTime.now(),
                                            ),
                                          );

                                          // TODO: mock the router & remove
                                          if (!Platform.environment
                                              .containsKey('FLUTTER_TEST')) {
                                            await context.router.pop();
                                          }
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
          ),
        );
      },
    );
  }
}

class EditDashboardPage extends StatelessWidget {
  EditDashboardPage({
    super.key,
    @PathParam() required this.dashboardId,
  });

  final JournalDb _db = getIt<JournalDb>();
  final String dashboardId;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder(
      stream: _db.watchDashboardById(dashboardId),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<DashboardDefinition>> snapshot,
      ) {
        DashboardDefinition? dashboard;
        final data = snapshot.data ?? [];
        if (data.isNotEmpty) {
          dashboard = data.first;
        }

        if (dashboard == null) {
          return EmptyScaffoldWithTitle(localizations.dashboardNotFound);
        }

        return DashboardDefinitionPage(
          dashboard: dashboard,
        );
      },
    );
  }
}
