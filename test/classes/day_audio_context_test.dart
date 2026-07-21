import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_audio_context.dart';

void main() {
  test('round-trips immutable Daily OS recording provenance', () {
    final context = DayAudioContext(
      dayId: 'dayplan-2026-07-18',
      planDate: DateTime(2026, 7, 18),
      recordingSessionId: 'recording-123',
      activityEntryId: 'activity-123',
      processingJobId: 'transcribe-recording-123',
      capturedAt: DateTime(2026, 7, 18, 7, 42),
      intent: 'dayPlan',
      originHostId: 'host-a',
    );

    final restored = DayAudioContext.fromJson(context.toJson());

    expect(restored, context);
    expect(restored.schemaVersion, 1);
    expect(restored.planDate, DateTime(2026, 7, 18));
  });
}
