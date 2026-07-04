import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/sync/vector_clock.dart';

part 'ai_consumption_event.freezed.dart';
part 'ai_consumption_event.g.dart';

/// One immutable, append-only record of a single backend AI call and what it
/// burned — tokens, money, energy, CO₂, water — tagged with the owner
/// (task/category/entry) and the causal parent call.
///
/// This is the domain model persisted in the separate, Matrix-synced
/// `ai_consumption.sqlite` database. The full entity (including [vectorClock])
/// round-trips through a `serialized` JSON column that is the sync source of
/// truth; a denormalized projection of the queryable fields is written to typed
/// columns purely so aggregation stays fast (see `ConsumptionDbConversions`).
///
/// Rows never mutate after creation: a fresh [id] is minted once, on the device
/// that made the call. Convergence across devices is therefore trivial — a
/// replayed id with an equal vector clock is skipped, and there is no
/// concurrent-merge case.
///
/// Only Melious reports cost/energy/impact; every other provider populates just
/// the token fields and leaves the impact fields null.
@freezed
abstract class AiConsumptionEvent with _$AiConsumptionEvent {
  const factory AiConsumptionEvent({
    /// Globally-unique id (uuid), minted once at capture time.
    required String id,

    /// When the backend call happened.
    required DateTime createdAt,

    /// Which backend provider served the call.
    required InferenceProviderType providerType,

    /// What kind of call this was.
    required AiConsumptionResponseType responseType,

    /// CRDT clock stamped by the sync-aware write path; null until stamped.
    required VectorClock? vectorClock,

    /// The causal parent call/context ("the call that made it"). For agent
    /// turns this is the wake's run key; top-level single calls leave it null.
    String? parentId,

    // ── Denormalized owners (snapshot at call time) ──────────────────────────
    String? taskId,
    String? categoryId,
    String? entryId,
    String? agentId,
    String? wakeRunKey,
    String? threadId,
    int? turnIndex,
    String? promptId,
    String? skillId,
    String? configId,

    // ── Provider / model / timing ────────────────────────────────────────────
    String? modelId,
    String? providerModelId,
    int? durationMs,

    // ── Token metrics ────────────────────────────────────────────────────────
    int? inputTokens,
    int? outputTokens,
    int? cachedInputTokens,
    int? thoughtsTokens,
    int? totalTokens,

    // ── Cost + environmental impact (Melious-only; null elsewhere) ───────────
    /// Billing cost in Melious credits (≈ EUR).
    double? credits,

    /// Energy in kilowatt-hours, as delivered by Melious.
    double? energyKwh,

    /// Carbon in grams of CO₂, as delivered by Melious.
    double? carbonGCo2,

    /// Water in litres, as delivered by Melious.
    double? waterLiters,

    /// Percentage of the serving data centre's energy from renewables (0–100).
    double? renewablePercent,

    /// Power-usage-effectiveness of the serving data centre.
    double? pue,

    /// The serving data-centre location (Melious `location`, e.g. `"FI"`).
    String? dataCenter,

    /// The upstream provider that actually served the call (Melious
    /// `provider_id`).
    String? upstreamProviderId,
  }) = _AiConsumptionEvent;

  factory AiConsumptionEvent.fromJson(Map<String, dynamic> json) =>
      _$AiConsumptionEventFromJson(json);
}
