import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/get_it.dart';

final sequenceLogPopulateControllerProvider =
    NotifierProvider<SequenceLogPopulateController, SequenceLogPopulateState>(
  SequenceLogPopulateController.new,
);

class SequenceLogPopulateState {
  const SequenceLogPopulateState({
    this.progress = 0,
    this.isRunning = false,
    this.populatedCount,
    this.totalCount,
    this.error,
  });

  final double progress;
  final bool isRunning;
  final int? populatedCount;
  final int? totalCount;
  final String? error;

  SequenceLogPopulateState copyWith({
    double? progress,
    bool? isRunning,
    int? populatedCount,
    int? totalCount,
    String? error,
    bool clearError = false,
    bool clearCount = false,
  }) {
    return SequenceLogPopulateState(
      progress: progress ?? this.progress,
      isRunning: isRunning ?? this.isRunning,
      populatedCount: clearCount ? null : populatedCount ?? this.populatedCount,
      totalCount: clearCount ? null : totalCount ?? this.totalCount,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class SequenceLogPopulateController extends Notifier<SequenceLogPopulateState> {
  @override
  SequenceLogPopulateState build() {
    return const SequenceLogPopulateState();
  }

  Future<void> populateSequenceLog() async {
    state = state.copyWith(
      isRunning: true,
      progress: 0,
      clearError: true,
      clearCount: true,
    );

    try {
      final sequenceLogService = getIt<SyncSequenceLogService>();
      final journalDb = getIt<JournalDb>();

      final populated = await sequenceLogService.populateFromJournal(
        entryStream: journalDb.streamEntriesWithVectorClock(),
        getTotalCount: journalDb.countAllJournalEntries,
        onProgress: (progress) {
          state = state.copyWith(progress: progress);
        },
      );

      state = state.copyWith(
        isRunning: false,
        progress: 1,
        populatedCount: populated,
      );
    } catch (e) {
      state = state.copyWith(
        isRunning: false,
        progress: 0,
        error: e.toString(),
      );
    }
  }
}
