import 'package:flutter/foundation.dart';

/// Local settings key for the maximum number of agent wakes dispatched at
/// once.
const agentWakeConcurrencySettingsKey = 'AI_AGENT_WAKE_CONCURRENCY';

/// Default number of agent wake cycles that may execute concurrently.
const defaultAgentWakeConcurrency = 3;

/// Smallest supported agent wake concurrency.
const minAgentWakeConcurrency = 1;

/// Largest supported agent wake concurrency.
///
/// The upper bound keeps a malformed or manually edited setting from flooding
/// inference providers and the database with an unbounded number of requests.
const maxAgentWakeConcurrency = 8;

/// Device-local AI runtime settings that affect inference dispatch rather than
/// a particular provider, model, or profile.
@immutable
class AiRuntimeSettings {
  const AiRuntimeSettings({
    this.agentWakeConcurrency = defaultAgentWakeConcurrency,
  });

  /// Restores settings from the value persisted in `SettingsDb`.
  factory AiRuntimeSettings.fromStoredAgentWakeConcurrency(String? raw) {
    final parsed = int.tryParse(raw ?? '');
    return AiRuntimeSettings(
      agentWakeConcurrency: parsed == null
          ? defaultAgentWakeConcurrency
          : normalizeAgentWakeConcurrency(parsed),
    );
  }

  /// Maximum number of different agents whose wake cycles may run at once.
  ///
  /// `WakeRunner` separately keeps each individual agent single-flight.
  final int agentWakeConcurrency;

  /// Clamps [value] to the supported concurrency range.
  static int normalizeAgentWakeConcurrency(int value) => value.clamp(
    minAgentWakeConcurrency,
    maxAgentWakeConcurrency,
  );

  AiRuntimeSettings copyWith({int? agentWakeConcurrency}) {
    return AiRuntimeSettings(
      agentWakeConcurrency: agentWakeConcurrency == null
          ? this.agentWakeConcurrency
          : normalizeAgentWakeConcurrency(agentWakeConcurrency),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiRuntimeSettings &&
      other.agentWakeConcurrency == agentWakeConcurrency;

  @override
  int get hashCode => agentWakeConcurrency.hashCode;
}
