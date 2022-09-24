import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/pages/settings/settings_card.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/sync/vector_clock.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/journal/journal_card.dart';

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
          backgroundColor: colorConfig().negspace,
          appBar: TitleAppBar(
            title: localizations.settingsConflictsTitle,
            actions: [
              CupertinoSegmentedControl(
                selectedColor: colorConfig().riptide,
                unselectedColor: colorConfig().ice,
                borderColor: colorConfig().riptide,
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
                  'unresolved': Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      localizations.conflictsUnresolved,
                      style: segmentItemStyle,
                    ),
                  ),
                  'resolved': Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      localizations.conflictsResolved,
                      style: segmentItemStyle,
                    ),
                  ),
                },
              ),
            ],
          ),
          body: ListView(
            shrinkWrap: true,
            children: intersperse(
              const SettingsDivider(),
              List.generate(
                items.length,
                (int index) {
                  return ConflictCard(
                    conflict: items.elementAt(index),
                    index: index,
                  );
                },
              ),
            ).toList(),
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
  const ConflictCard({
    super.key,
    required this.conflict,
    required this.index,
  });

  final Conflict conflict;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: ListTile(
        hoverColor: colorConfig().riplight,
        contentPadding: const EdgeInsets.only(left: 24, right: 24),
        title: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '${df.format(conflict.createdAt)} - ${statusString(conflict)}',
          ),
        ),
        subtitle: Text(
          '${fromSerialized(conflict.serialized).meta.vectorClock}',
          style: monospaceTextStyleSmall(),
        ),
        onTap: () {
          beamToNamed('/settings/advanced/conflicts/${conflict.id}');
        },
      ),
    );
  }
}

class ConflictDetailRoute extends StatelessWidget {
  const ConflictDetailRoute({
    super.key,
    required this.conflictId,
  });

  final String conflictId;

  @override
  Widget build(BuildContext context) {
    final db = getIt<JournalDb>();
    final localizations = AppLocalizations.of(context)!;

    final stream = db.watchConflictById(conflictId);

    return StreamBuilder<List<Conflict>>(
      stream: stream,
      builder: (context, snapshot) {
        final data = snapshot.data ?? [];

        if (data.isEmpty) {
          return const EmptyScaffoldWithTitle('Conflict not found');
        }

        final conflict = data.first;
        final fromSync = fromSerialized(conflict.serialized);

        return StreamBuilder<JournalEntity?>(
          stream: db.watchEntityById(conflict.id),
          builder: (
            BuildContext context,
            AsyncSnapshot<JournalEntity?> snapshot,
          ) {
            final local = snapshot.data;

            if (local == null) {
              return const EmptyScaffoldWithTitle('Entry not found');
            }

            final merged = VectorClock.merge(
              local.meta.vectorClock,
              fromSync.meta.vectorClock,
            );

            final withResolvedVectorClock = local.copyWith(
              meta: local.meta.copyWith(vectorClock: merged),
            );

            return Scaffold(
              appBar: TitleAppBar(
                title: localizations.settingsConflictsResolutionTitle,
              ),
              backgroundColor: colorConfig().negspace,
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Local:', style: appBarTextStyleNew()),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: IgnorePointer(
                        child: JournalCard(
                          item: withResolvedVectorClock,
                          maxHeight: 1000,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton(
                          onPressed: () {
                            beamToNamed(
                              '/settings/advanced/conflicts/${conflict.id}/edit',
                            );
                          },
                          child: const Text('Edit'),
                        ),
                        TextButton(
                          clipBehavior: Clip.antiAlias,
                          onPressed: () {
                            getIt<PersistenceLogic>().updateJournalEntity(
                              withResolvedVectorClock,
                              withResolvedVectorClock.meta,
                            );
                            settingsBeamerDelegate.beamBack();
                          },
                          child: const Text(
                            'Resolve with local version',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Text('From Sync:', style: appBarTextStyleNew()),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: IgnorePointer(
                        child: JournalCard(
                          item: fromSync,
                          maxHeight: 1000,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: fromSync.entryText?.plainText,
                              ),
                            );
                          },
                          child: const Text('Copy Text from Sync'),
                        ),
                      ],
                    ),
                    const Divider(),
                    Text(
                      'Local: ${local.meta.vectorClock}',
                      style: monospaceTextStyleSmall(),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Merged: ${withResolvedVectorClock.meta.vectorClock}',
                      style: monospaceTextStyleSmall(),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'From Sync: ${fromSync.meta.vectorClock}',
                      style: monospaceTextStyleSmall(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
