import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';

/// Persisted settings key for the goal page's check-in rail width.
const goalTimelineRailWidthKey = 'PANE_WIDTH_GOAL_TIMELINE_RAIL';

/// The narrowest the check-in rail gets, dragged or not.
const double kGoalTimelineRailMinWidth = 360;

/// The widest a drag can make the check-in rail; the dashboard's fold width
/// beside it bounds it further on a narrower pane.
const double kGoalTimelineRailDragMaxWidth = 800;

/// How long to wait after the last drag frame before writing the width to
/// disk, as the other resizable panes do.
@visibleForTesting
const goalTimelineRailPersistDebounce = Duration(milliseconds: 300);

/// The width the person dragged the goal page's check-in rail to, or null
/// while they never have (or it is still loading) — the page then sizes the
/// rail from the pane.
///
/// One width for every goal, persisted (debounced) under
/// [goalTimelineRailWidthKey]. A drag that lands before the stored width
/// has loaded wins over the late load.
class GoalTimelineRailWidth extends AsyncNotifier<double?> {
  late DomainLogger _logger;
  Timer? _debounce;
  bool _adjusted = false;
  bool _disposed = false;

  @override
  Future<double?> build() async {
    _logger = ref.watch(domainLoggerProvider);
    ref.onDispose(() {
      _disposed = true;
      _debounce?.cancel();
    });
    final stored = await _load();
    // A drag that landed while the stored width loaded wins over it.
    return _adjusted ? state.value : stored;
  }

  Future<double?> _load() async {
    try {
      final values = await ref.read(settingsDbProvider).itemsByKeys({
        goalTimelineRailWidthKey,
      });
      final parsed = double.tryParse(values[goalTimelineRailWidthKey] ?? '');
      if (parsed == null || !parsed.isFinite) return null;
      return parsed.clamp(
        kGoalTimelineRailMinWidth,
        kGoalTimelineRailDragMaxWidth,
      );
    } catch (error, stackTrace) {
      _logger.error(
        LogDomain.settings,
        error,
        stackTrace: stackTrace,
        subDomain: 'goalTimelineRailWidth.load',
      );
      return null;
    }
  }

  /// Sets the rail to [width] — the width it showed plus the drag — clamped
  /// to [kGoalTimelineRailMinWidth]..[kGoalTimelineRailDragMaxWidth], and
  /// writes it to disk once the drag rests.
  void set(double width) {
    _adjusted = true;
    final next = width.clamp(
      kGoalTimelineRailMinWidth,
      kGoalTimelineRailDragMaxWidth,
    );
    if (state.value == next) return;
    state = AsyncData(next);
    _debounce?.cancel();
    _debounce = Timer(goalTimelineRailPersistDebounce, () async {
      if (!_disposed) await _persist(next);
    });
  }

  Future<void> _persist(double value) async {
    try {
      await ref
          .read(settingsDbProvider)
          .saveSettingsItem(goalTimelineRailWidthKey, value.toStringAsFixed(1));
    } catch (error, stackTrace) {
      if (_disposed) return;
      _logger.error(
        LogDomain.settings,
        error,
        stackTrace: stackTrace,
        subDomain: 'goalTimelineRailWidth.persist',
      );
    }
  }
}

/// The check-in rail's dragged width; see [GoalTimelineRailWidth].
final goalTimelineRailWidthProvider =
    AsyncNotifierProvider<GoalTimelineRailWidth, double?>(
      GoalTimelineRailWidth.new,
      name: 'goalTimelineRailWidthProvider',
    );
