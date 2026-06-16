import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';

final purgeControllerProvider = NotifierProvider<PurgeController, PurgeState>(
  PurgeController.new,
);

/// UI state for the "purge deleted entries" maintenance action: purge
/// [progress] (0–1), the [isPurging] flag, and the last [error] on failure.
class PurgeState {
  const PurgeState({
    this.progress = 0,
    this.isPurging = false,
    this.error,
  });

  final double progress;
  final bool isPurging;
  final String? error;

  PurgeState copyWith({
    double? progress,
    bool? isPurging,
    String? error,
    bool clearError = false,
  }) {
    return PurgeState(
      progress: progress ?? this.progress,
      isPurging: isPurging ?? this.isPurging,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// Drives the permanent removal of soft-deleted journal rows from the local DB,
/// streaming progress into [PurgeState] for the maintenance UI.
class PurgeController extends Notifier<PurgeState> {
  PurgeController();

  late final JournalDb _db;

  @override
  PurgeState build() {
    _db = ref.watch(journalDbProvider);
    return const PurgeState();
  }

  /// Purges all soft-deleted rows, updating [PurgeState.progress] as the DB
  /// reports it and capturing any failure into [PurgeState.error].
  Future<void> purgeDeleted() async {
    state = state.copyWith(isPurging: true, progress: 0, clearError: true);

    try {
      await for (final progress in _db.purgeDeleted()) {
        state = state.copyWith(progress: progress);
      }
    } catch (e, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.database,
        e,
        stackTrace: stackTrace,
        subDomain: 'PurgeController.purgeDeleted',
      );
      state = state.copyWith(
        isPurging: false,
        progress: 0,
        error: e.toString(),
      );
      return;
    }
    state = state.copyWith(isPurging: false);
  }
}
