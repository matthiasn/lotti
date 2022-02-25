import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/widgets/pages/settings/form_text_field.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class DashboardDetailRoute extends StatefulWidget {
  const DashboardDetailRoute({
    Key? key,
    required this.dashboard,
  }) : super(key: key);

  final DashboardDefinition dashboard;

  @override
  _DashboardDetailRouteState createState() {
    return _DashboardDetailRouteState();
  }
}

class _DashboardDetailRouteState extends State<DashboardDetailRoute> {
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

        return Scaffold(
          backgroundColor: AppColors.bodyBgColor,
          appBar: AppBar(
            foregroundColor: AppColors.appBarFgColor,
            title: Text(
              widget.dashboard.name,
              style: TextStyle(
                color: AppColors.entryTextColor,
                fontFamily: 'Oswald',
              ),
            ),
            actions: <Widget>[
              TextButton(
                key: const Key('tag_save'),
                onPressed: () async {
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
                    Navigator.pop(context);
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: 'Oswald',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            backgroundColor: AppColors.headerBgColor,
          ),
          body: SingleChildScrollView(
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
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
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
                                (dashboardItems ?? widget.dashboard.items)
                                    .length,
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
                            SizedBox(
                              width: 280,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 16.0,
                                  right: 16.0,
                                  top: 16,
                                ),
                                child:
                                    MultiSelectDialogField<MeasurableDataType?>(
                                  searchable: true,
                                  backgroundColor: AppColors.bodyBgColor,
                                  items: measurableSelectItems,
                                  initialValue: const [],
                                  title: Text(
                                    "Add Measurement Charts",
                                    style: titleStyle,
                                  ),
                                  checkColor: AppColors.entryTextColor,
                                  selectedColor: Colors.blue,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(40),
                                    ),
                                    border: Border.all(
                                      color: AppColors.entryTextColor,
                                      width: 2,
                                    ),
                                  ),
                                  itemsTextStyle: multiSelectStyle,
                                  selectedItemsTextStyle:
                                      multiSelectStyle.copyWith(
                                    fontWeight: FontWeight.normal,
                                  ),
                                  unselectedColor: AppColors.entryTextColor,
                                  searchIcon: Icon(
                                    Icons.search,
                                    size: 32,
                                    color: AppColors.entryTextColor,
                                  ),
                                  searchTextStyle: formLabelStyle,
                                  searchHintStyle: formLabelStyle,
                                  buttonIcon: Icon(
                                    MdiIcons.tapeMeasure,
                                    color: AppColors.entryTextColor,
                                  ),
                                  buttonText: Text(
                                    "Add Measurement Charts",
                                    style: TextStyle(
                                      color: AppColors.entryTextColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                  onConfirm: onConfirmAddMeasurement,
                                ),
                              ),
                            ),
                          SizedBox(
                            width: 280,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 16.0,
                                right: 16.0,
                                top: 16,
                              ),
                              child: MultiSelectDialogField<HealthTypeConfig?>(
                                searchable: true,
                                backgroundColor: AppColors.bodyBgColor,
                                items: healthSelectItems,
                                initialValue: const [],
                                title: Text(
                                  "Add Health Charts",
                                  style: titleStyle,
                                ),
                                checkColor: AppColors.entryTextColor,
                                selectedColor: Colors.blue,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(40),
                                  ),
                                  border: Border.all(
                                    color: AppColors.entryTextColor,
                                    width: 2,
                                  ),
                                ),
                                itemsTextStyle: multiSelectStyle,
                                selectedItemsTextStyle:
                                    multiSelectStyle.copyWith(
                                  fontWeight: FontWeight.normal,
                                ),
                                unselectedColor: AppColors.entryTextColor,
                                searchIcon: Icon(
                                  Icons.search,
                                  size: 32,
                                  color: AppColors.entryTextColor,
                                ),
                                searchTextStyle: formLabelStyle,
                                searchHintStyle: formLabelStyle,
                                buttonIcon: Icon(
                                  MdiIcons.stethoscope,
                                  color: AppColors.entryTextColor,
                                ),
                                buttonText: Text(
                                  "Add Health Charts",
                                  style: TextStyle(
                                    color: AppColors.entryTextColor,
                                    fontSize: 16,
                                  ),
                                ),
                                onConfirm: onConfirmAddHealthType,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
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
                                      persistenceLogic
                                          .upsertDashboardDefinition(
                                        widget.dashboard.copyWith(
                                          deletedAt: DateTime.now(),
                                        ),
                                      );
                                      Navigator.pop(context);
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
          ),
        );
      },
    );
  }
}

class DashboardItemCard extends StatelessWidget {
  final DashboardItem item;
  final List<MeasurableDataType> measurableTypes;

  const DashboardItemCard({
    Key? key,
    required this.item,
    required this.measurableTypes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String itemName = item.map(
      measurement: (measurement) {
        Iterable<MeasurableDataType> matches =
            measurableTypes.where((m) => measurement.id == m.id);
        if (matches.isNotEmpty) {
          return matches.first.displayName;
        }
        return '';
      },
      healthChart: (healthLineChart) {
        String type = healthLineChart.healthType;
        String itemName = healthTypes[type]?.displayName ?? type;
        return itemName;
      },
      surveyChart: (surveyChart) {
        return surveyChart.surveyType;
      },
    );

    return Card(
      color: AppColors.headerBgColor,
      elevation: 8.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 16,
        ),
        leading: item.map(
          measurement: (_) => Icon(
            MdiIcons.tapeMeasure,
            size: 32,
            color: AppColors.entryTextColor,
          ),
          healthChart: (_) => Icon(
            MdiIcons.stethoscope,
            size: 32,
            color: AppColors.entryTextColor,
          ),
          surveyChart: (_) => Icon(
            MdiIcons.clipboardOutline,
            size: 32,
            color: AppColors.entryTextColor,
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              itemName,
              style: TextStyle(
                color: AppColors.entryTextColor,
                fontFamily: 'Oswald',
                fontSize: 20.0,
              ),
            ),
          ],
        ),
        enabled: true,
      ),
    );
  }
}
