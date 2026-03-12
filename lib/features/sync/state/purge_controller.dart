import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/providers/service_providers.dart';

final purgeControllerProvider = NotifierProvider<PurgeController, PurgeState>(
  PurgeController.new,
);

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

class PurgeController extends Notifier<PurgeState> {
  PurgeController();

  late final JournalDb _db;

  @override
  PurgeState build() {
    _db = ref.watch(journalDbProvider);
    return const PurgeState();
  }

  Future<void> purgeDeleted() async {
    state = state.copyWith(isPurging: true, progress: 0, clearError: true);

    try {
      await for (final progress in _db.purgeDeleted()) {
        state = state.copyWith(progress: progress);
      }
    } catch (e, stackTrace) {
      ref
          .read(loggingServiceProvider)
          .captureException(
            e,
            domain: 'PurgeController',
            subDomain: 'purgeDeleted',
            stackTrace: stackTrace,
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
