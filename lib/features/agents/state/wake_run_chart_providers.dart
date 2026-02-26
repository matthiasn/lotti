import 'package:lotti/features/agents/database/agent_database.dart'
    show WakeRunLogData;
import 'package:lotti/features/agents/database/agent_repository.dart'
    show AgentRepository;
import 'package:lotti/features/agents/model/wake_run_time_series.dart';
import 'package:lotti/features/agents/model/wake_run_time_series_utils.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'wake_run_chart_providers.g.dart';

/// Computes time-series chart data for a template's wake runs.
///
/// Fetches raw [WakeRunLogData] via the [AgentRepository] and transforms
/// them into daily and per-version buckets suitable for mini chart rendering.
@riverpod
Future<WakeRunTimeSeries> templateWakeRunTimeSeries(
  Ref ref,
  String templateId,
) async {
  final repository = ref.watch(agentRepositoryProvider);
  final runs = await repository.getWakeRunsForTemplate(templateId);
  return computeTimeSeries(runs);
}
