import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/journal/persistence_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_modal_widget2.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/journal/journal_list_item.dart';

class JournalPage2 extends StatefulWidget {
  const JournalPage2({this.navigatorKey, required this.child});

  final Widget child;
  final GlobalKey? navigatorKey;

  @override
  _JournalPage2State createState() => _JournalPage2State();
}

class _JournalPage2State extends State<JournalPage2> {
  late TextEditingController _textEditingController;

  int _currentRoute = 0;

  @override
  void initState() {
    _textEditingController = TextEditingController();
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
                    title: widget.child,
                    centerTitle: true,
                  ),
                  backgroundColor: AppColors.bodyBgColor,
                  body: Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 10.0,
                      horizontal: 20.0,
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
                              JournalEntity item = entries.elementAt(index);

                              return Card(
                                child: ListTile(
                                  leading: const FlutterLogo(),
                                  //title: Text('Item ${index + 1}'),
                                  title: JournalListItem2(item: item),
                                  enabled: true,
                                  onTap: () {
                                    _currentRoute = index;
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

class DetailRoute extends StatelessWidget {
  DetailRoute({
    Key? key,
    required this.item,
    required this.index,
  }) : super(key: key);

  final int index;
  JournalEntity item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          df.format(item.meta.dateFrom),
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.headerBgColor,
      ),
      body: EntryModalWidget2(
        item: item,
        docDir: Directory('docDir'),
      ),
    );
  }
}
