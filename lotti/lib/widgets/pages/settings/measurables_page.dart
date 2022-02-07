import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/persistence_logic.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/misc/app_bar_version.dart';
import 'package:lotti/widgets/pages/settings/form_text_field.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

const double iconSize = 24.0;

class MeasurablesPage extends StatefulWidget {
  const MeasurablesPage({Key? key}) : super(key: key);

  @override
  State<MeasurablesPage> createState() => _MeasurablesPageState();
}

class _MeasurablesPageState extends State<MeasurablesPage> {
  final JournalDb _db = getIt<JournalDb>();

  late final Stream<List<MeasurableDataType>> stream =
      _db.watchMeasurableDataTypes();

  @override
  void initState() {
    super.initState();
    createDefaults();
  }

  void createDefaults() async {
    DateTime now = DateTime.now();

    _db.upsertMeasurableDataType(MeasurableDataType(
      id: '9e9e7a62-1e56-4059-a568-12234db7399b',
      createdAt: now,
      updatedAt: now,
      name: 'water',
      displayName: 'Water',
      description: 'Volume of water consumed, in milliliters',
      unitName: 'ml',
      version: 0,
      vectorClock: null,
    ));

    _db.upsertMeasurableDataType(MeasurableDataType(
      id: 'f2518f33-af1d-4dbe-ae9b-6a05def5d8f9',
      createdAt: now,
      updatedAt: now,
      name: 'caffeine',
      displayName: 'Caffeine',
      description: 'Amount of caffeine consumed, in milligrams',
      unitName: 'mg',
      version: 0,
      vectorClock: null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MeasurableDataType>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<MeasurableDataType>> snapshot,
      ) {
        List<MeasurableDataType> items = snapshot.data ?? [];

        return Scaffold(
          appBar: const VersionAppBar(title: 'Measurables'),
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
                return MeasurableTypeCard(
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

class MeasurableTypeCard extends StatelessWidget {
  final MeasurableDataType item;
  final int index;

  const MeasurableTypeCard({
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
                  item.displayName,
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
  final MeasurableDataType item;

  @override
  _DetailRouteState createState() {
    return _DetailRouteState();
  }
}

class _DetailRouteState extends State<DetailRoute> {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    final MeasurableDataType item = widget.item;

    return Scaffold(
      backgroundColor: AppColors.bodyBgColor,
      appBar: AppBar(
        foregroundColor: AppColors.appBarFgColor,
        title: Text(
          item.displayName,
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
                MeasurableDataType dataType = item.copyWith(
                  name: '${formData!['name']}'
                      .trim()
                      .replaceAll(' ', '_')
                      .toLowerCase(),
                  description: '${formData['description']}'.trim(),
                  unitName: '${formData['unitName']}'.trim(),
                  displayName: '${formData['displayName']}'.trim(),
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
  }
}
