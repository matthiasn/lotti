import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/services/day_activity_repository.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_processing_runtime_provider.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

/// Emits a strictly increasing tick per outbox mutation.
///
/// The repository's `changes` is a `Stream<void>`, and Riverpod deduplicates
/// `AsyncData` values with `==` — `AsyncData<void>(null)` equals itself, so
/// watching the raw stream would only ever notify on the FIRST event and the
/// Activity timeline would never refresh on later job-state changes (retry,
/// backoff, waitingForNetwork, failure). Mapping to a counter makes every
/// emission identity-distinct (same trick as `agentUpdateStreamProvider`).
final StreamProvider<int> dayProcessingOutboxChangesProvider =
    StreamProvider.autoDispose<int>((ref) {
      var tick = 0;
      return ref
          .watch(dayProcessingOutboxRepositoryProvider)
          .changes
          .map((_) => ++tick);
    });

/// Offline-first activity rows for one local calendar day.
// ignore: specify_nonobvious_property_types
final dayActivityProvider = FutureProvider.autoDispose
    .family<List<DayActivityEntry>, DateTime>((ref, date) async {
      ref
        ..watch(dayProcessingOutboxChangesProvider)
        ..watch(agentUpdateStreamProvider(audioNotification));
      final captures = await ref.watch(capturesForDateProvider(date).future);
      final planEntity = await ref.watch(
        draftedPlanForDateProvider(date).future,
      );
      // Summary ids are deterministic per day, so resolve by id instead of by
      // writing agent — the writer changes across the ADR 0032 cutover
      // (coordinator pre-cutover, per-day agent after) while the id does not.
      final summaryEntities = await ref
          .watch(agentRepositoryProvider)
          .getEntitiesByIds([dayAgentSummaryEntityId(dayAgentIdForDate(date))]);
      final summaries = summaryEntities.values
          .whereType<DaySummaryEntity>()
          .where((s) => s.deletedAt == null && isDailyOsDayOwner(s.agentId));
      return DayActivityRepository(
        journalDb: getIt(),
        outbox: ref.watch(dayProcessingOutboxRepositoryProvider),
        assetRoot: getIt<Directory>(),
      ).load(
        dayId: dayAgentIdForDate(date),
        captures: <CaptureEntity>[
          for (final item in captures) item.capture,
        ],
        summaries: summaries.whereType<DaySummaryEntity>(),
        plan: planEntity is DayPlanEntity ? planEntity : null,
      );
    });
