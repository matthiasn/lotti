import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  test('work attribution round-trips creator and output identity', () {
    final attribution = AiWorkAttribution(
      id: 'attribution-1',
      workType: AiWorkType.imageGeneration,
      status: AiWorkStatus.succeeded,
      initiator: const AiActorSnapshot(
        type: AiActorType.human,
        id: 'user-1',
        displayName: 'Ada',
      ),
      trigger: const AiTriggerSnapshot(type: AiTriggerType.manual),
      startedAt: DateTime.utc(2026, 7, 19, 10),
      completedAt: DateTime.utc(2026, 7, 19, 10, 0, 2),
      vectorClock: const VectorClock({'host-a': 1}),
      primaryOutput: const AiArtifactReference(
        type: AiArtifactType.journalImage,
        id: 'image-1',
      ),
    );

    final json =
        jsonDecode(jsonEncode(attribution.toJson())) as Map<String, dynamic>;

    expect(AiWorkAttribution.fromJson(json), attribution);
  });

  test('attribution session round-trips its transient work context', () {
    final session = AiAttributionSession(
      id: 'session-1',
      workType: AiWorkType.audioTranscription,
      initiator: const AiActorSnapshot(
        type: AiActorType.human,
        id: 'user-1',
        displayName: 'Ada',
      ),
      trigger: const AiTriggerSnapshot(type: AiTriggerType.manual),
      startedAt: DateTime.utc(2026, 7, 19, 10),
      intendedOutputs: const [
        AiArtifactReference(type: AiArtifactType.journalAudio, id: 'audio-1'),
      ],
      taskId: 'task-1',
      categoryId: 'category-1',
    );
    final json =
        jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>;

    expect(AiAttributionSession.fromJson(json), session);
  });
}
