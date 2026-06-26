import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';

const _zoomScaleKey = 'ZOOM_SCALE';

/// Scale applied when zoom is untouched / reset (1.0 = 100%).
const defaultZoomScale = 1.0;

/// Lower clamp for the zoom scale (50%).
const minZoomScale = 0.5;

/// Upper clamp for the zoom scale (300%).
const maxZoomScale = 3.0;

/// Increment applied by a single [ZoomController.zoomIn] / `zoomOut` step.
const zoomStep = 0.1;

/// App-wide UI zoom factor, persisted across launches.
///
/// `keepAlive` so the scale survives navigation. build returns
/// [defaultZoomScale] synchronously, then asynchronously hydrates the last
/// persisted value from [SettingsDb] under `ZOOM_SCALE`; hydration is
/// skipped if the user already adjusted zoom before it completed (so a
/// race can't clobber a fresh interaction). Every adjustment clamps to
/// [[minZoomScale], [maxZoomScale]], rounds to two decimals, and persists.
final zoomControllerProvider = NotifierProvider<ZoomController, double>(
  ZoomController.new,
  name: 'zoomControllerProvider',
);

class ZoomController extends Notifier<double> {
  bool _userAdjusted = false;

  @override
  double build() {
    _loadPersistedScale();
    return defaultZoomScale;
  }

  Future<void> _loadPersistedScale() async {
    final settingsDb = getIt<SettingsDb>();
    final stored = await settingsDb.itemByKey(_zoomScaleKey);
    // Skip if user already interacted before hydration completed.
    if (_userAdjusted) return;
    if (stored != null) {
      final parsed = double.tryParse(stored);
      if (parsed != null && parsed >= minZoomScale && parsed <= maxZoomScale) {
        state = parsed;
      }
    }
  }

  void _persist() {
    getIt<SettingsDb>().saveSettingsItem(
      _zoomScaleKey,
      state.toStringAsFixed(2),
    );
  }

  /// Increases the scale by [zoomStep] (capped at [maxZoomScale]) and
  /// persists it.
  void zoomIn() {
    _userAdjusted = true;
    final newScale = (state + zoomStep).clamp(minZoomScale, maxZoomScale);
    state = double.parse(newScale.toStringAsFixed(2));
    _persist();
  }

  /// Decreases the scale by [zoomStep] (floored at [minZoomScale]) and
  /// persists it.
  void zoomOut() {
    _userAdjusted = true;
    final newScale = (state - zoomStep).clamp(minZoomScale, maxZoomScale);
    state = double.parse(newScale.toStringAsFixed(2));
    _persist();
  }

  /// Restores [defaultZoomScale] (100%) and persists it.
  void resetZoom() {
    _userAdjusted = true;
    state = defaultZoomScale;
    _persist();
  }
}
