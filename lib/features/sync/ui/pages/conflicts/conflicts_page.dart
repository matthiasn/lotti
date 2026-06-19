import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/conflict_list_item.dart';
import 'package:lotti/features/sync/ui/widgets/sync_list_scaffold.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

enum _ConflictListFilter {
  unresolved,
  resolved,
}

/// Embeddable body alias for the Settings V2 detail pane (plan
/// step 8). See `CategoriesListBody` for the polish note about the
/// duplicate header.
class ConflictsBody extends StatelessWidget {
  const ConflictsBody({super.key});

  @override
  Widget build(BuildContext context) => const ConflictsPage();
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
        unresolvedSubscription = _db
            .watchConflicts(ConflictStatus.unresolved)
            .listen(
              (value) {
                unresolved = value;
                emitIfReady();
              },
              onError: (Object error, StackTrace stackTrace) {
                if (!controller.isClosed) {
                  controller.addError(error, stackTrace);
                }
              },
            );

        resolvedSubscription = _db
            .watchConflicts(ConflictStatus.resolved)
            .listen(
              (value) {
                resolved = value;
                emitIfReady();
              },
              onError: (Object error, StackTrace stackTrace) {
                if (!controller.isClosed) {
                  controller.addError(error, stackTrace);
                }
              },
            );
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
        unresolvedSubscription = null;
        resolvedSubscription = null;
        unresolved = null;
        resolved = null;
        if (!controller.isClosed) {
          await controller.close();
        }
      };

    return controller.stream;
  }

  ConflictStatus? _statusFromIndex(int statusIndex) {
    if (statusIndex < 0 || statusIndex >= ConflictStatus.values.length) {
      return null;
    }
    return ConflictStatus.values[statusIndex];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = context.designTokens.colors;
    // The "diverged" semantic token is the design-system equivalent of the
    // amber once hard-coded here; its foreground pairs with alert surfaces.
    final divergedAccent = colors.conflict.diverged.color;
    final divergedForeground = colors.text.onInteractiveAlert;
    final filters = <_ConflictListFilter, SyncFilterOption<Conflict>>{
      _ConflictListFilter.unresolved: SyncFilterOption<Conflict>(
        labelBuilder: (ctx) => ctx.messages.conflictsUnresolved,
        predicate: (conflict) =>
            _statusFromIndex(conflict.status) == ConflictStatus.unresolved,
        icon: Icons.report_problem_outlined,
        selectedColor: divergedAccent,
        selectedForegroundColor: divergedForeground,
        hideCountWhenZero: true,
        countAccentColor: divergedAccent,
        countAccentForegroundColor: divergedForeground,
      ),
      _ConflictListFilter.resolved: SyncFilterOption<Conflict>(
        labelBuilder: (ctx) => ctx.messages.conflictsResolved,
        predicate: (conflict) =>
            _statusFromIndex(conflict.status) == ConflictStatus.resolved,
        icon: Icons.verified_outlined,
        selectedColor: colorScheme.primary,
        selectedForegroundColor: colorScheme.onPrimary,
        showCount: false,
      ),
    };

    return SyncListScaffold<Conflict, _ConflictListFilter>(
      title: context.messages.settingsConflictsTitle,
      subtitle: context.messages.settingsSyncConflictsSubtitle,
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
