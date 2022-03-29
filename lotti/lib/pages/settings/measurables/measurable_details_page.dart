import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/settings/form_text_field.dart';
import 'package:lotti/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

const double iconSize = 24.0;

class MeasurableDetailsPage extends StatefulWidget {
  const MeasurableDetailsPage({
    Key? key,
    required this.dataType,
  }) : super(key: key);

  final MeasurableDataType dataType;

  @override
  _MeasurableDetailsPageState createState() {
    return _MeasurableDetailsPageState();
  }
}

class _MeasurableDetailsPageState extends State<MeasurableDetailsPage> {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    final MeasurableDataType item = widget.dataType;

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
                            initialValue: item.name,
                            labelText: 'Name',
                            name: 'name',
                          ),
                          FormTextField(
                            initialValue: item.displayName,
                            labelText: 'Display name',
                            name: 'displayName',
                          ),
                          FormTextField(
                            initialValue: item.description,
                            labelText: 'Description',
                            name: 'description',
                          ),
                          FormTextField(
                            initialValue: item.unitName,
                            labelText: 'Unit abbreviation',
                            name: 'unitName',
                          ),
                          FormBuilderSwitch(
                            name: 'private',
                            initialValue: item.private,
                            title: Text(
                              'Private: ',
                              style: formLabelStyle,
                            ),
                            activeColor: AppColors.private,
                          ),
                          FormBuilderSwitch(
                            name: 'favorite',
                            initialValue: item.favorite,
                            title: Text(
                              'Favorite: ',
                              style: formLabelStyle,
                            ),
                            activeColor: AppColors.starredGold,
                          ),
                          FormBuilderDropdown(
                            name: 'aggregationType',
                            initialValue: item.aggregationType,
                            decoration: InputDecoration(
                              labelText: 'Aggregation Type:',
                              labelStyle: labelStyle,
                            ),
                            style: const TextStyle(fontSize: 48),
                            allowClear: true,
                            dropdownColor: AppColors.headerBgColor,
                            hint: Text(
                              'Select aggregation type',
                              style: formLabelStyle.copyWith(
                                fontSize: 12,
                              ),
                            ),
                            items:
                                AggregationType.values.map((aggregationType) {
                              return DropdownMenuItem(
                                value: aggregationType,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    '$aggregationType',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.entryTextColor,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () async {
                              _formKey.currentState!.save();
                              if (_formKey.currentState!.validate()) {
                                final formData = _formKey.currentState?.value;
                                debugPrint('$formData');
                                MeasurableDataType dataType = item.copyWith(
                                  name: '${formData!['name']}'
                                      .trim()
                                      .replaceAll(' ', '_')
                                      .toLowerCase(),
                                  description:
                                      '${formData['description']}'.trim(),
                                  unitName: '${formData['unitName']}'.trim(),
                                  displayName:
                                      '${formData['displayName']}'.trim(),
                                  private: formData['private'],
                                  favorite: formData['favorite'],
                                  aggregationType: formData['aggregationType'],
                                );

                                persistenceLogic
                                    .upsertEntityDefinition(dataType);
                                context.router.pop();
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
                          IconButton(
                            icon: const Icon(MdiIcons.trashCanOutline),
                            iconSize: 24,
                            tooltip: 'Delete',
                            color: AppColors.appBarFgColor,
                            onPressed: () {
                              persistenceLogic.upsertEntityDefinition(
                                item.copyWith(
                                  deletedAt: DateTime.now(),
                                ),
                              );
                              context.router.pop();
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
  }
}

class EditMeasurablePage extends StatelessWidget {
  final JournalDb _db = getIt<JournalDb>();
  final String measurableId;

  EditMeasurablePage({
    Key? key,
    @PathParam() required this.measurableId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _db.watchMeasurableDataTypeById(measurableId),
      builder: (
        BuildContext context,
        AsyncSnapshot<MeasurableDataType?> snapshot,
      ) {
        MeasurableDataType? dataType = snapshot.data;

        if (dataType == null) {
          return const SizedBox.shrink();
        }

        return MeasurableDetailsPage(
          dataType: dataType,
        );
      },
    );
  }
}
