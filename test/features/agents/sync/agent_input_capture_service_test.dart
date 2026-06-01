import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/projection/input_frontier.dart';
import 'package:lotti/features/agents/sync/agent_input_capture_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_data/entity_factories.dart';
import 'in_memory_agent_repository.dart';

const _agentId = 'agent-1';

void main() {
  setUpAll(registerAllFallbackValues);

  late InMemoryAgentRepository repo;
  late AgentInputCaptureService capture;

  setUp(() {
    repo = InMemoryAgentRepository()..seed([makeTestState(agentId: _agentId)]);
    final vc = MockVectorClockService();
    var counter = 0;
    when(
      () => vc.getNextVectorClock(previous: any(named: 'previous')),
    ).thenAnswer((_) async => VectorClock({'h1': ++counter}));
    final outbox = MockOutboxService();
    when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
    final sync = AgentSyncService(
      repository: repo,
      outboxService: outbox,
      vectorClockService: vc,
    );
    capture = AgentInputCaptureService(syncService: sync);
  });

  RenderedSource source(String entryId, String text, {int day = 1}) =>
      RenderedSource(
        contentEntryId: entryId,
        sourceCreatedAt: DateTime.utc(2024, 3, day),
        content: {'text': text},
      );

  Map<String, String> frontierNow() => inputFrontierDigests(
    projectInputFrontier(messages: repo.messages, links: repo.links),
  );

  Future<CaptureDelta> captureSourcesAt(
    List<RenderedSource> sources,
    int captureDay,
  ) => capture.captureWakeInputs(
    agentId: _agentId,
    sources: sources,
    at: DateTime.utc(2024, 3, captureDay),
  );

  test(
    'captures new sources as content-addressed payloads + agent links',
    () async {
      final delta = await captureSourcesAt([
        source('e1', 'alpha'),
        source('e2', 'beta'),
      ], 10);

      expect(delta.newReferences, hasLength(2));
      expect(repo.payloads, hasLength(2));
      expect(repo.payloadLinks, hasLength(2));
      expect(repo.payloadLinks.every((l) => l.fromId == _agentId), isTrue);
      // The payload id is its content digest.
      expect(
        repo.payloads.map((p) => p.id).toSet(),
        {
          ContentDigest.of({'text': 'alpha'}),
          ContentDigest.of({'text': 'beta'}),
        },
      );
      expect(frontierNow(), {
        'e1': ContentDigest.of({'text': 'alpha'}),
        'e2': ContentDigest.of({'text': 'beta'}),
      });
    },
  );

  test('re-capturing identical sources writes nothing', () async {
    final sources = [source('e1', 'alpha')];
    await captureSourcesAt(sources, 10);
    final payloadsBefore = repo.payloads.length;
    final linksBefore = repo.links.length;

    final delta = await captureSourcesAt(sources, 11);

    expect(delta.isEmpty, isTrue);
    expect(repo.payloads, hasLength(payloadsBefore));
    expect(repo.links, hasLength(linksBefore));
  });

  test(
    'an edited source captures a new version and advances the frontier',
    () async {
      await captureSourcesAt([source('e1', 'v1')], 10);
      final delta = await captureSourcesAt([source('e1', 'v2')], 11);

      expect(delta.newReferences, hasLength(1));
      expect(repo.payloads, hasLength(2)); // both versions retained
      expect(frontierNow()['e1'], ContentDigest.of({'text': 'v2'}));
    },
  );

  test(
    'shares one payload across identical content from distinct sources',
    () async {
      await captureSourcesAt([
        source('e1', 'same'),
        source('e2', 'same'),
      ], 10);

      expect(repo.payloads, hasLength(1));
      expect(repo.payloadLinks, hasLength(2));
    },
  );

  test(
    'a removed source is retracted from the frontier but kept in the log',
    () async {
      await captureSourcesAt([source('e1', 'alpha'), source('e2', 'beta')], 10);

      final delta = await captureSourcesAt([source('e1', 'alpha')], 11);

      expect(delta.retractedEntryIds, ['e2']);
      // The retraction is an auditable system message; the e2 capture link stays.
      expect(
        repo.messages.where((m) => m.metadata.retractsContentEntryId == 'e2'),
        hasLength(1),
      );
      expect(repo.payloadLinks, hasLength(2));
      expect(frontierNow().keys, ['e1']);
    },
  );

  test(
    're-adding a retracted source restores it via a later capture',
    () async {
      await captureSourcesAt([source('e1', 'alpha')], 10);
      await captureSourcesAt(const [], 11); // retracts e1
      expect(frontierNow(), isEmpty);

      final delta = await captureSourcesAt([source('e1', 'alpha')], 12);

      expect(delta.newReferences, hasLength(1));
      expect(frontierNow().keys, ['e1']);
    },
  );
}
