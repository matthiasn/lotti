import 'dart:io';

import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_keys.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:uuid/uuid.dart';

const _localAiPrincipalIdSettingsKey = 'aiAttributionLocalPrincipalId';

/// Resolves stable actor and executor snapshots at the start of an AI run.
class AiAttributionIdentityResolver {
  factory AiAttributionIdentityResolver(
    SettingsDb settingsDb,
    VectorClockService vectorClockService, {
    String? Function()? matrixUserId,
    Uuid uuid = const Uuid(),
  }) => AiAttributionIdentityResolver._(
    settingsDb,
    vectorClockService,
    matrixUserId,
    uuid,
  );

  AiAttributionIdentityResolver._(
    this._settingsDb,
    this._vectorClockService,
    this._matrixUserId,
    this._uuid,
  );

  final SettingsDb _settingsDb;
  final VectorClockService _vectorClockService;
  final String? Function()? _matrixUserId;
  final Uuid _uuid;
  Future<String>? _localPrincipalId;

  Future<AiActorSnapshot> humanInitiator() async {
    final displayName =
        (await _settingsDb.itemByKey(dailyOsUserNameSettingsKey))?.trim() ?? '';
    final matrixUserId = _matrixUserId?.call()?.trim();
    final principalId = matrixUserId != null && matrixUserId.isNotEmpty
        ? 'matrix:$matrixUserId'
        : await (_localPrincipalId ??= _loadOrCreateLocalPrincipalId());
    return AiActorSnapshot(
      type: AiActorType.human,
      id: principalId,
      displayName: displayName,
      humanPrincipalId: principalId,
    );
  }

  Future<String> _loadOrCreateLocalPrincipalId() async {
    final stored = (await _settingsDb.itemByKey(
      _localAiPrincipalIdSettingsKey,
    ))?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    final created = 'local:${_uuid.v4()}';
    await _settingsDb.saveSettingsItem(
      _localAiPrincipalIdSettingsKey,
      created,
    );
    return created;
  }

  Future<AiExecutorSnapshot> executor() async {
    final hostId = await _vectorClockService.getHost();
    return AiExecutorSnapshot(
      hostId: hostId ?? 'unknown-host',
      displayName: Platform.localHostname,
    );
  }
}
