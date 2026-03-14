import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/logging_service.dart';

const vectorClockLogDomain = 'VECTOR_CLOCK';

String _formatClock(VectorClock? clock) => clock?.vclock.toString() ?? 'null';

String _formatClocks(List<VectorClock>? clocks) =>
    clocks?.map((vc) => vc.vclock).toList().toString() ?? 'null';

void logVectorClockAssignment(
  LoggingService loggingService, {
  required String subDomain,
  required String action,
  String? type,
  String? entryId,
  String? jsonPath,
  String? reason,
  VectorClock? previous,
  VectorClock? assigned,
  List<VectorClock>? coveredVectorClocks,
  Map<String, Object?> extras = const {},
}) {
  final parts = <String>[
    action,
    if (type != null) 'type=$type',
    if (entryId != null) 'entryId=$entryId',
    if (jsonPath != null) 'jsonPath=$jsonPath',
    if (reason != null) 'reason=$reason',
    'previous=${_formatClock(previous)}',
    'assigned=${_formatClock(assigned)}',
    if (coveredVectorClocks != null)
      'covered=${_formatClocks(coveredVectorClocks)}',
    for (final entry in extras.entries)
      if (entry.value != null) '${entry.key}=${entry.value}',
  ];

  loggingService.captureEvent(
    parts.join(' '),
    domain: vectorClockLogDomain,
    subDomain: subDomain,
  );
}
