import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/services/day_activity_repository.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_processing_runtime_provider.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

final StreamProvider<void> dayProcessingOutboxChangesProvider =
    StreamProvider.autoDispose<void>((ref) {
      return ref.watch(dayProcessingOutboxRepositoryProvider).changes;
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
      final summaries = await ref
          .watch(agentRepositoryProvider)
          .getEntitiesByAgentId(
            dailyOsPlannerAgentId,
            type: AgentEntityTypes.daySummary,
          );
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
