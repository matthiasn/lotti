import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/journal/persistence_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/journal/journal_list_item.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({Key? key}) : super(key: key);

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PersistenceCubit, PersistenceState>(
        builder: (context, PersistenceState state) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              state.when(
                initial: () => const Text('initial'),
                loading: () => const Text('loading'),
                failed: () => const Text('failed'),
                online: (List<JournalEntity> entries) {
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: entries.length,
                    itemBuilder: (BuildContext context, int index) {
                      JournalEntity item = entries.elementAt(index);
                      return Dismissible(
                        key: Key(index.toString()),
                        background: Container(color: Colors.red),
                        child: JournalListItem(item: item),
                        onDismissed: (DismissDirection direction) {
                          debugPrint('Dismiss: ${item.meta.id}');
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      );
    });
  }
}
