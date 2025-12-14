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
    this.populatedLinksCount,
    this.totalCount,
    this.error,
    this.phase = SequenceLogPopulatePhase.idle,
  });

  final double progress;
  final bool isRunning;
  final int? populatedCount;
  final int? populatedLinksCount;
  final int? totalCount;
  final String? error;
  final SequenceLogPopulatePhase phase;

  SequenceLogPopulateState copyWith({
    double? progress,
    bool? isRunning,
    int? populatedCount,
    int? populatedLinksCount,
    int? totalCount,
    String? error,
    SequenceLogPopulatePhase? phase,
    bool clearError = false,
    bool clearCount = false,
  }) {
    return SequenceLogPopulateState(
      progress: progress ?? this.progress,
      isRunning: isRunning ?? this.isRunning,
      populatedCount: clearCount ? null : populatedCount ?? this.populatedCount,
      populatedLinksCount:
          clearCount ? null : populatedLinksCount ?? this.populatedLinksCount,
      totalCount: clearCount ? null : totalCount ?? this.totalCount,
      error: clearError ? null : error ?? this.error,
      phase: phase ?? this.phase,
    );
  }
}

enum SequenceLogPopulatePhase {
  idle,
  populatingJournal,
  populatingLinks,
  done,
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
      phase: SequenceLogPopulatePhase.populatingJournal,
      clearError: true,
      clearCount: true,
    );

    try {
      final sequenceLogService = getIt<SyncSequenceLogService>();
      final journalDb = getIt<JournalDb>();

      // Phase 1: Populate from journal entries
      final populatedJournal = await sequenceLogService.populateFromJournal(
        entryStream: journalDb.streamEntriesWithVectorClock(),
        getTotalCount: journalDb.countAllJournalEntries,
        onProgress: (progress) {
          // Journal phase uses 0.0-0.5 of progress bar
          state = state.copyWith(progress: progress * 0.5);
        },
      );

      state = state.copyWith(
        progress: 0.5,
        phase: SequenceLogPopulatePhase.populatingLinks,
        populatedCount: populatedJournal,
      );

      // Phase 2: Populate from entry links
      final populatedLinks = await sequenceLogService.populateFromEntryLinks(
        linkStream: journalDb.streamEntryLinksWithVectorClock(),
        getTotalCount: journalDb.countAllEntryLinks,
        onProgress: (progress) {
          // Links phase uses 0.5-1.0 of progress bar
          state = state.copyWith(progress: 0.5 + progress * 0.5);
        },
      );

      state = state.copyWith(
        isRunning: false,
        progress: 1,
        phase: SequenceLogPopulatePhase.done,
        populatedCount: populatedJournal,
        populatedLinksCount: populatedLinks,
      );
    } catch (e) {
      state = state.copyWith(
        isRunning: false,
        progress: 0,
        phase: SequenceLogPopulatePhase.idle,
        error: e.toString(),
      );
    }
  }
}
