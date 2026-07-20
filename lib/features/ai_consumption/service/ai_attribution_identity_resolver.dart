import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_keys.dart';
import 'package:uuid/uuid.dart';

const _localAiPrincipalIdSettingsKey = 'aiAttributionLocalPrincipalId';

/// Resolves stable creator snapshots at the start of an AI run.
class AiAttributionIdentityResolver {
  factory AiAttributionIdentityResolver(
    SettingsDb settingsDb, {
    String? Function()? matrixUserId,
    Uuid uuid = const Uuid(),
  }) => AiAttributionIdentityResolver._(
    settingsDb,
    matrixUserId,
    uuid,
  );

  AiAttributionIdentityResolver._(
    this._settingsDb,
    this._matrixUserId,
    this._uuid,
  );

  final SettingsDb _settingsDb;
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

  /// Resolves a stable automation actor while retaining the accountable human
  /// principal for installations that have one.
  Future<AiActorSnapshot> automationInitiator({
    required String id,
    required String displayName,
  }) async {
    final human = await humanInitiator();
    return AiActorSnapshot(
      type: AiActorType.automation,
      id: id,
      displayName: displayName,
      humanPrincipalId: human.humanPrincipalId,
    );
  }

  /// Resolves an agent actor with the human principal that owns the run.
  Future<AiActorSnapshot> agentInitiator({
    required String id,
    required String displayName,
  }) async {
    final human = await humanInitiator();
    return AiActorSnapshot(
      type: AiActorType.agent,
      id: id,
      displayName: displayName,
      humanPrincipalId: human.humanPrincipalId,
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
}
