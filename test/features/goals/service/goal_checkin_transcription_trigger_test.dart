import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/goals/service/goal_checkin_transcription_trigger.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  late MockAgentService agents;
  late List<String> transcribed;
  late List<String> declined;

  GoalCheckInTranscriptionTrigger build() => GoalCheckInTranscriptionTrigger(
    agentService: agents,
    runTranscription: (entryId) async => transcribed.add(entryId),
    recordDecline: (entryId, reason) async => declined.add('$entryId: $reason'),
  );

  setUp(() {
    agents = MockAgentService();
    transcribed = <String>[];
    declined = <String>[];
  });

  test(
    'a check-in recording is transcribed for a goal with updates on',
    () async {
      when(() => agents.getAgent('goal-agent')).thenAnswer(
        (_) async => makeTestIdentity(
          agentId: 'goal-agent',
          kind: 'goal_agent',
          config: const AgentConfig(automaticUpdatesEnabled: true),
        ),
      );

      expect(
        await build().transcribe(agentId: 'goal-agent', entryId: 'checkin-1'),
        isTrue,
      );
      // The whole point: the recording enters the shared transcription pipeline
      // rather than sitting on the timeline as permanently pending.
      expect(transcribed, ['checkin-1']);
    },
  );

  test('a goal created before the switch existed still transcribes', () async {
    // Legacy goal agents carry no explicit value and shipped with automatic
    // updates ON — reading null as off would silently stop transcribing every
    // check-in on goals created before the switch was added.
    when(() => agents.getAgent('legacy-goal')).thenAnswer(
      (_) async => makeTestIdentity(
        agentId: 'legacy-goal',
        kind: 'goal_agent',
      ),
    );

    expect(
      await build().transcribe(agentId: 'legacy-goal', entryId: 'checkin-2'),
      isTrue,
    );
    expect(transcribed, ['checkin-2']);
  });

  test('automatic updates switched off spends nothing', () async {
    when(() => agents.getAgent('quiet-goal')).thenAnswer(
      (_) async => makeTestIdentity(
        agentId: 'quiet-goal',
        kind: 'goal_agent',
        config: const AgentConfig(automaticUpdatesEnabled: false),
      ),
    );

    expect(
      await build().transcribe(agentId: 'quiet-goal', entryId: 'checkin-3'),
      isFalse,
    );
    expect(transcribed, isEmpty);
    // Not silently: an unrecorded skip is indistinguishable from a recording
    // still being transcribed, so the beat would claim progress forever and
    // never offer the Retry that transcribes it by hand.
    expect(declined, [
      'checkin-3: automatic updates are off for goal quiet-goal',
    ]);
  });

  test('an unknown agent transcribes nothing', () async {
    when(() => agents.getAgent('ghost')).thenAnswer((_) async => null);

    expect(
      await build().transcribe(agentId: 'ghost', entryId: 'checkin-4'),
      isFalse,
    );
    expect(transcribed, isEmpty);
    expect(declined, ['checkin-4: no goal agent ghost']);
  });

  test('a failing transcription never reaches the recorder', () async {
    when(() => agents.getAgent('goal-agent')).thenAnswer(
      (_) async => makeTestIdentity(
        agentId: 'goal-agent',
        kind: 'goal_agent',
        config: const AgentConfig(automaticUpdatesEnabled: true),
      ),
    );
    final trigger = GoalCheckInTranscriptionTrigger(
      agentService: agents,
      runTranscription: (_) async => throw StateError('inference is down'),
      recordDecline: (entryId, reason) async => declined.add(entryId),
    );

    // Contained, not propagated: the recording is already saved, and losing
    // its transcript must not turn into an error the user sees on capture.
    expect(
      await trigger.transcribe(agentId: 'goal-agent', entryId: 'checkin-5'),
      isFalse,
    );
  });
}
