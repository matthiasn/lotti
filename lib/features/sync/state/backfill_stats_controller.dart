import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/get_it.dart';

/// State for backfill stats and manual operations.
class BackfillStatsState {
  const BackfillStatsState({
    this.stats,
    this.isLoading = false,
    this.isProcessing = false,
    this.isReRequesting = false,
    this.isResetting = false,
    this.isRetiringStuck = false,
    this.isResettingAllUnresolvable = false,
    this.error,
  });

  final BackfillStats? stats;
  final bool isLoading;
  final bool isProcessing;
  final bool isReRequesting;
  final bool isResetting;
  final bool isRetiringStuck;
  final bool isResettingAllUnresolvable;
  final String? error;

  BackfillStatsState copyWith({
    BackfillStats? stats,
    bool? isLoading,
    bool? isProcessing,
    bool? isReRequesting,
    bool? isResetting,
    bool? isRetiringStuck,
    bool? isResettingAllUnresolvable,
    String? error,
    bool clearError = false,
  }) {
    return BackfillStatsState(
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      isReRequesting: isReRequesting ?? this.isReRequesting,
      isResetting: isResetting ?? this.isResetting,
      isRetiringStuck: isRetiringStuck ?? this.isRetiringStuck,
      isResettingAllUnresolvable:
          isResettingAllUnresolvable ?? this.isResettingAllUnresolvable,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// Cadence at which the Backfill Settings page auto-refreshes stats
/// while it is open AND the app is in the foreground. Keeps
/// `missing` / `requested` counts live as backfill works them down
/// without requiring the user to hit the manual refresh button. The
/// stats aggregation ran 175 times per hour on a real desktop at the
/// previous 2-second cadence and showed up as a top offender in the
/// slow-query log, so the interval is now 30 s and we also pause the
/// timer entirely when the app is backgrounded (no user there to
/// watch the numbers move anyway).
///
/// Zero cost when the page is closed: the provider is auto-disposed,
/// so Riverpod tears it down on last unwatch,
/// firing the `ref.onDispose` that cancels this timer. Zero cost
/// when the app is backgrounded: the `AppLifecycleListener` stops
/// the timer on `onHide` and re-arms it on `onShow`.
const Duration _autoRefreshInterval = Duration(seconds: 30);

/// Live missing-row count for the Backfill Settings page.
///
/// The full per-host stats aggregate remains throttled because it is intended
/// for diagnostics. This focused reactive query is cheap enough to follow
/// committed sequence-log changes, keeping the prominent missing counters in
/// step with the inbound queue while a large backfill drains.
final StreamProvider<int> backfillMissingCountProvider =
    StreamProvider.autoDispose<int>(
      (ref) => getIt<SyncSequenceLogService>().watchBackfillMissingCount(),
      name: 'backfillMissingCountProvider',
    );

/// Backs the Backfill Settings page: loads and auto-refreshes [BackfillStats]
/// (throttled, foreground-only — see [_autoRefreshInterval]) and exposes the
/// manual operations (full backfill, re-request, reset/retire of stuck and
/// unresolvable entries), reflecting each operation's in-progress state on
/// [BackfillStatsState] and refreshing the aggregate afterward.
final NotifierProvider<BackfillStatsController, BackfillStatsState>
backfillStatsControllerProvider =
    NotifierProvider.autoDispose<BackfillStatsController, BackfillStatsState>(
      BackfillStatsController.new,
      name: 'backfillStatsControllerProvider',
    );

class BackfillStatsController extends Notifier<BackfillStatsState> {
  Timer? _autoRefreshTimer;
  AppLifecycleListener? _lifecycleListener;
  bool _appVisible = true;

  /// Guard against overlapping silent refreshes when the underlying
  /// aggregation query runs slower than [_autoRefreshInterval] (large
  /// `sync_sequence_log`, contended SQLite). Without this, the timer
  /// would stack concurrent `getBackfillStats` reads and overwrite
  /// `state.stats` with potentially out-of-order results.
  bool _silentRefreshInFlight = false;

  @override
  BackfillStatsState build() {
    // Load stats on build
    _loadStats();

    // Track app visibility so a backgrounded app (with the Backfill
    // Settings provider still technically alive because a nav stack
    // kept it mounted) doesn't keep running the aggregation.
    _lifecycleListener = AppLifecycleListener(
      onShow: () {
        _appVisible = true;
        _startTimer();
      },
      onHide: () {
        _appVisible = false;
        _autoRefreshTimer?.cancel();
        _autoRefreshTimer = null;
      },
    );

    _startTimer();

    ref.onDispose(() {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
      _lifecycleListener?.dispose();
      _lifecycleListener = null;
    });

    return const BackfillStatsState(isLoading: true);
  }

  void _startTimer() {
    _autoRefreshTimer?.cancel();
    if (!_appVisible) return;
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (!ref.mounted) return;
      if (!_appVisible) return;
      // Skip while a manual action is running — those paths call
      // `_loadStats` themselves on completion.
      if (state.isProcessing ||
          state.isReRequesting ||
          state.isResetting ||
          state.isRetiringStuck ||
          state.isResettingAllUnresolvable) {
        return;
      }
      // Skip if the previous silent refresh hasn't returned yet. A
      // slow query under contention must not cause us to stack N
      // pending reads that will each rewrite `state.stats` in
      // whatever order they happen to land.
      if (_silentRefreshInFlight) return;
      _loadStatsSilent();
    });
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

  /// Background refresh variant that only updates `stats` — it does NOT
  /// clear an existing error or toggle `isLoading`, so a manual action
  /// that surfaced an error keeps the error visible until the user
  /// explicitly refreshes or triggers a new action. Used by the
  /// auto-refresh timer. Sets [_silentRefreshInFlight] for the
  /// duration of the query so the timer can short-circuit overlapping
  /// fires while a slow aggregation is still running.
  Future<void> _loadStatsSilent() async {
    _silentRefreshInFlight = true;
    try {
      final sequenceLogService = getIt<SyncSequenceLogService>();
      final stats = await sequenceLogService.getBackfillStats();
      if (!ref.mounted) return;
      state = state.copyWith(stats: stats);
    } catch (_) {
      // Intentionally swallow — a transient DB error during background
      // refresh should not surface as a UI error banner; the next tick
      // or a manual refresh will retry.
    } finally {
      _silentRefreshInFlight = false;
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
    if (state.isProcessing ||
        state.isReRequesting ||
        state.isResetting ||
        state.isRetiringStuck ||
        state.isResettingAllUnresolvable) {
      return;
    }

    state = state.copyWith(
      isProcessing: true,
      clearError: true,
    );

    try {
      final backfillService = getIt<BackfillRequestService>();
      await backfillService.processFullBackfill();

      if (!ref.mounted) return;
      state = state.copyWith(isProcessing: false);

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

  /// Reset unresolvable entries that now have a known payload back to missing.
  Future<void> resetUnresolvable() async {
    if (!ref.mounted) return;
    if (state.isProcessing ||
        state.isReRequesting ||
        state.isResetting ||
        state.isRetiringStuck ||
        state.isResettingAllUnresolvable) {
      return;
    }

    state = state.copyWith(
      isResetting: true,
      clearError: true,
    );

    try {
      final sequenceLogService = getIt<SyncSequenceLogService>();
      await sequenceLogService.resetUnresolvableEntries();

      if (!ref.mounted) return;
      state = state.copyWith(isResetting: false);

      // Refresh stats after reset
      await _loadStats();
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isResetting: false,
        error: e.toString(),
      );
    }
  }

  /// Manually retire every currently-open `missing`/`requested` row to
  /// `unresolvable`, bypassing the usual 7-day amnesty window. Exposed
  /// as a Backfill Settings diagnostic action for the case where a
  /// device has accumulated watermark-blocking rows that are already
  /// stale (e.g. after a sync-room change rolled host ids) and the user
  /// wants immediate recovery without waiting for the periodic sweep.
  ///
  /// Effectively calls `retireAgedOutRequestedEntries(amnestyWindow:
  /// Duration.zero)` — any row with `created_at < now` (all of them)
  /// matches.
  Future<void> retireStuckNow() async {
    if (!ref.mounted) return;
    if (state.isProcessing ||
        state.isReRequesting ||
        state.isResetting ||
        state.isRetiringStuck ||
        state.isResettingAllUnresolvable) {
      return;
    }

    state = state.copyWith(
      isRetiringStuck: true,
      clearError: true,
    );

    try {
      final sequenceLogService = getIt<SyncSequenceLogService>();
      await sequenceLogService.retireAgedOutRequestedEntries(
        amnestyWindow: Duration.zero,
      );

      if (!ref.mounted) return;
      state = state.copyWith(isRetiringStuck: false);

      // Refresh stats after retirement
      await _loadStats();
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isRetiringStuck: false,
        error: e.toString(),
      );
    }
  }

  /// Reset every `unresolvable` row back to `missing` so the normal
  /// backfill sweep will ask peers again. Covers the case where the
  /// originating host is dead but a currently-alive peer still has
  /// the payload — the existing "Reset Unresolvable" action only
  /// covers rows whose `entry_id` was already repopulated locally,
  /// which is not the common case after a bulk retirement.
  Future<void> resetAllUnresolvable() async {
    if (!ref.mounted) return;
    if (state.isProcessing ||
        state.isReRequesting ||
        state.isResetting ||
        state.isRetiringStuck ||
        state.isResettingAllUnresolvable) {
      return;
    }

    state = state.copyWith(
      isResettingAllUnresolvable: true,
      clearError: true,
    );

    try {
      final sequenceLogService = getIt<SyncSequenceLogService>();
      await sequenceLogService.resetAllUnresolvableEntries();

      if (!ref.mounted) return;
      state = state.copyWith(isResettingAllUnresolvable: false);

      await _loadStats();
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isResettingAllUnresolvable: false,
        error: e.toString(),
      );
    }
  }

  /// Re-request entries that are in 'requested' status but never received.
  Future<void> triggerReRequest() async {
    if (!ref.mounted) return;
    if (state.isProcessing ||
        state.isReRequesting ||
        state.isResetting ||
        state.isRetiringStuck ||
        state.isResettingAllUnresolvable) {
      return;
    }

    state = state.copyWith(
      isReRequesting: true,
      clearError: true,
    );

    try {
      final backfillService = getIt<BackfillRequestService>();
      await backfillService.processReRequest();

      if (!ref.mounted) return;
      state = state.copyWith(isReRequesting: false);

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
