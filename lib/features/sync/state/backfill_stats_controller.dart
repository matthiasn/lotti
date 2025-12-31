import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backfill_stats_controller.g.dart';

/// State for backfill stats and manual operations.
class BackfillStatsState {
  const BackfillStatsState({
    this.stats,
    this.isLoading = false,
    this.isProcessing = false,
    this.isReRequesting = false,
    this.lastProcessedCount,
    this.lastReRequestedCount,
    this.error,
  });

  final BackfillStats? stats;
  final bool isLoading;
  final bool isProcessing;
  final bool isReRequesting;
  final int? lastProcessedCount;
  final int? lastReRequestedCount;
  final String? error;

  BackfillStatsState copyWith({
    BackfillStats? stats,
    bool? isLoading,
    bool? isProcessing,
    bool? isReRequesting,
    int? lastProcessedCount,
    int? lastReRequestedCount,
    String? error,
    bool clearError = false,
    bool clearLastProcessed = false,
    bool clearLastReRequested = false,
  }) {
    return BackfillStatsState(
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      isReRequesting: isReRequesting ?? this.isReRequesting,
      lastProcessedCount: clearLastProcessed
          ? null
          : lastProcessedCount ?? this.lastProcessedCount,
      lastReRequestedCount: clearLastReRequested
          ? null
          : lastReRequestedCount ?? this.lastReRequestedCount,
      error: clearError ? null : error ?? this.error,
    );
  }
}

@riverpod
class BackfillStatsController extends _$BackfillStatsController {
  @override
  BackfillStatsState build() {
    // Load stats on build
    _loadStats();
    return const BackfillStatsState(isLoading: true);
  }

  Future<void> _loadStats() async {
    try {
      final sequenceLogService = getIt<SyncSequenceLogService>();
      final stats = await sequenceLogService.getBackfillStats();
      if (!ref.mounted) return;
      state = state.copyWith(
        stats: stats,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh stats from database.
  Future<void> refresh() async {
    if (!ref.mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);
    await _loadStats();
  }

  /// Trigger a full historical backfill request.
  Future<void> triggerFullBackfill() async {
    if (!ref.mounted) return;
    if (state.isProcessing || state.isReRequesting) return;

    state = state.copyWith(
      isProcessing: true,
      clearError: true,
      clearLastProcessed: true,
    );

    try {
      final backfillService = getIt<BackfillRequestService>();
      final count = await backfillService.processFullBackfill();

      if (!ref.mounted) return;
      state = state.copyWith(
        isProcessing: false,
        lastProcessedCount: count,
      );

      // Refresh stats after processing
      await _loadStats();
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isProcessing: false,
        error: e.toString(),
      );
    }
  }

  /// Re-request entries that are in 'requested' status but never received.
  Future<void> triggerReRequest() async {
    if (!ref.mounted) return;
    if (state.isProcessing || state.isReRequesting) return;

    state = state.copyWith(
      isReRequesting: true,
      clearError: true,
      clearLastReRequested: true,
    );

    try {
      final backfillService = getIt<BackfillRequestService>();
      final count = await backfillService.processReRequest();

      if (!ref.mounted) return;
      state = state.copyWith(
        isReRequesting: false,
        lastReRequestedCount: count,
      );

      // Refresh stats after processing
      await _loadStats();
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isReRequesting: false,
        error: e.toString(),
      );
    }
  }
}
