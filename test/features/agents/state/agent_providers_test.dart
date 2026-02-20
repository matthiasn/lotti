import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentService mockService;
  late MockAgentRepository mockRepository;

  setUp(() {
    mockService = MockAgentService();
    mockRepository = MockAgentRepository();
  });

  /// Helper to create a [ProviderContainer] with both mocks overridden.
  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        agentServiceProvider.overrideWithValue(mockService),
        agentRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('agentReportProvider', () {
    test('returns report entity when service finds one', () async {
      final report = makeTestReport();

      when(() => mockService.getAgentReport(kTestAgentId))
          .thenAnswer((_) async => report);

      final container = createContainer();
      final result =
          await container.read(agentReportProvider(kTestAgentId).future);

      expect(result, equals(report));
      verify(() => mockService.getAgentReport(kTestAgentId)).called(1);
    });

    test('returns null when service finds no report', () async {
      when(() => mockService.getAgentReport(kTestAgentId))
          .thenAnswer((_) async => null);

      final container = createContainer();
      final result =
          await container.read(agentReportProvider(kTestAgentId).future);

      expect(result, isNull);
      verify(() => mockService.getAgentReport(kTestAgentId)).called(1);
    });
  });

  group('agentStateProvider', () {
    test('returns state entity when repository finds one', () async {
      final state = makeTestState();

      when(() => mockRepository.getAgentState(kTestAgentId))
          .thenAnswer((_) async => state);

      final container = createContainer();
      final result =
          await container.read(agentStateProvider(kTestAgentId).future);

      expect(result, equals(state));
      verify(() => mockRepository.getAgentState(kTestAgentId)).called(1);
    });

    test('returns null when repository finds no state', () async {
      when(() => mockRepository.getAgentState(kTestAgentId))
          .thenAnswer((_) async => null);

      final container = createContainer();
      final result =
          await container.read(agentStateProvider(kTestAgentId).future);

      expect(result, isNull);
      verify(() => mockRepository.getAgentState(kTestAgentId)).called(1);
    });
  });

  group('agentIdentityProvider', () {
    test('returns identity entity when service finds one', () async {
      final identity = makeTestIdentity();

      when(() => mockService.getAgent(kTestAgentId))
          .thenAnswer((_) async => identity);

      final container = createContainer();
      final result =
          await container.read(agentIdentityProvider(kTestAgentId).future);

      expect(result, equals(identity));
      verify(() => mockService.getAgent(kTestAgentId)).called(1);
    });

    test('returns null when service finds no agent', () async {
      when(() => mockService.getAgent(kTestAgentId))
          .thenAnswer((_) async => null);

      final container = createContainer();
      final result =
          await container.read(agentIdentityProvider(kTestAgentId).future);

      expect(result, isNull);
      verify(() => mockService.getAgent(kTestAgentId)).called(1);
    });
  });

  group('agentRecentMessagesProvider', () {
    test('returns messages sorted newest-first', () async {
      final msg1 = makeTestMessage(
        id: 'msg-1',
        createdAt: DateTime(2024, 3, 15, 10),
      );
      final msg2 = makeTestMessage(
        id: 'msg-2',
        createdAt: DateTime(2024, 3, 15, 12),
      );
      final msg3 = makeTestMessage(
        id: 'msg-3',
        createdAt: DateTime(2024, 3, 15, 11),
      );

      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
        ),
      ).thenAnswer((_) async => [msg1, msg2, msg3]);

      final container = createContainer();
      final result = await container
          .read(agentRecentMessagesProvider(kTestAgentId).future);

      expect(result, hasLength(3));
      // Newest first: msg2 (12:00), msg3 (11:00), msg1 (10:00)
      expect((result[0] as AgentMessageEntity).id, 'msg-2');
      expect((result[1] as AgentMessageEntity).id, 'msg-3');
      expect((result[2] as AgentMessageEntity).id, 'msg-1');
    });

    test('caps at 50 entries', () async {
      final messages = List.generate(
        60,
        (i) => makeTestMessage(
          id: 'msg-$i',
          createdAt: DateTime(2024, 3, 15, 0, i),
        ),
      );

      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
        ),
      ).thenAnswer((_) async => messages);

      final container = createContainer();
      final result = await container
          .read(agentRecentMessagesProvider(kTestAgentId).future);

      expect(result, hasLength(50));
      // Newest first: minute 59 should be first
      expect((result[0] as AgentMessageEntity).id, 'msg-59');
    });

    test('returns empty list when no messages exist', () async {
      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
        ),
      ).thenAnswer((_) async => []);

      final container = createContainer();
      final result = await container
          .read(agentRecentMessagesProvider(kTestAgentId).future);

      expect(result, isEmpty);
    });
  });

  group('agentMessagePayloadTextProvider', () {
    test('returns text from payload content', () async {
      const payloadId = 'payload-1';
      final payloadEntity = AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: kTestAgentId,
        createdAt: DateTime(2024, 3, 15),
        vectorClock: null,
        content: const {'text': 'hello world'},
      );

      when(() => mockRepository.getEntity(payloadId))
          .thenAnswer((_) async => payloadEntity);

      final container = createContainer();
      final result = await container
          .read(agentMessagePayloadTextProvider(payloadId).future);

      expect(result, 'hello world');
      verify(() => mockRepository.getEntity(payloadId)).called(1);
    });

    test('returns null when entity is not found', () async {
      const payloadId = 'nonexistent';

      when(() => mockRepository.getEntity(payloadId))
          .thenAnswer((_) async => null);

      final container = createContainer();
      final result = await container
          .read(agentMessagePayloadTextProvider(payloadId).future);

      expect(result, isNull);
    });

    test('returns null when entity is not a payload type', () async {
      const payloadId = 'not-a-payload';
      final identity = makeTestIdentity(id: payloadId);

      when(() => mockRepository.getEntity(payloadId))
          .thenAnswer((_) async => identity);

      final container = createContainer();
      final result = await container
          .read(agentMessagePayloadTextProvider(payloadId).future);

      expect(result, isNull);
    });

    test('returns null when payload text is empty', () async {
      const payloadId = 'payload-empty';
      final payloadEntity = AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: kTestAgentId,
        createdAt: DateTime(2024, 3, 15),
        vectorClock: null,
        content: const {'text': ''},
      );

      when(() => mockRepository.getEntity(payloadId))
          .thenAnswer((_) async => payloadEntity);

      final container = createContainer();
      final result = await container
          .read(agentMessagePayloadTextProvider(payloadId).future);

      expect(result, isNull);
    });

    test('returns null when payload has no text key', () async {
      const payloadId = 'payload-no-text';
      final payloadEntity = AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: kTestAgentId,
        createdAt: DateTime(2024, 3, 15),
        vectorClock: null,
        content: const {'other': 'data'},
      );

      when(() => mockRepository.getEntity(payloadId))
          .thenAnswer((_) async => payloadEntity);

      final container = createContainer();
      final result = await container
          .read(agentMessagePayloadTextProvider(payloadId).future);

      expect(result, isNull);
    });
  });
}
