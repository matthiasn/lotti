import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'backfill_config_controller.g.dart';

const _backfillEnabledKey = 'backfill_enabled';

/// Controller for backfill configuration settings.
/// Allows enabling/disabling automatic backfill sync (useful on metered/slow networks).
@riverpod
class BackfillConfigController extends _$BackfillConfigController {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_backfillEnabledKey) ?? true; // Enabled by default
  }

  /// Enable or disable backfill sync.
  Future<void> setEnabled({required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backfillEnabledKey, enabled);
    state = AsyncData(enabled);
  }

  /// Toggle backfill sync enabled state.
  Future<void> toggle() async {
    final currentValue = state.valueOrNull ?? true;
    await setEnabled(enabled: !currentValue);
  }
}

/// Simple synchronous check for backfill enabled state.
/// Uses cached SharedPreferences for quick access in service code.
Future<bool> isBackfillEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_backfillEnabledKey) ?? true;
}
