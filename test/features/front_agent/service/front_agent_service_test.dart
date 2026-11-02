import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/service/front_agent_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentService agentService;
  late MockAgentSyncService syncService;
  late FrontAgentService service;

  final existing = makeTestIdentity(
    id: frontAgentId,
    agentId: frontAgentId,
    kind: AgentKinds.frontAgent,
  );

  setUp(() {
    agentService = MockAgentService();
    syncService = MockAgentSyncService();
    service = FrontAgentService(
      agentService: agentService,
      syncService: syncService,
    );
  });

  test('returns the existing front agent without creating one', () async {
    when(
      () => agentService.getAgent(frontAgentId),
    ).thenAnswer((_) async => existing);

    final identity = await service.getOrCreate();

    expect(identity, same(existing));
    verifyNever(
      () => agentService.createAgent(
        kind: any(named: 'kind'),
        displayName: any(named: 'displayName'),
        config: any(named: 'config'),
        allowedCategoryIds: any(named: 'allowedCategoryIds'),
        agentId: any(named: 'agentId'),
      ),
    );
  });

  test('creates the one front agent under its fixed id and allow-list, '
      'inside a transaction', () async {
    when(
      () => agentService.getAgent(frontAgentId),
    ).thenAnswer((_) async => null);
    when(
      () => agentService.createAgent(
        kind: any(named: 'kind'),
        displayName: any(named: 'displayName'),
        config: any(named: 'config'),
        allowedCategoryIds: any(named: 'allowedCategoryIds'),
        agentId: any(named: 'agentId'),
      ),
    ).thenAnswer((_) async => existing);
    var inTransaction = false;
    var createdInside = false;
    syncService.transactionDelegate = <T>(action) async {
      inTransaction = true;
      try {
        return await action();
      } finally {
        inTransaction = false;
      }
    };
    when(
      () => agentService.createAgent(
        kind: AgentKinds.frontAgent,
        displayName: any(named: 'displayName'),
        config: const AgentConfig(),
        allowedCategoryIds: {'work'},
        agentId: frontAgentId,
      ),
    ).thenAnswer((_) async {
      createdInside = inTransaction;
      return existing;
    });

    final identity = await service.getOrCreate(allowedCategoryIds: {'work'});

    expect(identity, same(existing));
    expect(createdInside, isTrue);
  });

  test('a peer that created the agent between the read and the transaction '
      'wins; nothing is created twice', () async {
    var reads = 0;
    when(() => agentService.getAgent(frontAgentId)).thenAnswer((_) async {
      reads++;
      return reads == 1 ? null : existing;
    });

    final identity = await service.getOrCreate();

    expect(identity, same(existing));
    expect(reads, 2);
    verifyNever(
      () => agentService.createAgent(
        kind: any(named: 'kind'),
        displayName: any(named: 'displayName'),
        config: any(named: 'config'),
        allowedCategoryIds: any(named: 'allowedCategoryIds'),
        agentId: any(named: 'agentId'),
      ),
    );
  });

  group('chooseProfile', () {
    const chosen = AgentInferenceSetup(
      mode: AgentInferenceSetupMode.configured,
      origin: AgentInferenceSetupOrigin.user,
      baseProfileId: 'profile-mistral',
    );
    final now = DateTime(2026, 11, 1, 9);

    setUp(() {
      when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    });

    AgentIdentityEntity written() =>
        verify(() => syncService.upsertEntity(captureAny())).captured.single
            as AgentIdentityEntity;

    test('writes the profile as her own setup, chosen by the user, stamped '
        'now', () async {
      when(
        () => agentService.getAgent(frontAgentId),
      ).thenAnswer((_) async => existing);

      final done = await withClock(
        Clock.fixed(now),
        () => service.chooseProfile('profile-mistral'),
      );

      expect(done, isTrue);
      final identity = written();
      expect(identity.config.inferenceSetup, chosen);
      expect(identity.config.profileId, 'profile-mistral');
      expect(identity.updatedAt, now);
      expect(identity.agentId, frontAgentId);
    });

    test('keeps the rest of her config', () async {
      when(() => agentService.getAgent(frontAgentId)).thenAnswer(
        (_) async => existing.copyWith(
          config: const AgentConfig(maxWakesPerDay: 7),
        ),
      );

      await service.chooseProfile('profile-mistral');

      expect(written().config.maxWakesPerDay, 7);
    });

    test('replaces an earlier choice', () async {
      when(() => agentService.getAgent(frontAgentId)).thenAnswer(
        (_) async => existing.copyWith(
          config: const AgentConfig(
            profileId: 'profile-melious',
            inferenceSetup: AgentInferenceSetup(
              mode: AgentInferenceSetupMode.configured,
              origin: AgentInferenceSetupOrigin.user,
              baseProfileId: 'profile-melious',
            ),
          ),
        ),
      );

      await service.chooseProfile('profile-mistral');

      expect(written().config.inferenceSetup, chosen);
    });

    test('writes nothing when she already uses that choice', () async {
      when(() => agentService.getAgent(frontAgentId)).thenAnswer(
        (_) async => existing.copyWith(
          config: const AgentConfig(
            profileId: 'profile-mistral',
            inferenceSetup: chosen,
          ),
        ),
      );

      expect(await service.chooseProfile('profile-mistral'), isTrue);
      verifyNever(() => syncService.upsertEntity(any()));
    });

    test('rewrites a stale bare profile id even when the setup already '
        'matches', () async {
      when(() => agentService.getAgent(frontAgentId)).thenAnswer(
        (_) async => existing.copyWith(
          config: const AgentConfig(
            profileId: 'profile-old',
            inferenceSetup: chosen,
          ),
        ),
      );

      await service.chooseProfile('profile-mistral');

      expect(written().config.profileId, 'profile-mistral');
    });

    test(
      'null clears her choice, so she follows the Settings default',
      () async {
        when(() => agentService.getAgent(frontAgentId)).thenAnswer(
          (_) async => existing.copyWith(
            config: const AgentConfig(
              profileId: 'profile-mistral',
              inferenceSetup: chosen,
              maxWakesPerDay: 7,
            ),
          ),
        );

        expect(await service.chooseProfile(null), isTrue);

        final config = written().config;
        expect(config.inferenceSetup, isNull);
        expect(config.profileId, isNull);
        expect(config.maxWakesPerDay, 7);
      },
    );

    test('null writes nothing when she has no choice of her own', () async {
      when(
        () => agentService.getAgent(frontAgentId),
      ).thenAnswer((_) async => existing.copyWith(config: const AgentConfig()));

      expect(await service.chooseProfile(null), isTrue);
      verifyNever(() => syncService.upsertEntity(any()));
    });

    test('answers false, writing nothing, before she exists', () async {
      when(
        () => agentService.getAgent(frontAgentId),
      ).thenAnswer((_) async => null);

      expect(await service.chooseProfile('profile-mistral'), isFalse);
      verifyNever(() => syncService.upsertEntity(any()));
    });

    test('reads and writes inside one transaction', () async {
      var inTransaction = false;
      var readInside = false;
      var writtenInside = false;
      syncService.transactionDelegate = <T>(action) async {
        inTransaction = true;
        try {
          return await action();
        } finally {
          inTransaction = false;
        }
      };
      when(() => agentService.getAgent(frontAgentId)).thenAnswer((_) async {
        readInside = inTransaction;
        return existing;
      });
      when(() => syncService.upsertEntity(any())).thenAnswer((_) async {
        writtenInside = inTransaction;
      });

      await service.chooseProfile('profile-mistral');

      expect(readInside, isTrue);
      expect(writtenInside, isTrue);
    });
  });
}
