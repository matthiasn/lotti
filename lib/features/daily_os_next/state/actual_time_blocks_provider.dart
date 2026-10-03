import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/logic/actual_time_blocks.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/recorded_time.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/signals/health_signal_refresh_service.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/date_utils_extension.dart';

/// Emits whenever recorded ("actual") time entries change, so the actual-time
/// blocks for the day can be recomputed. Bridges the global update-notification
/// stream into Riverpod, dropping empty batches via [actualTimelineUpdateBatches].
// ignore: specify_nonobvious_property_types
final dailyOsActualTimeUpdateProvider = StreamProvider.autoDispose<Set<String>>(
  (ref) {
    final notifications = ref.watch(maybeUpdateNotificationsProvider);
    if (notifications == null) return const Stream<Set<String>>.empty();
    return actualTimelineUpdateBatches(notifications.updateStream);
  },
);

@visibleForTesting
Stream<Set<String>> actualTimelineUpdateBatches(Stream<Set<String>> updates) {
  return updates.where((affectedIds) => affectedIds.isNotEmpty);
}

/// The recorded ("actual") [TimeBlock]s for a given local day, projected from
/// journal entries that overlap that day. Re-runs whenever
/// [dailyOsActualTimeUpdateProvider] signals a change; the heavy lifting
/// (tombstone/zero-length filtering, linked-from resolution) lives in
/// [actualTimeBlocksForEntries] via the shared `resolveTimeEntries` core.
///
/// An event whose span sits inside the day is recorded time too — the user
/// set its start and end on the event page — and lands on the lane as a
/// calendar block whose state follows the event's status
/// ([eventBlockState]). Because events are hidden everywhere while the
/// Events feature is off, the projection watches that flag and re-runs when
/// it flips.
///
/// Workouts are recorded time too, but they reach the journal only through the
/// health import, and nothing on this surface used to ask for one — a walk
/// appeared on the timeline only after some dashboard with a workout chart had
/// been opened. Each recompute therefore nudges the workout delta, fire and
/// forget: the importer throttles it, and the journal write it produces comes
/// back through [dailyOsActualTimeUpdateProvider] to repaint the lane.
// ignore: specify_nonobvious_property_types
final dailyOsActualTimeBlocksProvider = FutureProvider.autoDispose
    .family<List<TimeBlock>, DateTime>((ref, date) async {
      ref.watch(dailyOsActualTimeUpdateProvider);
      final eventsEnabled = ref.watch(
        configFlagProvider(enableEventsFlag).future,
      );
      unawaited(
        ref.read(healthSignalRefreshServiceProvider)?.refreshWorkouts(),
      );
      final dayStart = date.dayAtMidnight;
      final inputs = await loadRecordedTimeInputs(
        ref.watch(journalDbProvider),
        rangeStart: dayStart,
        rangeEnd: dayStart.add(const Duration(days: 1)),
      );
      return actualTimeBlocksForEntries(
        entries: inputs.entries,
        links: inputs.links,
        linkedFromById: inputs.linkedFromById,
        categoryById: cachedCategoryById,
        eventsEnabled: await eventsEnabled,
      );
    });

/// The category with [id] from the entities cache, or null before the cache
/// is registered (tests, early boot).
CategoryDefinition? cachedCategoryById(String id) {
  if (!getIt.isRegistered<EntitiesCacheService>()) return null;
  return getIt<EntitiesCacheService>().getCategoryById(id);
}
