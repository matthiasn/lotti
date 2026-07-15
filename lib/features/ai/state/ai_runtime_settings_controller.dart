import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/model/ai_runtime_settings.dart';
import 'package:lotti/get_it.dart';

/// Holds device-local AI runtime settings and persists user changes.
final aiRuntimeSettingsControllerProvider =
    NotifierProvider<AiRuntimeSettingsController, AiRuntimeSettings>(
      AiRuntimeSettingsController.new,
      name: 'aiRuntimeSettingsControllerProvider',
    );

/// Loads, exposes, and persists the device-local AI runtime settings.
class AiRuntimeSettingsController extends Notifier<AiRuntimeSettings> {
  bool _userChanged = false;

  @override
  AiRuntimeSettings build() {
    unawaited(_load());
    return const AiRuntimeSettings();
  }

  Future<void> _load() async {
    try {
      final raw = await getIt<SettingsDb>().itemByKey(
        agentWakeConcurrencySettingsKey,
      );
      if (!ref.mounted || _userChanged) return;
      state = AiRuntimeSettings.fromStoredAgentWakeConcurrency(raw);
    } on Object {
      // Keep defaults when settings storage is unavailable. Agent wakes must
      // remain functional even when a local preference read fails.
    }
  }

  /// Updates and persists the maximum number of concurrent agent wakes.
  void setAgentWakeConcurrency(int value) {
    _userChanged = true;
    state = state.copyWith(agentWakeConcurrency: value);
    unawaited(
      getIt<SettingsDb>().saveSettingsItem(
        agentWakeConcurrencySettingsKey,
        state.agentWakeConcurrency.toString(),
      ),
    );
  }
}
