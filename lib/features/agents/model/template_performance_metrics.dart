import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/agents/database/agent_database.dart'
    show WakeRunLogData;

part 'template_performance_metrics.freezed.dart';

/// Aggregated performance metrics for an agent template, computed in-memory
/// from [WakeRunLogData] entries.
@freezed
abstract class TemplatePerformanceMetrics with _$TemplatePerformanceMetrics {
  const factory TemplatePerformanceMetrics({
    required String templateId,
    required int totalWakes,
    required int successCount,
    required int failureCount,
    required double successRate,
    required Duration? averageDuration,
    required DateTime? firstWakeAt,
    required DateTime? lastWakeAt,
    required int activeInstanceCount,
  }) = _TemplatePerformanceMetrics;
}
