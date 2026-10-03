import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agent_wake_cadence.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/model/ai_runtime_settings.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/get_it.dart';

/// The explicit device-wide fallback for otherwise unconfigured inference.
final defaultInferenceProfileControllerProvider =
    AsyncNotifierProvider<DefaultInferenceProfileController, String?>(
      DefaultInferenceProfileController.new,
      name: 'defaultInferenceProfileControllerProvider',
    );

class DefaultInferenceProfileController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    try {
      return await ref.watch(aiConfigRepositoryProvider).getDefaultProfileId();
    } on Object {
      // A failed preference read must not prevent choosing a new default.
      return null;
    }
  }

  Future<void> _pendingSave = Future<void>.value();

  /// Serializes choices and publishes only persisted values. A failed save
  /// leaves the last choice visible and does not block subsequent changes.
  Future<void> selectProfile(String? profileId) {
    final save = _pendingSave.then((_) async {
      await future;
      await ref.read(aiConfigRepositoryProvider).setDefaultProfileId(profileId);
      if (ref.mounted) state = AsyncData(profileId);
    });
    _pendingSave = save.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return save;
  }
}

/// Holds device-local AI runtime settings and persists user changes.
final aiRuntimeSettingsControllerProvider =
    NotifierProvider<AiRuntimeSettingsController, AiRuntimeSettings>(
      AiRuntimeSettingsController.new,
      name: 'aiRuntimeSettingsControllerProvider',
    );

/// Loads, exposes, and persists the device-local AI runtime settings.
class AiRuntimeSettingsController extends Notifier<AiRuntimeSettings> {
  /// Settings the user changed before the stored values loaded; the load
  /// must not overwrite them.
  final _userChangedKeys = <String>{};

  SettingsDb get _settingsDb => getIt<SettingsDb>();

  @override
  AiRuntimeSettings build() {
    unawaited(_load());
    return const AiRuntimeSettings();
  }

  Future<void> _load() async {
    try {
      final (concurrency, cadence) = await (
        _settingsDb.itemByKey(agentWakeConcurrencySettingsKey),
        _settingsDb.itemByKey(defaultAgentWakeCadenceSettingsKey),
      ).wait;
      if (!ref.mounted) return;
      final stored = AiRuntimeSettings.fromStored(
        agentWakeConcurrency: concurrency,
        defaultWakeCadence: cadence,
      );
      state = state.copyWith(
        agentWakeConcurrency:
            _userChangedKeys.contains(agentWakeConcurrencySettingsKey)
            ? null
            : stored.agentWakeConcurrency,
        defaultWakeCadence:
            _userChangedKeys.contains(defaultAgentWakeCadenceSettingsKey)
            ? null
            : stored.defaultWakeCadence,
      );
    } on Object {
      // Keep defaults when settings storage is unavailable. Agent wakes must
      // remain functional even when a local preference read fails.
    }
  }

  /// Updates and persists the maximum number of concurrent agent wakes.
  void setAgentWakeConcurrency(int value) {
    _userChangedKeys.add(agentWakeConcurrencySettingsKey);
    state = state.copyWith(agentWakeConcurrency: value);
    unawaited(
      _settingsDb.saveSettingsItem(
        agentWakeConcurrencySettingsKey,
        state.agentWakeConcurrency.toString(),
      ),
    );
  }

  /// Updates and persists the wake cadence of task agents whose task and
  /// category set none.
  void setDefaultWakeCadence(AgentWakeCadence cadence) {
    _userChangedKeys.add(defaultAgentWakeCadenceSettingsKey);
    state = state.copyWith(defaultWakeCadence: cadence);
    unawaited(
      _settingsDb.saveSettingsItem(
        defaultAgentWakeCadenceSettingsKey,
        cadence.name,
      ),
    );
  }
}
