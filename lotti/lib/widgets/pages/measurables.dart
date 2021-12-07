import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/measurables.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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

    stream.listen((List<MeasurableDataType> data) {
      debugPrint('DataReceived: $data');
    }, onDone: () {
      debugPrint('Task Done');
    }, onError: (error) {
      debugPrint('Some Error');
    });

    DateTime now = DateTime.now();

    _db.addMeasurable(MeasurableDataType(
      id: '9e9e7a62-1e56-4059-a568-12234db7399b',
      createdAt: now,
      updatedAt: now,
      name: 'water',
      displayName: 'Water',
      description: 'Volume of water consumed, in milliliters',
      unitName: 'ml',
      version: 0,
    ));

    _db.addMeasurable(MeasurableDataType(
      id: 'f2518f33-af1d-4dbe-ae9b-6a05def5d8f9',
      createdAt: now,
      updatedAt: now,
      name: 'caffeine',
      displayName: 'Caffeine',
      description: 'Amount of caffeine consumed, in milligrams',
      unitName: 'mg',
      version: 0,
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
          appBar: AppBar(
            title: Text(
              'Measurables',
              style: TextStyle(
                color: AppColors.entryBgColor,
                fontFamily: 'Oswald',
              ),
            ),
            backgroundColor: AppColors.headerBgColor,
          ),
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
                      ),
                      index: -1,
                    );
                  },
                ),
              );
            },
          ),
          body: SingleChildScrollView(
              child: ListView(
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
          )),
        );
      },
    );
  }
}

class MeasurableTypeCard extends StatelessWidget {
  final MeasurableDataType item;
  final int index;
  final _formKey = GlobalKey<FormBuilderState>();

  MeasurableTypeCard({
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
        child: ListTile(
          contentPadding:
              const EdgeInsets.only(left: 24, top: 4, bottom: 12, right: 24),
          title: Text(
            item.name,
            style: TextStyle(
              color: AppColors.entryBgColor,
              fontFamily: 'Oswald',
              fontSize: 24.0,
            ),
          ),
          subtitle: Text(
            item.description,
            style: TextStyle(
              color: AppColors.entryBgColor,
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
  final _formKey = GlobalKey<FormBuilderState>();
  final JournalDb _db = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    final MeasurableDataType item = widget.item;

    return Scaffold(
      backgroundColor: AppColors.entryBgColor,
      appBar: AppBar(
        title: Text(
          item.displayName,
          style: TextStyle(
            color: AppColors.entryBgColor,
            fontFamily: 'Oswald',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              _formKey.currentState!.save();
              if (_formKey.currentState!.validate()) {
                final formData = _formKey.currentState?.value;
                MeasurableDataType dataType = item.copyWith(
                  name: formData!['name'],
                  description: formData['description'],
                  unitName: formData['unitName'],
                  displayName: formData['displayName'],
                );
                _db.addMeasurable(dataType);
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text('Save'),
            ),
          ),
        ],
        backgroundColor: AppColors.headerBgColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            FormBuilder(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: <Widget>[
                  FormBuilderTextField(
                    name: 'name',
                    initialValue: item.name,
                    validator: FormBuilderValidators.required(context),
                    decoration: const InputDecoration(
                      labelText: 'Name',
                    ),
                  ),
                  FormBuilderTextField(
                    name: 'displayName',
                    initialValue: item.displayName,
                    validator: FormBuilderValidators.required(context),
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                  ),
                  FormBuilderTextField(
                    name: 'description',
                    initialValue: item.description,
                    validator: FormBuilderValidators.required(context),
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  ),
                  FormBuilderTextField(
                    name: 'unitName',
                    initialValue: item.unitName,
                    validator: FormBuilderValidators.required(context),
                    decoration: const InputDecoration(
                      labelText: 'Unit Abbreviation',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 80.0),
              child: Text(item.toString()),
            ),
          ],
        ),
      ),
    );
  }
}
