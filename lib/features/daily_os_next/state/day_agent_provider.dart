import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/logic/real_day_agent.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';

/// Resolves the [DayAgentInterface] the UI talks to.
///
/// Returns a [RealDayAgent] that delegates seven methods to the real
/// agent layer: the capture/reconcile tools
/// (`submitCapture`, `parseCaptureToItems`, `surfacePendingDecisions`,
/// `applyTriage`, `linkCapturePhraseToTask`, `breakCaptureLink`), day-plan
/// drafting/refinement/commit calls, and plan summary reads. Shutdown and task
/// corpus methods still delegate to a held [MockDayAgent] fallback until their
/// backend tools ship.
///
/// Tests override this provider with their own implementation via
/// `ProviderScope(overrides: [...])` (typically with a fresh
/// [MockDayAgent] so they stay deterministic + don't touch the
/// agent layer).
final dayAgentProvider = Provider<DayAgentInterface>((ref) {
  return RealDayAgent(
    captureService: ref.watch(dayAgentCaptureServiceProvider),
    planService: ref.watch(dayAgentPlanServiceProvider),
    dayAgentService: ref.watch(dayAgentServiceProvider),
    journalDb: ref.watch(journalDbProvider),
    mockFallback: MockDayAgent(),
  );
});

/// Currently persisted `DraftPlan` for the given date, if any. Re-runs
/// whenever the underlying day-agent emits an update (parsed items,
/// drafted plan, etc.) so the routing layer flips from Capture → Day
/// the instant the wake completes.
// ignore: specify_nonobvious_property_types
final currentDraftPlanProvider = FutureProvider.autoDispose
    .family<DraftPlan?, DateTime>((ref, date) async {
      final agent = ref.watch(dayAgentProvider);
      // Re-runs whenever entities under this day-agent change. The broad
      // agent sentinel covers sync-originated agent entity updates, which
      // currently notify by agent id rather than by the derived day id.
      ref
        ..watch(agentUpdateStreamProvider(dayAgentIdForDate(date)))
        ..watch(agentUpdateStreamProvider(agentNotification));
      return agent.currentPlanForDate(date);
    });

/// One row in the Captures panel — a persisted capture paired with the
/// `JournalAudio` it references (if any). Audio may be `null` when the
/// capture was typed instead of spoken or when the journal entry has
/// been deleted out from under the capture.
@immutable
class CaptureWithAudio {
  const CaptureWithAudio({required this.capture, this.audio});

  final CaptureEntity capture;
  final JournalAudio? audio;
}

/// Captures persisted under the day-agent for the given date, newest
/// first. Each entry is paired with the linked `JournalAudio` so the
/// UI can drop the existing `AudioPlayerWidget` straight in.
// ignore: specify_nonobvious_property_types
final capturesForDateProvider = FutureProvider.autoDispose
    .family<List<CaptureWithAudio>, DateTime>((ref, date) async {
      final dayAgentService = ref.watch(dayAgentServiceProvider);
      final journalDb = ref.watch(journalDbProvider);
      final agentRepository = ref.watch(agentRepositoryProvider);
      ref
        ..watch(agentUpdateStreamProvider(dayAgentIdForDate(date)))
        ..watch(agentUpdateStreamProvider(agentNotification));

      final agent = await dayAgentService.getDayAgentForDate(date);
      if (agent == null) return const <CaptureWithAudio>[];
      final rows = await agentRepository.getEntitiesByAgentId(
        agent.agentId,
        type: AgentEntityTypes.capture,
      );
      final captures = rows
          .whereType<CaptureEntity>()
          .where((c) => c.deletedAt == null)
          .toList();
      final out = <CaptureWithAudio>[];
      for (final capture in captures) {
        JournalAudio? audio;
        final audioRef = capture.audioRef;
        if (audioRef != null && audioRef.isNotEmpty) {
          final entity = await journalDb.journalEntityById(audioRef);
          if (entity is JournalAudio && entity.meta.deletedAt == null) {
            audio = entity;
          }
        }
        out.add(CaptureWithAudio(capture: capture, audio: audio));
      }
      return out;
    });
