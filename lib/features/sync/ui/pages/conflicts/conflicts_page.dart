import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_journal_card.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/conflict_list_item.dart';
import 'package:lotti/features/sync/ui/widgets/sync_list_scaffold.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

enum _ConflictListFilter {
  unresolved,
  resolved,
}

class ConflictsPage extends StatefulWidget {
  const ConflictsPage({super.key});

  @override
  State<ConflictsPage> createState() => _ConflictsPageState();
}

class _ConflictsPageState extends State<ConflictsPage> {
  final JournalDb _db = getIt<JournalDb>();

  late final Stream<List<Conflict>> _stream = _watchAllConflicts();

  Stream<List<Conflict>> _watchAllConflicts() {
    final controller = StreamController<List<Conflict>>();
    List<Conflict>? unresolved;
    List<Conflict>? resolved;

    StreamSubscription<List<Conflict>>? unresolvedSubscription;
    StreamSubscription<List<Conflict>>? resolvedSubscription;

    void emitIfReady() {
      if (unresolved == null || resolved == null) {
        return;
      }
      final combined = <Conflict>[
        ...unresolved!,
        ...resolved!,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(combined);
    }

    controller
      ..onListen = () {
        unresolvedSubscription =
            _db.watchConflicts(ConflictStatus.unresolved).listen((value) {
          unresolved = value;
          emitIfReady();
        });

        resolvedSubscription =
            _db.watchConflicts(ConflictStatus.resolved).listen((value) {
          resolved = value;
          emitIfReady();
        });
      }
      ..onPause = () {
        unresolvedSubscription?.pause();
        resolvedSubscription?.pause();
      }
      ..onResume = () {
        unresolvedSubscription?.resume();
        resolvedSubscription?.resume();
      }
      ..onCancel = () async {
        await unresolvedSubscription?.cancel();
        await resolvedSubscription?.cancel();
        unresolved = null;
        resolved = null;
      };

    return controller.stream;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filters = <_ConflictListFilter, SyncFilterOption<Conflict>>{
      _ConflictListFilter.unresolved: SyncFilterOption<Conflict>(
        labelBuilder: (ctx) => ctx.messages.conflictsUnresolved,
        predicate: (conflict) =>
            ConflictStatus.values[conflict.status] == ConflictStatus.unresolved,
        icon: Icons.report_problem_outlined,
        selectedColor: Colors.amber,
        selectedForegroundColor: Colors.black,
      ),
      _ConflictListFilter.resolved: SyncFilterOption<Conflict>(
        labelBuilder: (ctx) => ctx.messages.conflictsResolved,
        predicate: (conflict) =>
            ConflictStatus.values[conflict.status] == ConflictStatus.resolved,
        icon: Icons.verified_outlined,
        selectedColor: colorScheme.primary,
        selectedForegroundColor: colorScheme.onPrimary,
      ),
    };

    return SyncListScaffold<Conflict, _ConflictListFilter>(
      title: context.messages.settingsConflictsTitle,
      stream: _stream,
      filters: filters,
      initialFilter: _ConflictListFilter.unresolved,
      emptyIcon: Icons.verified_user_outlined,
      emptyTitleBuilder: (ctx) => ctx.messages.conflictsEmptyTitle,
      emptyDescriptionBuilder: (ctx) => ctx.messages.conflictsEmptyDescription,
      countSummaryBuilder: (ctx, label, count) =>
          ctx.messages.syncListCountSummary(label, count),
      itemBuilder: (ctx, conflict) => ConflictListItem(
        conflict: conflict,
        onTap: () => beamToNamed('/settings/advanced/conflicts/${conflict.id}'),
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
                      style: monoTabularStyle(fontSize: fontSizeSmall),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Resolved with local: ${localWithResolvedVectorClock.meta.vectorClock}',
                      style: monoTabularStyle(fontSize: fontSizeSmall),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'From Sync: ${fromSync.meta.vectorClock}',
                      style: monoTabularStyle(fontSize: fontSizeSmall),
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
