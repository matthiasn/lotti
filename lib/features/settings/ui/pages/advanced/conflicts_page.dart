import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_journal_card.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

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
    return StreamBuilder<List<Conflict>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<Conflict>> snapshot,
      ) {
        final items = snapshot.data ?? [];

        return Scaffold(
          appBar: TitleAppBar(
            title: context.messages.settingsConflictsTitle,
            actions: [
              CupertinoSegmentedControl(
                selectedColor: Theme.of(context).primaryColor,
                borderColor: Theme.of(context).primaryColor,
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
                      context.messages.conflictsUnresolved,
                      style: segmentItemStyle,
                    ),
                  ),
                  'resolved': Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      context.messages.conflictsResolved,
                      style: segmentItemStyle,
                    ),
                  ),
                },
              ),
            ],
          ),
          body: ListView(
            shrinkWrap: true,
            children: List.generate(
              items.length,
              (int index) => ConflictCard(conflict: items.elementAt(index)),
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
  const ConflictCard({
    required this.conflict,
    super.key,
  });

  final Conflict conflict;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 24, right: 24),
        title: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '${df.format(conflict.createdAt)} - ${statusString(conflict)}',
          ),
        ),
        subtitle: Text(
          '${fromSerialized(conflict.serialized).meta.vectorClock}',
          style: monospaceTextStyleSmall,
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
    required this.conflictId,
    super.key,
  });

  final String conflictId;

  @override
  Widget build(BuildContext context) {
    final db = getIt<JournalDb>();

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

        return FutureBuilder<JournalEntity?>(
          future: db.journalEntityById(conflict.id),
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

            final localWithResolvedVectorClock = local.copyWith(
              meta: local.meta.copyWith(vectorClock: merged),
            );

            final remoteWithResolvedVectorClock = fromSync.copyWith(
              meta: local.meta.copyWith(vectorClock: merged),
            );

            return Scaffold(
              appBar: TitleAppBar(
                title: context.messages.settingsConflictsResolutionTitle,
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Local:', style: appBarTextStyleNew),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: IgnorePointer(
                        child: ModernJournalCard(
                          item: localWithResolvedVectorClock,
                          maxHeight: 1000,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        LottiTertiaryButton(
                          onPressed: () => beamToNamed(
                            '/settings/advanced/conflicts/${conflict.id}/edit',
                          ),
                          label: context.messages.editMenuTitle,
                        ),
                        LottiTertiaryButton(
                          onPressed: () {
                            getIt<PersistenceLogic>().updateJournalEntity(
                              localWithResolvedVectorClock,
                              localWithResolvedVectorClock.meta,
                            );
                            settingsBeamerDelegate.beamBack();
                          },
                          label: context.messages.conflictsResolveLocalVersion,
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text('From Sync:', style: appBarTextStyleNew),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: IgnorePointer(
                        child: ModernJournalCard(
                          item: remoteWithResolvedVectorClock,
                          maxHeight: 1000,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        LottiTertiaryButton(
                          onPressed: () {
                            getIt<PersistenceLogic>().updateJournalEntity(
                              remoteWithResolvedVectorClock,
                              remoteWithResolvedVectorClock.meta,
                            );
                            settingsBeamerDelegate.beamBack();
                          },
                          label: context.messages.conflictsResolveRemoteVersion,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        LottiTertiaryButton(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: fromSync.entryText?.plainText ?? '',
                              ),
                            );
                          },
                          label: context.messages.conflictsCopyTextFromSync,
                        ),
                      ],
                    ),
                    const Divider(),
                    Text(
                      'Local: ${local.meta.vectorClock}',
                      style: monospaceTextStyleSmall,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Resolved with local: ${localWithResolvedVectorClock.meta.vectorClock}',
                      style: monospaceTextStyleSmall,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'From Sync: ${fromSync.meta.vectorClock}',
                      style: monospaceTextStyleSmall,
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
