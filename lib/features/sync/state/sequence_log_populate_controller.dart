import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
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
    this.populatedAgentEntitiesCount,
    this.populatedAgentLinksCount,
    this.totalCount,
    this.error,
    this.phase = SequenceLogPopulatePhase.idle,
  });

  final double progress;
  final bool isRunning;
  final int? populatedCount;
  final int? populatedLinksCount;
  final int? populatedAgentEntitiesCount;
  final int? populatedAgentLinksCount;
  final int? totalCount;
  final String? error;
  final SequenceLogPopulatePhase phase;

  SequenceLogPopulateState copyWith({
    double? progress,
    bool? isRunning,
    int? populatedCount,
    int? populatedLinksCount,
    int? populatedAgentEntitiesCount,
    int? populatedAgentLinksCount,
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
      populatedAgentEntitiesCount: clearCount
          ? null
          : populatedAgentEntitiesCount ?? this.populatedAgentEntitiesCount,
      populatedAgentLinksCount: clearCount
          ? null
          : populatedAgentLinksCount ?? this.populatedAgentLinksCount,
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
  populatingAgentEntities,
  populatingAgentLinks,
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
      final agentDb = getIt<AgentDatabase>();

      // Phase 1: Populate from journal entries (0.0–0.25)
      final populatedJournal = await sequenceLogService.populateFromJournal(
        entryStream: journalDb.streamEntriesWithVectorClock(),
        getTotalCount: journalDb.countAllJournalEntries,
        onProgress: (progress) {
          state = state.copyWith(progress: progress * 0.25);
        },
      );

      state = state.copyWith(
        progress: 0.25,
        phase: SequenceLogPopulatePhase.populatingLinks,
        populatedCount: populatedJournal,
      );

      // Phase 2: Populate from entry links (0.25–0.5)
      final populatedLinks = await sequenceLogService.populateFromEntryLinks(
        linkStream: journalDb.streamEntryLinksWithVectorClock(),
        getTotalCount: journalDb.countAllEntryLinks,
        onProgress: (progress) {
          state = state.copyWith(progress: 0.25 + progress * 0.25);
        },
      );

      state = state.copyWith(
        progress: 0.5,
        phase: SequenceLogPopulatePhase.populatingAgentEntities,
        populatedLinksCount: populatedLinks,
      );

      // Phase 3: Populate from agent entities (0.5–0.75)
      final populatedAgentEntities =
          await sequenceLogService.populateFromAgentEntities(
        entityStream: agentDb.streamAgentEntitiesWithVectorClock(),
        getTotalCount: agentDb.countAllAgentEntities,
        onProgress: (progress) {
          state = state.copyWith(progress: 0.5 + progress * 0.25);
        },
      );

      state = state.copyWith(
        progress: 0.75,
        phase: SequenceLogPopulatePhase.populatingAgentLinks,
        populatedAgentEntitiesCount: populatedAgentEntities,
      );

      // Phase 4: Populate from agent links (0.75–1.0)
      final populatedAgentLinks =
          await sequenceLogService.populateFromAgentLinks(
        linkStream: agentDb.streamAgentLinksWithVectorClock(),
        getTotalCount: agentDb.countAllAgentLinks,
        onProgress: (progress) {
          state = state.copyWith(progress: 0.75 + progress * 0.25);
        },
      );

      state = state.copyWith(
        isRunning: false,
        progress: 1,
        phase: SequenceLogPopulatePhase.done,
        populatedCount: populatedJournal,
        populatedLinksCount: populatedLinks,
        populatedAgentEntitiesCount: populatedAgentEntities,
        populatedAgentLinksCount: populatedAgentLinks,
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
