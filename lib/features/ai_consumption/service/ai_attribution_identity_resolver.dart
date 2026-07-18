import 'dart:io';

import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_keys.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// Resolves stable actor and executor snapshots at the start of an AI run.
class AiAttributionIdentityResolver {
  const AiAttributionIdentityResolver(
    this._settingsDb,
    this._vectorClockService,
  );

  final SettingsDb _settingsDb;
  final VectorClockService _vectorClockService;

  Future<AiActorSnapshot> humanInitiator() async {
    final displayName =
        (await _settingsDb.itemByKey(dailyOsUserNameSettingsKey))?.trim() ?? '';
    return AiActorSnapshot(
      type: AiActorType.human,
      id: 'human:owner',
      displayName: displayName,
      humanPrincipalId: 'human:owner',
    );
  }

  Future<AiExecutorSnapshot> executor() async {
    final hostId = await _vectorClockService.getHost();
    return AiExecutorSnapshot(
      hostId: hostId ?? 'unknown-host',
      displayName: Platform.localHostname,
    );
  }
}
