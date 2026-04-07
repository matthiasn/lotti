import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/services/db_notification.dart';

/// Threshold multiplier: a source is flagged "high usage" if its share exceeds
/// this fraction of an equal split among sources (e.g. 2.5x its "fair share").
const _highUsageMultiplier = 2.5;

/// Shared raw token records for a given day window — single DB query per
/// window size, consumed by the aggregate, per-model, and comparison providers.
final FutureProviderFamily<List<WakeTokenUsageEntity>, int>
_globalTokenRecordsProvider =
    FutureProvider.family<List<WakeTokenUsageEntity>, int>((ref, days) async {
      ref.watch(agentUpdateStreamProvider(agentNotification));

      final repository = ref.watch(agentRepositoryProvider);
      final now = clock.now().toLocal();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final since = todayMidnight.subtract(Duration(days: days - 1));

      return repository.getGlobalTokenUsageSince(since: since);
    });

/// Wake run counts per day for a given day window.
final FutureProviderFamily<Map<DateTime, int>, int> _wakeRunCountsProvider =
    FutureProvider.family<Map<DateTime, int>, int>((
      ref,
      days,
    ) async {
      ref.watch(agentUpdateStreamProvider(agentNotification));

      final repository = ref.watch(agentRepositoryProvider);
      final now = clock.now().toLocal();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final since = todayMidnight.subtract(Duration(days: days - 1));

      final runs = await repository.getWakeRunsInWindow(
        since: since,
        until: now,
      );

      final counts = <DateTime, int>{};
      for (final run in runs) {
        final created = run.createdAt.toLocal();
        final dayKey = DateTime(created.year, created.month, created.day);
        counts[dayKey] = (counts[dayKey] ?? 0) + 1;
      }
      return counts;
    });

/// Provides N days of daily token usage data for the aggregate bar chart.
///
/// Parameter: number of days (e.g. 7 or 30).
final FutureProviderFamily<List<DailyTokenUsage>, int> dailyTokenUsageProvider =
    FutureProvider.family<List<DailyTokenUsage>, int>((ref, days) async {
      final records = await ref.watch(_globalTokenRecordsProvider(days).future);
      final wakeCounts = await ref.watch(_wakeRunCountsProvider(days).future);
      return _buildDailyUsage(records, chartDays: days, wakeCounts: wakeCounts);
    });

/// Per-model daily token usage for individual model charts.
///
/// Returns a map of modelId -> N-day [DailyTokenUsage] list, sorted by
/// total tokens descending (heaviest model first).
final FutureProviderFamily<Map<String, List<DailyTokenUsage>>, int>
dailyTokenUsageByModelProvider =
    FutureProvider.family<Map<String, List<DailyTokenUsage>>, int>((
      ref,
      days,
    ) async {
      final records = await ref.watch(_globalTokenRecordsProvider(days).future);

      final byModel = <String, List<WakeTokenUsageEntity>>{};
      for (final record in records) {
        byModel.putIfAbsent(record.modelId, () => []).add(record);
      }

      final result = <String, List<DailyTokenUsage>>{};
      for (final entry in byModel.entries) {
        result[entry.key] = _buildDailyUsage(entry.value, chartDays: days);
      }

      final sortedEntries = result.entries.toList()
        ..sort((a, b) {
          final totalA = a.value.fold<int>(0, (s, d) => s + d.totalTokens);
          final totalB = b.value.fold<int>(0, (s, d) => s + d.totalTokens);
          return totalB.compareTo(totalA);
        });

      return Map.fromEntries(sortedEntries);
    });

/// Provides the average-vs-today comparison for the summary card.
final FutureProviderFamily<TokenUsageComparison, int>
tokenUsageComparisonProvider = FutureProvider.family<TokenUsageComparison, int>(
  (ref, days) async {
    final dailyUsage = await ref.watch(dailyTokenUsageProvider(days).future);

    final pastDays = dailyUsage.where((d) => !d.isToday).toList();
    final today = dailyUsage.firstWhere(
      (d) => d.isToday,
      orElse: () => DailyTokenUsage(
        date: clock.now(),
        totalTokens: 0,
        tokensByTimeOfDay: 0,
        isToday: true,
      ),
    );

    final averageByTimeOfDay = pastDays.isEmpty
        ? 0
        : pastDays.fold<int>(0, (sum, d) => sum + d.tokensByTimeOfDay) ~/
              pastDays.length;

    return TokenUsageComparison(
      averageTokensByTimeOfDay: averageByTimeOfDay,
      todayTokens: today.totalTokens,
    );
  },
);

/// Provides a per-template breakdown of today's token usage.
///
/// Each entry shows the template name, token count, percentage share,
/// wake count, total wake duration, and a high-usage flag.
final tokenSourceBreakdownProvider = FutureProvider<List<TokenSourceBreakdown>>(
  (ref) async {
    // Derive today's token records from the shared 7-day cache to avoid a
    // duplicate DB query.
    final allRecords = await ref.watch(_globalTokenRecordsProvider(7).future);
    final repository = ref.watch(agentRepositoryProvider);
    final now = clock.now().toLocal();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    final records = allRecords
        .where((r) => !r.createdAt.toLocal().isBefore(todayMidnight))
        .toList();

    final wakeRuns = await repository.getWakeRunsInWindow(
      since: todayMidnight,
      until: now,
    );

    // Group tokens by templateId.
    final tokensByTemplate = <String, int>{};
    for (final record in records) {
      final key = record.templateId ?? record.agentId;
      tokensByTemplate[key] =
          (tokensByTemplate[key] ?? 0) + _recordTotalTokens(record);
    }

    // Group wake runs by templateId for count and duration.
    final wakeCountByTemplate = <String, int>{};
    final durationByTemplate = <String, Duration>{};
    for (final run in wakeRuns) {
      final key = run.templateId ?? run.agentId;
      wakeCountByTemplate[key] = (wakeCountByTemplate[key] ?? 0) + 1;
      if (run.startedAt != null && run.completedAt != null) {
        final duration = run.completedAt!.difference(run.startedAt!);
        durationByTemplate[key] =
            (durationByTemplate[key] ?? Duration.zero) + duration;
      }
    }

    final sourceInfo = await _resolveSourceInfo(repository, {
      ...tokensByTemplate.keys,
      ...wakeCountByTemplate.keys,
    });

    final totalTokens = tokensByTemplate.values.fold<int>(
      0,
      (sum, t) => sum + t,
    );
    final sourceCount = tokensByTemplate.length;

    final breakdowns = <TokenSourceBreakdown>[];
    for (final entry in tokensByTemplate.entries) {
      final percentage = totalTokens > 0
          ? (entry.value / totalTokens) * 100
          : 0.0;
      final fairShare = sourceCount > 0 ? 100.0 / sourceCount : 100.0;
      final info = sourceInfo[entry.key];

      breakdowns.add(
        TokenSourceBreakdown(
          templateId: entry.key,
          displayName: info?.name ?? entry.key,
          totalTokens: entry.value,
          percentage: percentage,
          wakeCount: wakeCountByTemplate[entry.key] ?? 0,
          totalDuration: durationByTemplate[entry.key] ?? Duration.zero,
          isHighUsage: percentage > fairShare * _highUsageMultiplier,
          isTemplate: info?.isTemplate ?? true,
        ),
      );
    }

    breakdowns.sort((a, b) => b.totalTokens.compareTo(a.totalTokens));
    return breakdowns;
  },
);

/// Resolved source info: display name and whether it's a template.
typedef _SourceInfo = ({String name, bool isTemplate});

Future<Map<String, _SourceInfo>> _resolveSourceInfo(
  AgentRepository repository,
  Set<String> ids,
) async {
  final entries = await Future.wait(
    ids.map((id) async {
      try {
        final entity = await repository.getEntity(id);
        final info = switch (entity) {
          AgentTemplateEntity(:final displayName) => (
            name: displayName,
            isTemplate: true,
          ),
          AgentIdentityEntity(:final displayName) => (
            name: displayName,
            isTemplate: false,
          ),
          _ => null,
        };
        return info != null ? MapEntry(id, info) : null;
      } on Exception {
        return null;
      }
    }),
  );
  return Map.fromEntries(entries.nonNulls);
}

/// Builds an N-day [DailyTokenUsage] list from raw token records.
///
/// When [wakeCounts] is provided, each day's [DailyTokenUsage.wakeCount]
/// is populated from it.
List<DailyTokenUsage> _buildDailyUsage(
  List<WakeTokenUsageEntity> records, {
  int chartDays = 7,
  Map<DateTime, int> wakeCounts = const {},
}) {
  final now = clock.now().toLocal();
  final todayMidnight = DateTime(now.year, now.month, now.day);

  final dailyBuckets = <DateTime, _DayBucket>{};
  for (final record in records) {
    final created = record.createdAt.toLocal();
    final dayKey = DateTime(created.year, created.month, created.day);

    final bucket = dailyBuckets.putIfAbsent(dayKey, _DayBucket.new);
    final tokens = _recordTotalTokens(record);
    bucket
      ..totalTokens += tokens
      ..inputTokens += record.inputTokens ?? 0
      ..outputTokens += record.outputTokens ?? 0
      ..thoughtsTokens += record.thoughtsTokens ?? 0
      ..cachedInputTokens += record.cachedInputTokens ?? 0;

    if (created.hour < now.hour ||
        (created.hour == now.hour && created.minute <= now.minute)) {
      bucket.tokensByTimeOfDay += tokens;
    }
  }

  final result = <DailyTokenUsage>[];
  for (var i = chartDays - 1; i >= 0; i--) {
    final day = todayMidnight.subtract(Duration(days: i));
    final isToday = i == 0;
    final bucket = dailyBuckets[day];

    result.add(
      DailyTokenUsage(
        date: day,
        totalTokens: bucket?.totalTokens ?? 0,
        tokensByTimeOfDay: isToday
            ? (bucket?.totalTokens ?? 0)
            : (bucket?.tokensByTimeOfDay ?? 0),
        isToday: isToday,
        inputTokens: bucket?.inputTokens ?? 0,
        outputTokens: bucket?.outputTokens ?? 0,
        thoughtsTokens: bucket?.thoughtsTokens ?? 0,
        cachedInputTokens: bucket?.cachedInputTokens ?? 0,
        wakeCount: wakeCounts[day] ?? 0,
      ),
    );
  }

  return result;
}

/// Total tokens for a single [WakeTokenUsageEntity] record.
int _recordTotalTokens(WakeTokenUsageEntity record) =>
    (record.inputTokens ?? 0) +
    (record.outputTokens ?? 0) +
    (record.thoughtsTokens ?? 0);

/// Mutable helper for accumulating per-day token counts.
class _DayBucket {
  int totalTokens = 0;
  int tokensByTimeOfDay = 0;
  int inputTokens = 0;
  int outputTokens = 0;
  int thoughtsTokens = 0;
  int cachedInputTokens = 0;
}
