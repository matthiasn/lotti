import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/conflict_resolution_service.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/conflict_resolution_view.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_field_diff.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/layout/empty_scaffold.dart';
import 'package:material_ui/material_ui.dart';

/// Conflict resolution page. Loads the local + remote versions of the
/// conflicted entry, renders a full field-level diff, and lets the user keep
/// either side or combine them — applied through [ConflictResolutionService].
///
/// An entry can hold several concurrent versions at once, one conflict row
/// each (ADR 0092). The page shows the one [versionKey] names; without it, or
/// once that one is resolved, the oldest still unresolved. Resolving one
/// writes the merge of that pair, and the next is decided against it.
class ConflictDetailRoute extends ConsumerStatefulWidget {
  const ConflictDetailRoute({
    required this.conflictId,
    this.versionKey,
    super.key,
  });

  /// The conflicted entry's id.
  final String conflictId;

  /// The conflict row's `version_key`, when a list row named one.
  final String? versionKey;

  @override
  ConsumerState<ConflictDetailRoute> createState() =>
      _ConflictDetailRouteState();
}

class _ConflictDetailRouteState extends ConsumerState<ConflictDetailRoute> {
  late final JournalDb _db = ref.read(journalDbProvider);
  late final ConflictResolutionService _service = ConflictResolutionService(
    journalDb: _db,
  );
  Future<JournalEntity?>? _localEntryFuture;
  String? _futureKey;

  /// Cache the local-entry lookup keyed by the conflict row shown — the
  /// entry and the version — so the [FutureBuilder] doesn't re-issue the DB
  /// read on every stream tick, but does read again when the page moves to
  /// another version. That happens when the version shown is resolved while
  /// another is still open: the resolution wrote a new local row, and the
  /// next version must be decided against it, not against the row before.
  ///
  /// The local side is read with its soft deletion: an edit that arrived
  /// after this device deleted the entry is a delete-versus-edit conflict,
  /// and the user decides it here.
  Future<JournalEntity?> _localEntryFor(Conflict conflict) {
    final key = '${conflict.id}/${conflict.versionKey}';
    if (_futureKey != key || _localEntryFuture == null) {
      _futureKey = key;
      _localEntryFuture = _db.journalEntityByIdIncludingDeleted(
        conflict.id,
      );
    }
    return _localEntryFuture!;
  }

  /// Runs a resolution of [pair]. One refused because this device stored
  /// another version of the entry since the page read it (the service's
  /// precondition) is not applied: the page reads the local side again and
  /// shows the difference as it now is, for the user to decide on.
  Future<void> _resolve(
    ConflictPair pair,
    Future<bool> Function() action,
  ) async {
    try {
      final applied = await action();
      if (!applied) {
        final stored = await _db.journalEntityByIdIncludingDeleted(
          pair.local.id,
        );
        if (!mounted) return;
        if (stored != null &&
            stored.meta.vectorClock != pair.local.meta.vectorClock) {
          // The side just read is shown at once, in place of the old one:
          // the page keeps its diff rather than flashing a loading scaffold.
          setState(() {
            _localEntryFuture = SynchronousFuture(stored);
          });
          context.showToast(
            tone: DesignSystemToastTone.warning,
            title: context.messages.conflictEntryChangedTitle,
          );
          return;
        }
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.conflictApplyFailedTitle,
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.conflictApplyFailedTitle,
        description: '$e',
      );
      return;
    }
    if (!mounted) return;
    context.showToast(
      tone: DesignSystemToastTone.success,
      title: context.messages.conflictResolvedToast,
    );
    ref.read(navServiceProvider).settingsDelegate.beamBack();
  }

  @override
  Widget build(BuildContext context) {
    final db = _db;
    return StreamBuilder<List<Conflict>>(
      stream: db.watchConflictById(widget.conflictId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyScaffoldWithTitle(
            context.messages.conflictDetailLoadErrorTitle,
            body: _ErrorBody(error: snapshot.error),
          );
        }
        final data = snapshot.data ?? const <Conflict>[];
        if (data.isEmpty) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loading(context);
          }
          return EmptyScaffoldWithTitle(
            context.messages.conflictDetailNotFoundTitle,
          );
        }
        final conflict = pickConflictVersion(data, widget.versionKey);
        final remote = fromSerialized(conflict.serialized);
        return FutureBuilder<JournalEntity?>(
          future: _localEntryFor(conflict),
          builder: (context, entrySnapshot) {
            if (entrySnapshot.hasError) {
              return EmptyScaffoldWithTitle(
                context.messages.conflictDetailLoadErrorTitle,
                body: _ErrorBody(error: entrySnapshot.error),
              );
            }
            if (entrySnapshot.connectionState == ConnectionState.waiting) {
              return _loading(context);
            }
            final local = entrySnapshot.data;
            if (local == null) {
              return EmptyScaffoldWithTitle(
                context.messages.conflictDetailEntryNotFoundTitle,
              );
            }
            final pair = ConflictPair(
              local: local,
              remote: remote,
            );
            return _Scaffold(
              diff: pair.diff,
              service: _service,
              pair: pair,
              resolve: (action) => _resolve(pair, action),
            );
          },
        );
      },
    );
  }

  Widget _loading(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// The conflict row of one entry the page shows, from [rows] ordered newest
/// first: the one [versionKey] names while it is unresolved, else the oldest
/// unresolved, else the newest.
@visibleForTesting
Conflict pickConflictVersion(List<Conflict> rows, String? versionKey) {
  bool unresolved(Conflict c) => c.status == ConflictStatus.unresolved.index;
  return rows.firstWhereOrNull(
        (c) => unresolved(c) && c.versionKey == versionKey,
      ) ??
      rows.lastWhereOrNull(unresolved) ??
      rows.first;
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({
    required this.diff,
    required this.service,
    required this.pair,
    required this.resolve,
  });

  final EntryDiff diff;
  final ConflictResolutionService service;
  final ConflictPair pair;
  final Future<void> Function(Future<bool> Function()) resolve;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return EmptyScaffoldWithTitle(
      context.messages.conflictPageTitle,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacing.step4),
        child: ConflictResolutionView(
          diff: diff,
          onKeepSide: (side) => resolve(() => service.keepSide(pair, side)),
          onCombine: ({required baseSide, required choices}) => resolve(
            () => service.combine(pair, baseSide: baseSide, choices: choices),
          ),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Text(
        '$error',
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: tokens.colors.alert.error.ink,
        ),
      ),
    );
  }
}
