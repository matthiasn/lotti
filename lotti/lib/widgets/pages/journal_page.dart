import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/journal/persistence_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/journal_card.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({
    Key? key,
    this.navigatorKey,
  });

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
  static final List<FilterBy> _entryTypes = [
    FilterBy(typeName: r'_$JournalEntry', name: "Text"),
    FilterBy(typeName: r'_$JournalAudio', name: "Audio"),
    FilterBy(typeName: r'_$JournalImage', name: "Photo"),
    FilterBy(typeName: r'_$QuantitativeEntry', name: "Quantitative"),
  ];
  final _items = _entryTypes
      .map((entryType) => MultiSelectItem<FilterBy?>(entryType, entryType.name))
      .toList();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: widget.navigatorKey,
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (BuildContext context) {
            return BlocBuilder<PersistenceCubit, PersistenceState>(
              builder: (BuildContext context, PersistenceState state) {
                return Scaffold(
                  appBar: AppBar(
                    backgroundColor: AppColors.headerBgColor,
                    title: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: MultiSelectDialogField(
                        items: _items,
                        title: const Text("Entry Types"),
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
                          "Filter by Type",
                          style: TextStyle(
                            color: AppColors.entryBgColor,
                            fontSize: 16,
                          ),
                        ),
                        onConfirm: (List<FilterBy?> results) {
                          context.read<PersistenceCubit>().queryFilteredJournal(
                              results
                                  .map((FilterBy? e) => e!.typeName)
                                  .toList());
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
                    child: state.when(
                      initial: () => const Text('initial'),
                      loading: () => const Text('loading'),
                      failed: () => const Text('failed'),
                      online: (List<JournalEntity> entries) {
                        debugPrint('entries.length ${entries.length}');
                        return ListView(
                          children: List.generate(
                            entries.length,
                            (int index) {
                              return JournalCard(
                                item: entries.elementAt(index),
                                index: index,
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
