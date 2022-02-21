import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MeasurableDataType>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<MeasurableDataType>> snapshot,
      ) {
        List<MeasurableDataType> measurableDataTypes = snapshot.data ?? [];

        final multiSelectItems = measurableDataTypes
            .map((item) => MultiSelectItem<MeasurableDataType>(
                  item,
                  item.displayName,
                ))
            .toList();

        final Set<String> priorSelection =
            widget.dashboard.items.map((e) => e.id).toSet();

        List<MeasurableDataType> initialSelection = measurableDataTypes
            .where((e) => priorSelection.contains(e.id))
            .toList();

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
          body: Padding(
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
                        const SizedBox(
                          height: 24,
                        ),
                        if (multiSelectItems.isNotEmpty)
                          MultiSelectDialogField<MeasurableDataType?>(
                            searchable: true,
                            backgroundColor: AppColors.bodyBgColor,
                            items: multiSelectItems,
                            initialValue: initialSelection,
                            title: Text(
                              "Measurement Types",
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
                            selectedItemsTextStyle: multiSelectStyle.copyWith(
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
                              "Measurement types",
                              style: TextStyle(
                                color: AppColors.entryTextColor,
                                fontSize: 16,
                              ),
                            ),
                            onConfirm: (List<MeasurableDataType?> selection) {
                              dashboardItems = [];
                              for (MeasurableDataType? selected in selection) {
                                if (selected != null) {
                                  dashboardItems?.add(DashboardItem.measurement(
                                      id: selected.id));
                                }
                              }
                            },
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
                                    persistenceLogic.upsertDashboardDefinition(
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
        );
      },
    );
  }
}
