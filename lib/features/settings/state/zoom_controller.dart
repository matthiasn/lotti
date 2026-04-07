import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'zoom_controller.g.dart';

const _zoomScaleKey = 'ZOOM_SCALE';
const defaultZoomScale = 1.0;
const minZoomScale = 0.5;
const maxZoomScale = 3.0;
const zoomStep = 0.1;

@Riverpod(keepAlive: true)
class ZoomController extends _$ZoomController {
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

  void zoomIn() {
    _userAdjusted = true;
    final newScale = (state + zoomStep).clamp(minZoomScale, maxZoomScale);
    state = double.parse(newScale.toStringAsFixed(2));
    _persist();
  }

  void zoomOut() {
    _userAdjusted = true;
    final newScale = (state - zoomStep).clamp(minZoomScale, maxZoomScale);
    state = double.parse(newScale.toStringAsFixed(2));
    _persist();
  }

  void resetZoom() {
    _userAdjusted = true;
    state = defaultZoomScale;
    _persist();
  }
}
