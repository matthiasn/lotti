import 'package:flutter/material.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/conflict_resolution_service.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/conflict_resolution_view.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_field_diff.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';

/// Conflict resolution page. Loads the local + remote versions of the
/// conflicted entry, renders a full field-level diff, and lets the user keep
/// either side or combine them — applied through [ConflictResolutionService].
class ConflictDetailRoute extends StatefulWidget {
  const ConflictDetailRoute({required this.conflictId, super.key});

  final String conflictId;

  @override
  State<ConflictDetailRoute> createState() => _ConflictDetailRouteState();
}

class _ConflictDetailRouteState extends State<ConflictDetailRoute> {
  final ConflictResolutionService _service = ConflictResolutionService();
  Future<JournalEntity?>? _localEntryFuture;
  String? _futureKey;

  /// Cache the local-entry lookup keyed by conflict id so the
  /// [FutureBuilder] doesn't re-issue the DB read on every stream tick.
  Future<JournalEntity?> _localEntryFor(String conflictId) {
    if (_futureKey != conflictId || _localEntryFuture == null) {
      _futureKey = conflictId;
      _localEntryFuture = getIt<JournalDb>().journalEntityById(conflictId);
    }
    return _localEntryFuture!;
  }

  Future<void> _resolve(Future<bool> Function() action) async {
    try {
      final applied = await action();
      if (!applied) {
        if (!mounted) return;
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
    settingsBeamerDelegate.beamBack();
  }

  @override
  Widget build(BuildContext context) {
    final db = getIt<JournalDb>();
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
        final conflict = data.first;
        final remote = fromSerialized(conflict.serialized);
        return FutureBuilder<JournalEntity?>(
          future: _localEntryFor(conflict.id),
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
              conflict: conflict,
              local: local,
              remote: remote,
            );
            return _Scaffold(
              diff: pair.diff,
              service: _service,
              pair: pair,
              resolve: _resolve,
            );
          },
        );
      },
    );
  }

  Widget _loading(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
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
          color: tokens.colors.alert.error.defaultColor,
        ),
      ),
    );
  }
}
