import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/demo/ai/demo_ai_gate.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  final created = DateTime(2026, 8, 5);

  AiConfig provider(String id) => AiConfig.inferenceProvider(
    id: id,
    baseUrl: 'https://example.test',
    apiKey: 'key-$id',
    name: 'Provider $id',
    createdAt: created,
    inferenceProviderType: InferenceProviderType.gemini,
  );

  DemoSeedManifest manifest(List<String> seededAiConfigIds) => DemoSeedManifest(
    seedVersion: demoSeedVersion,
    seededAt: created.toUtc(),
    localeTag: 'en',
    seededJournalIds: const [],
    seededDefinitionIds: const [],
    seededAiConfigIds: seededAiConfigIds,
  );

  ProfileContext context({required bool guest}) => ProfileContext.forProfile(
    profile: guest
        ? Profile(
            id: 'demo-guest',
            type: ProfileType.guest,
            name: 'Demo',
            dirName: 'demo-guest',
            createdAt: created,
          )
        : Profile.realDefault(),
    root: Directory.systemTemp,
  );

  ProviderContainer buildContainer({
    required DemoSeedManifest? seedManifest,
    required AiConfigRepository repository,
    ProfileContext? profileContext,
  }) {
    final container = ProviderContainer(
      overrides: [
        demoSeedManifestProvider.overrideWith((ref) async => seedManifest),
        aiConfigRepositoryProvider.overrideWithValue(repository),
        if (profileContext != null)
          profileContextProvider.overrideWithValue(profileContext),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  MockAiConfigRepository repositoryWith(List<AiConfig> providers) {
    final repository = MockAiConfigRepository();
    when(
      () => repository.watchConfigsByType(AiConfigType.inferenceProvider),
    ).thenAnswer((_) => Stream.value(providers));
    return repository;
  }

  group('demoRealAiAvailableProvider', () {
    test('false when every provider config is a seeded fixture', () async {
      final container = buildContainer(
        seedManifest: manifest(['fixture-a', 'fixture-b']),
        repository: repositoryWith([
          provider('fixture-a'),
          provider('fixture-b'),
        ]),
      );

      expect(
        await container.read(demoRealAiAvailableProvider.future),
        isFalse,
      );
    });

    test('true as soon as one provider id is not in the manifest', () async {
      final container = buildContainer(
        seedManifest: manifest(['fixture-a']),
        repository: repositoryWith([
          provider('fixture-a'),
          provider('user-real'),
        ]),
      );

      expect(await container.read(demoRealAiAvailableProvider.future), isTrue);
    });

    test('false with no providers at all', () async {
      final container = buildContainer(
        seedManifest: manifest(['fixture-a']),
        repository: repositoryWith([]),
      );

      expect(
        await container.read(demoRealAiAvailableProvider.future),
        isFalse,
      );
    });

    test('without a manifest every provider counts as real (a corrupt '
        'manifest must not nudge a working setup)', () async {
      final container = buildContainer(
        seedManifest: null,
        repository: repositoryWith([provider('anything')]),
      );

      expect(await container.read(demoRealAiAvailableProvider.future), isTrue);
    });

    test('flips reactively when the user connects a real provider', () async {
      final repository = MockAiConfigRepository();
      // Mirrors the production repository stream: replays the current
      // snapshot to every subscriber, then forwards updates.
      var current = <AiConfig>[provider('fixture-a')];
      final updates = StreamController<List<AiConfig>>.broadcast();
      addTearDown(updates.close);
      when(
        () => repository.watchConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) async* {
        yield current;
        yield* updates.stream;
      });
      final container = buildContainer(
        seedManifest: manifest(['fixture-a']),
        repository: repository,
      );
      // Keep the provider alive across emissions.
      final sub = container.listen(demoRealAiAvailableProvider, (_, _) {});
      addTearDown(sub.close);

      expect(
        await container.read(demoRealAiAvailableProvider.future),
        isFalse,
      );

      current = [provider('fixture-a'), provider('user-real')];
      updates.add(current);
      // The stream emission invalidates the FutureProvider; wait for the
      // recomputed value.
      await container.pump();
      expect(await container.read(demoRealAiAvailableProvider.future), isTrue);
    });
  });

  group('demoSeedManifestProvider', () {
    tearDown(() async {
      await getIt.reset();
    });

    test('reads the manifest at the registered root Directory', () async {
      final root = Directory.systemTemp.createTempSync('lotti_ai_gate_');
      addTearDown(() => root.delete(recursive: true));
      await manifest(['fixture-a']).write(root);
      getIt.registerSingleton<Directory>(root);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final loaded = await container.read(demoSeedManifestProvider.future);
      expect(loaded?.seededAiConfigIds, ['fixture-a']);
    });

    test('null without a registered root (bare tests, no crash)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(demoSeedManifestProvider.future), isNull);
    });

    test('a malformed manifest reads as null instead of throwing', () async {
      final root = Directory.systemTemp.createTempSync('lotti_ai_gate_bad_');
      addTearDown(() => root.delete(recursive: true));
      DemoSeedManifest.fileFor(root).writeAsStringSync('{not json');
      getIt.registerSingleton<Directory>(root);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(demoSeedManifestProvider.future), isNull);
    });
  });

  group('shouldNudgeForRealAi', () {
    test('true in the demo world while only fixtures exist', () async {
      final container = buildContainer(
        seedManifest: manifest(['fixture-a']),
        repository: repositoryWith([provider('fixture-a')]),
        profileContext: context(guest: true),
      );

      expect(await shouldNudgeForRealAi(container), isTrue);
    });

    test('false in the demo world once a real provider exists', () async {
      final container = buildContainer(
        seedManifest: manifest(['fixture-a']),
        repository: repositoryWith([
          provider('fixture-a'),
          provider('user-real'),
        ]),
        profileContext: context(guest: true),
      );

      expect(await shouldNudgeForRealAi(container), isFalse);
    });

    test(
      'false outside the demo WITHOUT touching the AI config database',
      () async {
        final repository = MockAiConfigRepository();
        final container = buildContainer(
          seedManifest: manifest(const []),
          repository: repository,
          profileContext: context(guest: false),
        );

        expect(await shouldNudgeForRealAi(container), isFalse);
        verifyZeroInteractions(repository);
      },
    );

    test('false when no profile context is overridden (bare widget tests '
        'default to the real world)', () async {
      final repository = MockAiConfigRepository();
      final container = buildContainer(
        seedManifest: manifest(const []),
        repository: repository,
      );

      expect(await shouldNudgeForRealAi(container), isFalse);
      verifyZeroInteractions(repository);
    });
  });
}
