import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/misc/app_bar_version.dart';
import 'package:lotti/widgets/pages/settings/form_text_field.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

const double iconSize = 24.0;

class GoalsPage extends StatefulWidget {
  const GoalsPage({Key? key}) : super(key: key);

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  final JournalDb _db = getIt<JournalDb>();

  late final Stream<List<EntityDefinition>> stream =
      _db.watchEntityDefinitions();

  @override
  void initState() {
    super.initState();
    createDefaults();
  }

  void createDefaults() async {
    DateTime now = DateTime.now();

    _db.upsertEntityDefinition(
      MeasurableGoal(
        id: '9e9e7a62-1e56-4159-a568-12234db7399b',
        createdAt: now,
        updatedAt: now,
        name: 'Drink enough water',
        description: 'At least 2000 ml a day',
        vectorClock: null,
        successCriteria: [
          GoalCriterion(
            measurableTypeId: '9e9e7a62-1e56-4059-a568-12234db7399b',
            min: 2000,
            validFrom: now,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EntityDefinition>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<EntityDefinition>> snapshot,
      ) {
        List<EntityDefinition> items = snapshot.data ?? [];

        return Scaffold(
          appBar: const VersionAppBar(title: 'Goals'),
          backgroundColor: AppColors.bodyBgColor,
          floatingActionButton: FloatingActionButton(
            child: const Icon(MdiIcons.plus, size: 32),
            backgroundColor: AppColors.entryBgColor,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (BuildContext context) {
                    DateTime now = DateTime.now();
                    return DetailRoute(
                      item: MeasurableDataType(
                        id: uuid.v1(),
                        name: '',
                        displayName: '',
                        version: 0,
                        createdAt: now,
                        updatedAt: now,
                        unitName: '',
                        description: '',
                        vectorClock: null,
                      ),
                      index: -1,
                    );
                  },
                ),
              );
            },
          ),
          body: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8.0),
            children: List.generate(
              items.length,
              (int index) {
                return EntityDefinitionCard(
                  item: items.elementAt(index),
                  index: index,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class EntityDefinitionCard extends StatelessWidget {
  final EntityDefinition item;
  final int index;

  const EntityDefinitionCard({
    Key? key,
    required this.item,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Card(
        color: AppColors.headerBgColor,
        elevation: 8.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: SingleChildScrollView(
          child: ListTile(
            contentPadding:
                const EdgeInsets.only(left: 24, top: 4, bottom: 12, right: 24),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    color: AppColors.entryTextColor,
                    fontFamily: 'Oswald',
                    fontSize: 24.0,
                  ),
                ),
                Expanded(child: Container()),
                Visibility(
                  visible: fromNullableBool(item.private),
                  child: Icon(
                    MdiIcons.security,
                    color: AppColors.error,
                    size: iconSize,
                  ),
                ),
                Visibility(
                  visible: fromNullableBool(item.favorite),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Icon(
                      MdiIcons.star,
                      color: AppColors.starredGold,
                      size: iconSize,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              item.description,
              style: TextStyle(
                color: AppColors.entryTextColor,
                fontFamily: 'Oswald',
                fontWeight: FontWeight.w200,
                fontSize: 16.0,
              ),
            ),
            enabled: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (BuildContext context) {
                    return DetailRoute(
                      item: item,
                      index: index,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class DetailRoute extends StatefulWidget {
  const DetailRoute({
    Key? key,
    required this.item,
    required this.index,
  }) : super(key: key);

  final int index;
  final EntityDefinition item;

  @override
  _DetailRouteState createState() {
    return _DetailRouteState();
  }
}

class _DetailRouteState extends State<DetailRoute> {
  final JournalDb _db = getIt<JournalDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();
  late final Stream<List<MeasurableDataType>> stream =
      _db.watchMeasurableDataTypes();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MeasurableDataType>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<MeasurableDataType>> snapshot,
      ) {
        List<MeasurableDataType> items = snapshot.data ?? [];
        if (widget.item is MeasurableGoal) {
          final MeasurableGoal item = widget.item as MeasurableGoal;

          MeasurableDataType selected = items.where((element) {
            return element.id == item.successCriteria.first.measurableTypeId;
          }).first;

          debugPrint('$selected');

          return Scaffold(
            backgroundColor: AppColors.bodyBgColor,
            appBar: AppBar(
              foregroundColor: AppColors.appBarFgColor,
              title: Text(
                item.name,
                style: TextStyle(
                  color: AppColors.entryTextColor,
                  fontFamily: 'Oswald',
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () async {
                    _formKey.currentState!.save();
                    if (_formKey.currentState!.validate()) {
                      final formData = _formKey.currentState?.value;
                      debugPrint('$formData');
                      MeasurableGoal dataType = item.copyWith(
                        name: '${formData!['name']}'
                            .trim()
                            .replaceAll(' ', '_')
                            .toLowerCase(),
                        description: '${formData['description']}'.trim(),
                        successCriteria: [
                          GoalCriterion(
                            measurableTypeId:
                                (formData['type'] as MeasurableDataType).id,
                            min: nf.parse(
                              '${formData['min']}'.replaceAll(',', '.'),
                            ),
                            max: nf.parse(
                              '${formData['max']}'.replaceAll(',', '.'),
                            ),
                            validFrom: formData['validFrom'],
                            validTo: formData['validTo'],
                          ),
                        ],
                        private: formData['private'],
                        favorite: formData['favorite'],
                      );

                      persistenceLogic.upsertEntityDefinition(dataType);
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
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            child: Column(
                              children: <Widget>[
                                FormTextField(
                                  initialValue: item.name,
                                  labelText: 'Name',
                                  name: 'name',
                                ),
                                FormTextField(
                                  initialValue: item.description,
                                  labelText: 'Description',
                                  name: 'description',
                                ),
                                FormBuilderDropdown(
                                  dropdownColor: AppColors.headerBgColor,
                                  name: 'type',
                                  decoration: InputDecoration(
                                    labelText: 'Type',
                                    labelStyle: labelStyle,
                                  ),
                                  hint: Text(
                                    'Select Measurement Type',
                                    style: inputStyle,
                                  ),
                                  onChanged: (Object? value) {},
                                  validator: FormBuilderValidators.compose([
                                    FormBuilderValidators.required(context),
                                  ]),
                                  items: items
                                      .map((MeasurableDataType item) =>
                                          DropdownMenuItem(
                                            value: item,
                                            child: Text(
                                              item.displayName,
                                              style: inputStyle,
                                            ),
                                          ))
                                      .toList(),
                                ),
                                FormBuilderTextField(
                                  initialValue:
                                      '${item.successCriteria.first.min ?? ''}',
                                  decoration: InputDecoration(
                                    labelText: 'Minimum',
                                    labelStyle: labelStyle,
                                  ),
                                  style: inputStyle,
                                  name: 'min',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                ),
                                FormBuilderTextField(
                                  initialValue:
                                      '${item.successCriteria.first.max ?? ''}',
                                  decoration: InputDecoration(
                                    labelText: 'Maximum',
                                    labelStyle: labelStyle,
                                  ),
                                  style: inputStyle,
                                  name: 'max',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                ),
                                FormBuilderCupertinoDateTimePicker(
                                  name: 'validFrom',
                                  alwaysUse24HourFormat: true,
                                  format: DateFormat('EEEE, MMMM d, yyyy'),
                                  inputType:
                                      CupertinoDateTimePickerInputType.date,
                                  style: inputStyle,
                                  decoration: InputDecoration(
                                    labelText: 'Valid from',
                                    labelStyle: labelStyle,
                                  ),
                                  initialValue:
                                      item.successCriteria.first.validFrom,
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
                                FormBuilderCupertinoDateTimePicker(
                                  name: 'validTo',
                                  alwaysUse24HourFormat: true,
                                  format: DateFormat('EEEE, MMMM d, yyyy'),
                                  inputType:
                                      CupertinoDateTimePickerInputType.date,
                                  style: inputStyle,
                                  decoration: InputDecoration(
                                    labelText: 'Valid to',
                                    labelStyle: labelStyle,
                                  ),
                                  initialValue:
                                      item.successCriteria.first.validTo,
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
                              ],
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
                                  onPressed: () {
                                    persistenceLogic.upsertEntityDefinition(
                                      item.copyWith(
                                        deletedAt: DateTime.now(),
                                      ),
                                    );
                                    Navigator.pop(context);
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
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }
}
