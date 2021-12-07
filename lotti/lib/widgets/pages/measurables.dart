import 'package:flutter/material.dart';
import 'package:lotti/classes/measurables.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:units_converter/units_converter.dart';

class MeasurablesPage extends StatefulWidget {
  const MeasurablesPage({Key? key}) : super(key: key);

  @override
  State<MeasurablesPage> createState() => _MeasurablesPageState();
}

class _MeasurablesPageState extends State<MeasurablesPage> {
  final JournalDb _db = getIt<JournalDb>();

  late final Stream<List<MeasurableDataType>> stream;

  @override
  void initState() {
    super.initState();

    var length = Length()..convert(LENGTH.meters, 1);
    Unit unit = length.inches;
    print(
        'name:${unit.name}, value:${unit.value}, stringValue:${unit.stringValue}, symbol:${unit.symbol}');

    stream = _db.watchMeasurableDataTypes();

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
      uniqueName: 'water',
      displayName: 'Water',
      unitName: 'ml',
      version: 0,
    ));

    _db.addMeasurable(MeasurableDataType(
      id: 'f2518f33-af1d-4dbe-ae9b-6a05def5d8f9',
      createdAt: now,
      updatedAt: now,
      uniqueName: 'caffeine',
      displayName: 'Caffeine',
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
          title: Text(
            item.displayName,
            style: TextStyle(
              color: AppColors.entryBgColor,
              fontFamily: 'Oswald',
              fontSize: 20.0,
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

class DetailRoute extends StatelessWidget {
  const DetailRoute({
    Key? key,
    required this.item,
    required this.index,
  }) : super(key: key);

  final int index;
  final MeasurableDataType item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          item.displayName,
          style: TextStyle(
            color: AppColors.entryBgColor,
            fontFamily: 'Oswald',
          ),
        ),
        backgroundColor: AppColors.headerBgColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(item.toString()),
      ),
    );
  }
}
