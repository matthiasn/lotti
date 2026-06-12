import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/dashboards/config/dashboard_workout_config.dart';
import 'package:lotti/features/dashboards/state/survey_data.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/chart_multi_select.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_item_card.dart';
import 'package:lotti/features/settings/ui/widgets/dashboards/dashboard_category.dart';
import 'package:lotti/features/settings/ui/widgets/form/form_switch.dart';
import 'package:lotti/features/settings/ui/widgets/form/settings_form_text_field.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_stream.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:lotti/widgets/settings/settings_detail_scaffold.dart';
import 'package:lotti/widgets/settings/settings_form_action_bar.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

part 'edit_dashboard_page.dart';

class DashboardDefinitionPage extends StatefulWidget {
  const DashboardDefinitionPage({
    required this.dashboard,
    super.key,
    this.formKey,
    this.isCreateMode = false,
  });

  final DashboardDefinition dashboard;
  final GlobalKey<FormBuilderState>? formKey;

  /// Renders the create-flavored chrome: create title, a "Create" primary
  /// action, and no destructive delete action.
  final bool isCreateMode;

  @override
  State<DashboardDefinitionPage> createState() =>
      _DashboardDefinitionPageState();
}

class _DashboardDefinitionPageState extends State<DashboardDefinitionPage> {
  final JournalDb _db = getIt<JournalDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();

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

  @override
  Widget build(BuildContext context) {
    // Beam back to the dashboards list rather than popping the
    // navigator. The page is rendered inline inside V2's desktop
    // detail surface (no Navigator route to pop); on mobile the URL
    // change still pops the detail page off the Beamer stack.
    void backToList() => beamToNamed('/settings/dashboards');

    final formKey = widget.formKey ?? _formKey;

    return StreamBuilder<List<HabitDefinition>>(
      stream: notificationDrivenStream(
        notifications: getIt<UpdateNotifications>(),
        notificationKeys: {habitsNotification, privateToggleNotification},
        fetcher: getIt<JournalDb>().getAllHabitDefinitions,
      ),
      builder:
          (
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
              stream: notificationDrivenStream(
                notifications: getIt<UpdateNotifications>(),
                notificationKeys: {
                  measurablesNotification,
                  privateToggleNotification,
                },
                fetcher: _db.getAllMeasurableDataTypes,
              ),
              builder:
                  (
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

                    final healthSelectItems = healthTypes.keys.map((
                      String typeName,
                    ) {
                      final item = healthTypes[typeName];
                      return MultiSelectItem<HealthTypeConfig>(
                        item!,
                        item.displayName,
                      );
                    }).toList();

                    final surveySelectItems = surveyTypes.keys.map((
                      String typeName,
                    ) {
                      final item = surveyTypes[typeName];
                      return MultiSelectItem<DashboardSurveyItem>(
                        item!,
                        item.surveyName,
                      );
                    }).toList();

                    final workoutSelectItems = workoutTypes.keys.map((
                      String typeName,
                    ) {
                      final item = workoutTypes[typeName];
                      return MultiSelectItem<DashboardWorkoutItem>(
                        item!,
                        item.displayName,
                      );
                    }).toList();

                    void setCategory(String? newCategoryId) {
                      DevLogger.log(
                        name: 'DashboardDefinitionPage',
                        message: 'setCategory $newCategoryId',
                      );
                      categoryId = newCategoryId;
                      setState(() {
                        dirty = true;
                      });
                    }

                    /// Persists the form when it validates; returns null
                    /// (without persisting) when validation fails.
                    Future<DashboardDefinition?> saveDashboard() async {
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

                        await persistenceLogic.upsertDashboardDefinition(
                          dashboard,
                        );
                        return dashboard;
                      }
                      return null;
                    }

                    Future<void> saveDashboardPress() async {
                      final saved = await saveDashboard();
                      if (saved == null || !mounted) return;
                      setState(() {
                        dirty = false;
                      });
                      backToList();
                    }

                    Future<void> copyDashboard() async {
                      final dashboard =
                          await saveDashboard() ?? widget.dashboard;
                      final entityDefinitions = <EntityDefinition>[dashboard];

                      for (final item in dashboard.items) {
                        switch (item) {
                          case DashboardMeasurementItem(:final id):
                            final dataType = await _db
                                .getMeasurableDataTypeById(id);
                            if (dataType != null) {
                              entityDefinitions.add(dataType);
                            }
                          case DashboardHealthItem():
                          case DashboardWorkoutItem():
                          case DashboardSurveyItem():
                          case DashboardHabitItem():
                            break;
                        }
                      }
                      await Clipboard.setData(
                        ClipboardData(
                          text: json.encode(
                            entityDefinitions,
                          ),
                        ),
                      );
                    }

                    Future<void> deleteDashboard() async {
                      const deleteKey = 'deleteKey';
                      final result = await showModalActionSheet<String>(
                        context: context,
                        title: context.messages.dashboardDeleteQuestion,
                        actions: [
                          ModalSheetAction(
                            icon: Icons.warning,
                            label: context.messages.dashboardDeleteConfirm,
                            key: deleteKey,
                            isDestructiveAction: true,
                          ),
                        ],
                      );

                      if (result == deleteKey) {
                        await persistenceLogic.deleteDashboardDefinition(
                          widget.dashboard,
                        );
                        backToList();
                      }
                    }

                    final messages = context.messages;

                    return SettingsDetailScaffold(
                      title: widget.isCreateMode
                          ? messages.settingsDashboardsCreateTitle
                          : messages.settingsDashboardDetailsLabel,
                      onBack: backToList,
                      onSaveShortcut: () {
                        if (dirty) saveDashboardPress();
                      },
                      headerActions: [
                        IconButton(
                          key: const Key('dashboard_copy'),
                          icon: const Icon(Icons.copy),
                          tooltip: messages.dashboardCopyHint,
                          onPressed: copyDashboard,
                        ),
                      ],
                      actionBar: SettingsFormActionBar(
                        primaryLabel: widget.isCreateMode
                            ? messages.createButton
                            : messages.saveButton,
                        onPrimary: saveDashboardPress,
                        primaryEnabled: dirty,
                        secondaryLabel: messages.cancelButton,
                        onSecondary: backToList,
                        destructiveLabel: widget.isCreateMode
                            ? null
                            : messages.deleteButton,
                        onDestructive: widget.isCreateMode
                            ? null
                            : deleteDashboard,
                      ),
                      children: [
                        FormBuilder(
                          key: formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: () {
                            formKey.currentState?.save();
                            setState(() {
                              dirty = true;
                            });
                          },
                          child: SettingsFormSection(
                            title: messages.basicSettings,
                            icon: Icons.dashboard_customize_outlined,
                            children: [
                              SettingsFormTextField(
                                key: const Key('dashboard_name_field'),
                                initialValue: widget.dashboard.name,
                                labelText: messages.dashboardNameLabel,
                                name: 'name',
                                semanticsLabel: 'Dashboard - name field',
                              ),
                              SettingsFormTextField(
                                key: const Key('dashboard_description_field'),
                                initialValue: widget.dashboard.description,
                                labelText: messages.dashboardDescriptionLabel,
                                name: 'description',
                                semanticsLabel: 'Dashboard - description field',
                                fieldRequired: false,
                                multiline: true,
                              ),
                              FormSwitch(
                                name: 'private',
                                initialValue: widget.dashboard.private,
                                title: messages.dashboardPrivateLabel,
                                icon: Icons.lock_outline,
                              ),
                              FormSwitch(
                                name: 'active',
                                initialValue: widget.dashboard.active,
                                title: messages.dashboardActiveLabel,
                                icon: Icons.visibility_outlined,
                              ),
                              SelectDashboardCategoryWidget(
                                setCategory: setCategory,
                                categoryId: categoryId,
                              ),
                            ],
                          ),
                        ),
                        SettingsFormSection(
                          title: messages.dashboardAddChartsTitle,
                          icon: Icons.insert_chart_outlined,
                          children: [
                            if (dashboardItems.isNotEmpty)
                              ReorderableListView(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                onReorderItem: (int oldIndex, int newIndex) {
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
                                      ),
                                    );
                                  },
                                ),
                              ),
                            if (habitSelectItems.isNotEmpty)
                              ChartMultiSelect<HabitDefinition>(
                                multiSelectItems: habitSelectItems,
                                onConfirm: onConfirmAddHabit,
                                title: messages.dashboardAddHabitTitle,
                                buttonText: messages.dashboardAddHabitButton,
                                semanticsLabel: 'Add Habit Chart',
                                iconData: Icons.insights,
                              ),
                            if (measurableSelectItems.isNotEmpty)
                              ChartMultiSelect<MeasurableDataType>(
                                multiSelectItems: measurableSelectItems,
                                onConfirm: onConfirmAddMeasurement,
                                title: messages.dashboardAddMeasurementTitle,
                                buttonText:
                                    messages.dashboardAddMeasurementButton,
                                semanticsLabel: 'Add Measurable Data Chart',
                                iconData: Icons.insights,
                              ),
                            ChartMultiSelect<HealthTypeConfig>(
                              multiSelectItems: healthSelectItems,
                              onConfirm: onConfirmAddHealthType,
                              title: messages.dashboardAddHealthTitle,
                              buttonText: messages.dashboardAddHealthButton,
                              semanticsLabel: 'Add Health Chart',
                              iconData: MdiIcons.stethoscope,
                            ),
                            ChartMultiSelect<DashboardSurveyItem>(
                              multiSelectItems: surveySelectItems,
                              onConfirm: onConfirmAddSurveyType,
                              title: messages.dashboardAddSurveyTitle,
                              buttonText: messages.dashboardAddSurveyButton,
                              semanticsLabel: 'Add Survey Chart',
                              iconData: MdiIcons.clipboardOutline,
                            ),
                            ChartMultiSelect<DashboardWorkoutItem>(
                              multiSelectItems: workoutSelectItems,
                              onConfirm: onConfirmAddWorkoutType,
                              title: messages.dashboardAddWorkoutTitle,
                              buttonText: messages.dashboardAddWorkoutButton,
                              semanticsLabel: 'Add Workout Chart',
                              iconData: Icons.sports_gymnastics,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
            );
          },
    );
  }
}
