import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_detail_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class ConflictsPage extends StatefulWidget {
  const ConflictsPage({Key? key}) : super(key: key);

  @override
  State<ConflictsPage> createState() => _ConflictsPageState();
}

class _ConflictsPageState extends State<ConflictsPage> {
  final JournalDb _db = getIt<JournalDb>();

  late Stream<List<Conflict>> stream =
      _db.watchConflicts(ConflictStatus.unprocessed);

  String _selectedValue = 'unresolved';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OutboxCubit, OutboxState>(
      builder: (context, OutboxState state) {
        return StreamBuilder<List<Conflict>>(
          stream: stream,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<Conflict>> snapshot,
          ) {
            List<Conflict> items = snapshot.data ?? [];

            return Scaffold(
              appBar: AppBar(
                backgroundColor: AppColors.headerBgColor,
                foregroundColor: AppColors.appBarFgColor,
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoSegmentedControl(
                      selectedColor: AppColors.entryBgColor,
                      unselectedColor: AppColors.headerBgColor,
                      borderColor: AppColors.entryBgColor,
                      groupValue: _selectedValue,
                      onValueChanged: (String value) {
                        setState(() {
                          _selectedValue = value;
                          if (_selectedValue == 'unresolved') {
                            stream =
                                _db.watchConflicts(ConflictStatus.unprocessed);
                          }
                          if (_selectedValue == 'resolved') {
                            stream =
                                _db.watchConflicts(ConflictStatus.resolved);
                          }
                        });
                      },
                      children: const {
                        'unresolved': SizedBox(
                          width: 64,
                          height: 32,
                          child: Center(
                            child: Text(
                              'unresolved',
                              style: TextStyle(
                                fontFamily: 'Oswald',
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        'resolved': SizedBox(
                          child: Center(
                            child: Text(
                              'resolved',
                              style: TextStyle(
                                fontFamily: 'Oswald',
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      },
                    ),
                  ],
                ),
              ),
              backgroundColor: AppColors.bodyBgColor,
              body: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8.0),
                children: List.generate(
                  items.length,
                  (int index) {
                    return ConflictCard(
                      conflict: items.elementAt(index),
                      db: _db,
                      index: index,
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ConflictCard extends StatelessWidget {
  final Conflict conflict;
  final JournalDb db;
  final int index;

  const ConflictCard({
    Key? key,
    required this.conflict,
    required this.db,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Card(
        elevation: 8.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 24, right: 24),
          title: Text(
            '${df.format(conflict.createdAt)} - ${conflict.status}',
            style: TextStyle(
              color: AppColors.entryTextColor,
              fontFamily: 'Oswald',
              fontSize: 16.0,
            ),
          ),
          subtitle: Text(
            '$conflict',
            style: TextStyle(
              color: AppColors.entryTextColor,
              fontFamily: 'Oswald',
              fontWeight: FontWeight.w200,
              fontSize: 16.0,
            ),
          ),
          enabled: true,
          onTap: () async {
            JournalEntity? entity = await db.journalEntityById(conflict.id);
            if (entity == null) return;

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (BuildContext context) {
                  return DetailRoute(
                    local: entity,
                    conflict: conflict,
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
    required this.local,
    required this.index,
    required this.conflict,
  }) : super(key: key);

  final int index;
  final JournalEntity local;
  final Conflict conflict;

  @override
  Widget build(BuildContext context) {
    final JournalEntity fromSync = fromSerialized(conflict.serialized);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          df.format(local.meta.dateFrom),
          style: TextStyle(
            color: AppColors.entryBgColor,
            fontFamily: 'Oswald',
          ),
        ),
        backgroundColor: AppColors.headerBgColor,
      ),
      backgroundColor: AppColors.bodyBgColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Text(
              'Local:',
              style: TextStyle(color: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(8.0)),
                child: EntryDetailWidget(item: local),
              ),
            ),
            const Text(
              'From Sync:',
              style: TextStyle(color: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(8.0)),
                child: EntryDetailWidget(item: fromSync),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
