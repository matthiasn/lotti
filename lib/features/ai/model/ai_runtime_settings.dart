import 'package:flutter/foundation.dart';
import 'package:lotti/classes/agent_wake_cadence.dart';

/// Local settings key for the maximum number of agent wakes dispatched at
/// once.
const agentWakeConcurrencySettingsKey = 'AI_AGENT_WAKE_CONCURRENCY';

/// Local settings key for the wake cadence of task agents whose task and
/// category leave it unset.
const defaultAgentWakeCadenceSettingsKey = 'AI_DEFAULT_AGENT_WAKE_CADENCE';

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
    this.defaultWakeCadence = defaultAgentWakeCadence,
  });

  /// Restores settings from the values persisted in `SettingsDb`. A missing or
  /// malformed value falls back to its default.
  factory AiRuntimeSettings.fromStored({
    String? agentWakeConcurrency,
    String? defaultWakeCadence,
  }) {
    final parsed = int.tryParse(agentWakeConcurrency ?? '');
    return AiRuntimeSettings(
      agentWakeConcurrency: parsed == null
          ? defaultAgentWakeConcurrency
          : normalizeAgentWakeConcurrency(parsed),
      defaultWakeCadence:
          AgentWakeCadence.fromName(defaultWakeCadence) ??
          defaultAgentWakeCadence,
    );
  }

  /// Maximum number of different agents whose wake cycles may run at once.
  ///
  /// `WakeRunner` separately keeps each individual agent single-flight.
  final int agentWakeConcurrency;

  /// The wake cadence of a task agent whose task and category set none.
  ///
  /// Device-local, like the rest of these settings: each device may pace its
  /// own wakes. Only reaches agents whose automatic updates are on.
  final AgentWakeCadence defaultWakeCadence;

  /// Clamps [value] to the supported concurrency range.
  static int normalizeAgentWakeConcurrency(int value) => value.clamp(
    minAgentWakeConcurrency,
    maxAgentWakeConcurrency,
  );

  AiRuntimeSettings copyWith({
    int? agentWakeConcurrency,
    AgentWakeCadence? defaultWakeCadence,
  }) {
    return AiRuntimeSettings(
      agentWakeConcurrency: agentWakeConcurrency == null
          ? this.agentWakeConcurrency
          : normalizeAgentWakeConcurrency(agentWakeConcurrency),
      defaultWakeCadence: defaultWakeCadence ?? this.defaultWakeCadence,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiRuntimeSettings &&
      other.agentWakeConcurrency == agentWakeConcurrency &&
      other.defaultWakeCadence == defaultWakeCadence;

  @override
  int get hashCode => Object.hash(agentWakeConcurrency, defaultWakeCadence);
}
