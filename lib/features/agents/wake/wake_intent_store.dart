import 'dart:async';
import 'dart:convert';

import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/services/domain_logging.dart';

/// A wake that is owed to an agent: a queued job, or the run it started,
/// that has not settled yet.
class WakeIntent {
  WakeIntent({
    required this.runKey,
    required this.agentId,
    required this.workspaceKey,
    required this.reason,
    required this.initiator,
    required Set<String> tokens,
    this.restores = 0,
  }) : tokens = {...tokens};

  factory WakeIntent.fromJson(Map<String, dynamic> json) => WakeIntent(
    runKey: json['runKey'] as String,
    agentId: json['agentId'] as String,
    workspaceKey: json['workspaceKey'] as String?,
    reason: json['reason'] as String,
    initiator: WakeInitiator.values.byName(json['initiator'] as String),
    tokens: {...(json['tokens'] as List<dynamic>).cast<String>()},
    restores: json['restores'] as int? ?? 0,
  );

  /// The job this intent belongs to.
  final String runKey;
  final String agentId;
  final String? workspaceKey;
  final String reason;
  final WakeInitiator initiator;

  /// Every trigger the job carries, including tokens merged in while queued.
  final Set<String> tokens;

  /// Startups that restored this wake without a run of it settling.
  int restores;

  Map<String, dynamic> toJson() => {
    'runKey': runKey,
    'agentId': agentId,
    'workspaceKey': workspaceKey,
    'reason': reason,
    'initiator': initiator.name,
    'tokens': tokens.toList()..sort(),
    'restores': restores,
  };
}

/// Durable, device-local record of the wakes still owed to agents, so a
/// process death cannot lose one (`specs/tla/WakeRuntime.tla`,
/// `NoLostWake`).
///
/// One intent per queued job, keyed by its run key: recorded when the queue
/// accepts the job, grown by the tokens merged into it while it waits, and
/// settled — forgotten — once its run settles or the job is dropped for good.
/// Tokens merge only into jobs still queued, so a run covers exactly its own
/// job's intent; a trigger that arrives meanwhile belongs to another job.
/// Whatever is still recorded at startup — jobs the crash lost, runs it
/// interrupted — is restored once per boot.
///
/// Stored as one JSON list in [SettingsDb], which is device-local like the
/// throttle deadline. Writes are coalesced: a burst of triggers costs one or
/// two writes, not one per trigger.
class WakeIntentStore {
  WakeIntentStore({
    required this._settingsDb,
    this._domainLogger,
  });

  static const settingsKey = 'AGENT_WAKE_INTENTS';

  /// Startups a wake may be restored on without a run of it settling. A wake
  /// that kills the process every time it runs is dropped after this many,
  /// instead of crashing every future launch.
  static const maxRestores = 2;

  final SettingsDb _settingsDb;
  final DomainLogger? _domainLogger;
  final _intents = <String, WakeIntent>{};

  /// Run keys loaded at startup and not yet restored. Only these are owed
  /// by a previous process; what this one recorded since is its own work.
  final _loaded = <String>{};

  /// The one read of the persisted intents; every write waits for it, so a
  /// write can never replace what is on disk with a partial snapshot.
  Future<void>? _loading;

  /// Run keys settled before [_loading] completed, which the disk copy must
  /// not bring back.
  final _settledBeforeLoad = <String>{};
  var _isLoaded = false;
  Future<void>? _writing;
  var _dirty = false;

  /// Loads the persisted intents, once: a second call — a restarted
  /// orchestrator, a re-run initialization — waits for the same read and
  /// changes nothing. They are merged into what this store already holds, so
  /// a job recorded while the read ran is kept; a job this process holds is
  /// live here, and is not restorable.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final raw = await _settingsDb.itemByKey(settingsKey);
      if (raw == null || raw.isEmpty) return;
      for (final item in jsonDecode(raw) as List<dynamic>) {
        try {
          _merge(WakeIntent.fromJson(item as Map<String, dynamic>));
        } catch (error, stackTrace) {
          _logError('unreadable wake intent skipped', error, stackTrace);
        }
      }
    } catch (error, stackTrace) {
      _logError('unreadable wake intents skipped', error, stackTrace);
    } finally {
      _isLoaded = true;
      _settledBeforeLoad.clear();
    }
  }

  void _merge(WakeIntent persisted) {
    final runKey = persisted.runKey;
    if (_settledBeforeLoad.contains(runKey)) return;
    final live = _intents[runKey];
    if (live == null) {
      _intents[runKey] = persisted;
      _loaded.add(runKey);
      return;
    }
    live.tokens.addAll(persisted.tokens);
    if (live.restores < persisted.restores) live.restores = persisted.restores;
  }

  /// Records that the job [runKey] for [agentId] carries [tokens]: a job the
  /// queue accepted, or tokens merged into it while it waits.
  void record({
    required String runKey,
    required String agentId,
    required String? workspaceKey,
    required String reason,
    required WakeInitiator initiator,
    required Set<String> tokens,
  }) {
    _intents
        .putIfAbsent(
          runKey,
          () => WakeIntent(
            runKey: runKey,
            agentId: agentId,
            workspaceKey: workspaceKey,
            reason: reason,
            initiator: initiator,
            tokens: const {},
          ),
        )
        .tokens
        .addAll(tokens);
    _persistSoon();
  }

  /// Whether a wake of [agentId] in [workspaceKey] carrying every one of
  /// [tokens] is still owed: a job queued or running in this process, or one
  /// a previous process left for startup to restore. Waits for the load, so a
  /// restorable intent is never missed.
  Future<bool> owes({
    required String agentId,
    required String? workspaceKey,
    required Set<String> tokens,
  }) async {
    await load();
    return _intents.values.any(
      (intent) =>
          intent.agentId == agentId &&
          intent.workspaceKey == workspaceKey &&
          intent.tokens.containsAll(tokens),
    );
  }

  /// Forgets the intent of job [runKey]: its run settled, or the job was
  /// dropped for good.
  void settle(String runKey) {
    if (!_isLoaded) _settledBeforeLoad.add(runKey);
    if (_intents.remove(runKey) != null) _persistSoon();
  }

  /// Startup: the intents a previous process left unsettled, each counted as
  /// one more restore — once per [load]. Intents this process recorded are
  /// not among them: their jobs are queued or running here already. Intents
  /// restored [maxRestores] times without settling are dropped.
  List<WakeIntent> takeRestorable() {
    final restorable = <WakeIntent>[];
    final loaded = _loaded.toList();
    _loaded.clear();
    for (final runKey in loaded) {
      final intent = _intents[runKey];
      if (intent == null) continue; // settled since startup
      if (intent.restores >= maxRestores) {
        _intents.remove(runKey);
        _logError(
          'wake intent dropped after ${intent.restores} restores without a '
          'settled run (agent ${DomainLogger.sanitizeId(intent.agentId)})',
          StateError('wake intent not settled'),
          StackTrace.current,
        );
        continue;
      }
      intent.restores++;
      restorable.add(intent);
    }
    _persistSoon();
    return restorable;
  }

  /// A restored [intent] now lives on as job [runKey] — a new job, or a
  /// queued one its tokens merged into. Its restore count moves along, so
  /// the poison guard still counts the startups it has been through.
  void adopt(WakeIntent intent, {required String runKey}) {
    if (intent.runKey == runKey) return;
    final target = _intents[runKey];
    if (target != null && target.restores < intent.restores) {
      target.restores = intent.restores;
    }
    _intents.remove(intent.runKey);
    _persistSoon();
  }

  /// Completes once every write requested so far has been attempted.
  Future<void> flush() async {
    while (_writing != null) {
      await _writing;
    }
  }

  void _persistSoon() {
    _dirty = true;
    // Cleared in `whenComplete`, which always runs after this assignment: the
    // loop itself can finish synchronously when a write throws before its
    // first suspension.
    _writing ??= _writeLoop().whenComplete(() => _writing = null);
  }

  Future<void> _writeLoop() async {
    await load();
    while (_dirty) {
      _dirty = false;
      final snapshot = [
        for (final intent in _intents.values) intent.toJson(),
      ];
      try {
        if (snapshot.isEmpty) {
          await _settingsDb.removeSettingsItem(settingsKey);
        } else {
          await _settingsDb.saveSettingsItem(
            settingsKey,
            jsonEncode(snapshot),
          );
        }
      } catch (error, stackTrace) {
        _logError('failed to persist wake intents', error, stackTrace);
      }
    }
  }

  void _logError(String message, Object error, StackTrace stackTrace) {
    _domainLogger?.error(
      LogDomain.agentRuntime,
      error,
      message: message,
      stackTrace: stackTrace,
      subDomain: 'wake.intents',
    );
  }
}
