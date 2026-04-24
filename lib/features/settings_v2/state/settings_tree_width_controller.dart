import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

/// Persisted settings key — intentionally distinct from the shared
/// `PANE_WIDTH_LIST` used by Tasks/Projects/Dashboards so dragging
/// the Settings tree-nav can't bleed into the other surfaces (plan
/// §1 risk 5).
const settingsTreeNavWidthKey = 'SETTINGS_TREE_NAV_WIDTH';

/// Width constraints from spec §3 "Dimensions".
const defaultSettingsTreeNavWidth = 340.0;
const minSettingsTreeNavWidth = 280.0;
const maxSettingsTreeNavWidth = 480.0;

/// Keyboard step sizes from spec §3.1.
const settingsTreeNavWidthArrowStep = 8.0;
const settingsTreeNavWidthShiftArrowStep = 32.0;

/// How long to wait after the last drag update before persisting to
/// disk. Matches the shared `PaneWidthController` debounce.
@visibleForTesting
const settingsTreeNavWidthPersistDebounce = Duration(milliseconds: 300);

/// Holds the current width of the Settings tree-nav column, plus the
/// clamp + debounced persist machinery. A single scalar rather than
/// a compound value: the tree nav has exactly one variable dimension,
/// and keeping the notifier scalar keeps its test surface minimal.
class SettingsTreeNavWidth extends Notifier<double> {
  Timer? _debounce;
  bool _userAdjusted = false;

  @override
  double build() {
    ref.onDispose(() {
      _debounce?.cancel();
    });
    unawaited(_loadPersistedWidth());
    return defaultSettingsTreeNavWidth;
  }

  Future<void> _loadPersistedWidth() async {
    try {
      final db = getIt<SettingsDb>();
      final values = await db.itemsByKeys({settingsTreeNavWidthKey});
      // A mutation (drag / keyboard / reset) that lands before the
      // persisted value loads wins — the user's intent trumps the
      // slow disk read.
      if (_userAdjusted) return;

      final raw = values[settingsTreeNavWidthKey];
      if (raw == null) return;
      final parsed = double.tryParse(raw);
      if (parsed == null || !parsed.isFinite) return;

      state = parsed.clamp(
        minSettingsTreeNavWidth,
        maxSettingsTreeNavWidth,
      );
    } catch (error, stackTrace) {
      getIt<LoggingService>().captureException(
        error,
        domain: 'SETTINGS_TREE_NAV',
        subDomain: 'loadPersistedWidth',
        stackTrace: stackTrace,
      );
    }
  }

  /// Applies a drag delta. Clamps into the spec range and schedules
  /// a debounced persist — rapid drag frames coalesce into one disk
  /// write.
  void updateBy(double delta) {
    final next = (state + delta).clamp(
      minSettingsTreeNavWidth,
      maxSettingsTreeNavWidth,
    );
    _commit(next);
  }

  /// Sets the width to an absolute value (keyboard step, drag end,
  /// external adjustment). Clamps + persists the same way.
  void setTo(double width) {
    if (!width.isFinite) return;
    final next = width.clamp(
      minSettingsTreeNavWidth,
      maxSettingsTreeNavWidth,
    );
    _commit(next);
  }

  /// Resets to [defaultSettingsTreeNavWidth] and flushes the debounce
  /// timer — double-click / Home always writes immediately, no
  /// 300 ms lag.
  ///
  /// If the value is already the default AND the user has not made
  /// any mutation since construction, skip the persist entirely —
  /// resetting from default to default while the default is what's
  /// on disk is a pure no-op. We still cancel any in-flight debounce
  /// because the caller's intent is "stop; be at default now".
  void resetToDefault() {
    _debounce?.cancel();
    final alreadyDefault = state == defaultSettingsTreeNavWidth;
    final hadNoMutation = !_userAdjusted;
    // Mark as user-adjusted on entry so a still-pending
    // `_loadPersistedWidth` cannot overwrite this explicit reset
    // with a stale persisted non-default value. The early return
    // below is still a pure no-op because nothing observes
    // `_userAdjusted` through it.
    _userAdjusted = true;
    if (alreadyDefault && hadNoMutation) {
      return;
    }
    if (!alreadyDefault) {
      state = defaultSettingsTreeNavWidth;
    }
    unawaited(_persist(defaultSettingsTreeNavWidth));
  }

  void _commit(double value) {
    _userAdjusted = true;
    if (state == value) return;
    state = value;
    _debounce?.cancel();
    _debounce = Timer(
      settingsTreeNavWidthPersistDebounce,
      () => unawaited(_persist(state)),
    );
  }

  Future<void> _persist(double value) async {
    try {
      await getIt<SettingsDb>().saveSettingsItem(
        settingsTreeNavWidthKey,
        value.toStringAsFixed(1),
      );
    } catch (error, stackTrace) {
      getIt<LoggingService>().captureException(
        error,
        domain: 'SETTINGS_TREE_NAV',
        subDomain: 'persist',
        stackTrace: stackTrace,
      );
    }
  }
}

final settingsTreeNavWidthProvider =
    NotifierProvider<SettingsTreeNavWidth, double>(
      SettingsTreeNavWidth.new,
    );
