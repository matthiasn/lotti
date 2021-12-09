import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/journal/persistence_state.dart';
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
    createDefaults();
  }

  void createDefaults() async {
    DateTime now = DateTime.now();

    _db.upsertEntityDefinition(MeasurableDataType(
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

    _db.upsertEntityDefinition(MeasurableDataType(
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
          appBar: AppBar(
            title: Text(
              'Measurables',
              style: TextStyle(
                color: AppColors.entryTextColor,
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
                        vectorClock: null,
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
        child: ListTile(
          contentPadding:
              const EdgeInsets.only(left: 24, top: 4, bottom: 12, right: 24),
          title: Text(
            item.name,
            style: TextStyle(
              color: AppColors.entryTextColor,
              fontFamily: 'Oswald',
              fontSize: 24.0,
            ),
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
    return BlocBuilder<PersistenceCubit, PersistenceState>(
        builder: (BuildContext context, PersistenceState state) {
      final MeasurableDataType item = widget.item;

      return Scaffold(
        backgroundColor: AppColors.bodyBgColor,
        appBar: AppBar(
          title: Text(
            item.displayName,
            style: TextStyle(
              color: AppColors.entryTextColor,
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

                  context
                      .read<PersistenceCubit>()
                      .upsertEntityDefinition(dataType);
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
                  child: FormBuilder(
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
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class FormTextField extends StatelessWidget {
  const FormTextField({
    Key? key,
    required this.initialValue,
    required this.name,
    required this.labelText,
  }) : super(key: key);

  final String initialValue;
  final String name;
  final String labelText;

  @override
  Widget build(BuildContext context) {
    return FormBuilderTextField(
      name: name,
      minLines: 1,
      maxLines: 3,
      initialValue: initialValue,
      validator: FormBuilderValidators.required(context),
      style: TextStyle(
        color: AppColors.entryTextColor,
        height: 1.6,
        fontFamily: 'Lato',
        fontSize: 20,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: AppColors.entryTextColor, fontSize: 16),
      ),
    );
  }
}
