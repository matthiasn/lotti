import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/file_utils.dart';

final purgeControllerProvider =
    NotifierProvider<PurgeController, PurgeState>(PurgeController.new);

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
    _db = getIt<JournalDb>();
    return const PurgeState();
  }

  Future<void> purgeDeleted() async {
    state = state.copyWith(isPurging: true, progress: 0, clearError: true);

    try {
      await for (final progress in _db.purgeDeleted()) {
        state = state.copyWith(progress: progress);
      }
    } catch (e, stackTrace) {
      await getIt<LoggingDb>().log(
        LogEntry(
          id: uuid.v1(),
          createdAt: DateTime.now().toIso8601String(),
          domain: 'PurgeController',
          subDomain: 'purgeDeleted',
          message: e.toString(),
          stacktrace: stackTrace.toString(),
          level: InsightLevel.error.name.toUpperCase(),
          type: InsightType.exception.name.toUpperCase(),
        ),
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
