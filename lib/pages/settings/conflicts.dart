import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/journal/entry_details_page.dart';
import 'package:lotti/sync/vector_clock.dart';
import 'package:lotti/theme/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class ConflictsPage extends StatefulWidget {
  const ConflictsPage({super.key});

  @override
  State<ConflictsPage> createState() => _ConflictsPageState();
}

class _ConflictsPageState extends State<ConflictsPage> {
  final JournalDb _db = getIt<JournalDb>();

  late Stream<List<Conflict>> stream =
      _db.watchConflicts(ConflictStatus.unresolved);

  String _selectedValue = 'unresolved';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<Conflict>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<Conflict>> snapshot,
      ) {
        final items = snapshot.data ?? [];

        return Scaffold(
          backgroundColor: getIt<ThemeService>().colors.bodyBgColor,
          appBar: TitleAppBar(title: localizations.settingsConflictsTitle),
          body: SingleChildScrollView(
            child: Column(
              children: [
                CupertinoSegmentedControl(
                  selectedColor: getIt<ThemeService>().colors.entryBgColor,
                  unselectedColor: getIt<ThemeService>().colors.headerBgColor,
                  borderColor: getIt<ThemeService>().colors.entryBgColor,
                  groupValue: _selectedValue,
                  onValueChanged: (String value) {
                    setState(() {
                      _selectedValue = value;
                      if (_selectedValue == 'unresolved') {
                        stream = _db.watchConflicts(ConflictStatus.unresolved);
                      }
                      if (_selectedValue == 'resolved') {
                        stream = _db.watchConflicts(ConflictStatus.resolved);
                      }
                    });
                  },
                  children: {
                    'unresolved': SizedBox(
                      width: 64,
                      height: 32,
                      child: Center(
                        child: Text(
                          localizations.conflictsUnresolved,
                          style: segmentItemStyle,
                        ),
                      ),
                    ),
                    'resolved': SizedBox(
                      child: Center(
                        child: Text(
                          localizations.conflictsResolved,
                          style: segmentItemStyle,
                        ),
                      ),
                    ),
                  },
                ),
                ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  children: List.generate(
                    items.length,
                    (int index) {
                      return ConflictCard(
                        conflict: items.elementAt(index),
                        index: index,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String statusString(Conflict conflict) {
  return EnumToString.convertToString(ConflictStatus.values[conflict.status]);
}

class ConflictCard extends StatelessWidget {
  ConflictCard({
    super.key,
    required this.conflict,
    required this.index,
  });

  final JournalDb _db = getIt<JournalDb>();
  final Conflict conflict;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 24, right: 24),
          title: Text(
            '${df.format(conflict.createdAt)} - ${statusString(conflict)}',
            style: TextStyle(
              color: getIt<ThemeService>().colors.entryTextColor,
              fontFamily: 'Oswald',
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            '${fromSerialized(conflict.serialized).meta.vectorClock}',
            style: TextStyle(
              color: getIt<ThemeService>().colors.entryTextColor,
              fontFamily: 'Oswald',
              fontWeight: FontWeight.w200,
              fontSize: 16,
            ),
          ),
          onTap: () async {
            final navigator = Navigator.of(context);
            final entity = await _db.journalEntityById(conflict.id);
            if (entity == null) return;

            await navigator.push(
              MaterialPageRoute<DetailRoute>(
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
    super.key,
    required this.local,
    required this.index,
    required this.conflict,
  });

  final int index;
  final JournalEntity local;
  final Conflict conflict;

  @override
  Widget build(BuildContext context) {
    final fromSync = fromSerialized(conflict.serialized);
    final merged =
        VectorClock.merge(local.meta.vectorClock, fromSync.meta.vectorClock);
    final withResolvedVectorClock =
        local.copyWith(meta: local.meta.copyWith(vectorClock: merged));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          df.format(local.meta.dateFrom),
          style: TextStyle(
            color: getIt<ThemeService>().colors.entryBgColor,
            fontFamily: 'Oswald',
          ),
        ),
        backgroundColor: getIt<ThemeService>().colors.headerBgColor,
      ),
      backgroundColor: getIt<ThemeService>().colors.bodyBgColor,
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              Text(
                'Local: ${local.meta.vectorClock}',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'ShareTechMono',
                ),
              ),
              Text(
                'Merged: ${withResolvedVectorClock.meta.vectorClock}',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'ShareTechMono',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  child: EntryDetailPage(
                    itemId: withResolvedVectorClock.meta.id,
                  ),
                ),
              ),
              Text(
                'From Sync: ${fromSync.meta.vectorClock}',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'ShareTechMono',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  child: EntryDetailPage(
                    itemId: fromSync.meta.id,
                    readOnly: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
