import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/journal_card.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({
    Key? key,
    this.navigatorKey,
  }) : super(key: key);

  final GlobalKey? navigatorKey;

  @override
  _JournalPageState createState() => _JournalPageState();
}

class FilterBy {
  final String typeName;
  final String name;

  FilterBy({
    required this.typeName,
    required this.name,
  });
}

class _JournalPageState extends State<JournalPage> {
  final JournalDb _db = getIt<JournalDb>();

  static final List<FilterBy> _entryTypes = [
    FilterBy(typeName: 'JournalEntry', name: 'Text'),
    FilterBy(typeName: 'JournalAudio', name: 'Audio'),
    FilterBy(typeName: 'JournalImage', name: 'Photo'),
    FilterBy(typeName: 'QuantitativeEntry', name: 'Quantitative'),
    FilterBy(typeName: 'MeasurementEntry', name: 'Measurement'),
    FilterBy(typeName: 'SurveyEntry', name: 'Questionnaire'),
  ];

  late Stream<List<JournalEntity>> stream;

  final List<MultiSelectItem<FilterBy?>> _items = _entryTypes
      .map((entryType) => MultiSelectItem<FilterBy?>(entryType, entryType.name))
      .toList();

  final List<String> _allTypes = _entryTypes.map((e) => e.typeName).toList();

  @override
  void initState() {
    super.initState();
    stream = _db.watchJournalEntities(types: _allTypes);
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: widget.navigatorKey,
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (BuildContext context) {
            return StreamBuilder<List<JournalEntity>>(
              stream: stream,
              builder: (
                BuildContext context,
                AsyncSnapshot<List<JournalEntity>> snapshot,
              ) {
                if (snapshot.data == null) {
                  return Container();
                } else {
                  List<JournalEntity> items = snapshot.data!;

                  return Scaffold(
                    appBar: AppBar(
                      backgroundColor: AppColors.headerBgColor,
                      title: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: MultiSelectDialogField(
                          items: _items,
                          title: const Text('Entry Types'),
                          selectedColor: Colors.blue,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius:
                                const BorderRadius.all(Radius.circular(40)),
                            border: Border.all(
                              color: AppColors.entryBgColor,
                              width: 2,
                            ),
                          ),
                          buttonIcon: Icon(
                            Icons.search,
                            color: AppColors.entryBgColor,
                          ),
                          buttonText: Text(
                            'Filter by Type',
                            style: TextStyle(
                              color: AppColors.entryBgColor,
                              fontSize: 16,
                            ),
                          ),
                          onConfirm: (List<FilterBy?> results) {
                            final List<String> types = results.isNotEmpty
                                ? results.map((e) => e?.typeName ?? '').toList()
                                : _allTypes;

                            setState(() {
                              stream = _db.watchJournalEntities(types: types);
                            });
                          },
                        ),
                      ),
                      centerTitle: true,
                    ),
                    backgroundColor: AppColors.bodyBgColor,
                    body: Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 8.0,
                      ),
                      child: ListView(
                        children: List.generate(
                          items.length,
                          (int index) {
                            return JournalCard(
                              item: items.elementAt(index),
                              index: index,
                            );
                          },
                          growable: true,
                        ),
                      ),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}
