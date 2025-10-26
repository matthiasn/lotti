import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/labels/services/label_assignment_event_service.dart';
import 'package:lotti/get_it.dart';

final labelAssignmentEventServiceProvider =
    Provider<LabelAssignmentEventService>((ref) {
  return getIt<LabelAssignmentEventService>();
});

final labelAssignmentEventsProvider =
    StreamProvider<LabelAssignmentEvent>((ref) {
  final svc = ref.watch(labelAssignmentEventServiceProvider);
  return svc.stream;
});
