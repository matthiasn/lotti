import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/measurables/measurable_type_card.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/theme.dart';
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

        return Stack(
          children: [
            ListView(
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
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FloatingActionButton(
                  child: const Icon(MdiIcons.plus, size: 32),
                  backgroundColor: AppColors.entryBgColor,
                  onPressed: () {
                    context.router.push(const CreateMeasurableRoute());
                  },
                ),
              ),
            )
          ],
        );
      },
    );
  }
}
