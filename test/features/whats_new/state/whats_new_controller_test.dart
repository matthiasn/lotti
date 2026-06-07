import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/whats_new/model/whats_new_content.dart';
import 'package:lotti/features/whats_new/model/whats_new_release.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeWhatsNewRelease());

    // Mock PackageInfo platform channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/package_info'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getAll') {
              return <String, dynamic>{
                'appName': 'Lotti',
                'packageName': 'app.lotti',
                'version':
                    '99.99.99', // High version to include all test releases
                'buildNumber': '1',
              };
            }
            return null;
          },
        );
  });

  tearDownAll(() {
    // Clear the PackageInfo mock to prevent leaking to other tests
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/package_info'),
          null,
        );
  });

  late MockWhatsNewService mockService;
  late ProviderContainer container;

  final testRelease1 = WhatsNewRelease(
    version: '0.9.980',
    date: DateTime(2026, 1, 7),
    title: 'January Update',
    folder: '0.9.980',
  );

  final testRelease2 = WhatsNewRelease(
    version: '0.9.970',
    date: DateTime(2025, 12, 15),
    title: 'December Update',
    folder: '0.9.970',
  );

  final testContent1 = WhatsNewContent(
    release: testRelease1,
    headerMarkdown: '# January Update',
    sections: ['## Feature 1', '## Feature 2'],
    bannerImageUrl: 'https://example.com/banner1.png',
  );

  final testContent2 = WhatsNewContent(
    release: testRelease2,
    headerMarkdown: '# December Update',
    sections: ['## Old Feature'],
    bannerImageUrl: 'https://example.com/banner2.png',
  );

  setUp(() {
    mockService = MockWhatsNewService();
    SharedPreferences.setMockInitialValues({});

    container = ProviderContainer(
      overrides: [
        whatsNewServiceProvider.overrideWithValue(mockService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  /// Re-creates the mock service and container after seeding
  /// SharedPreferences — the controller reads prefs during build, so the
  /// seed must land before the container that builds it exists.
  void remakeContainer({Map<String, Object> prefs = const {}}) {
    SharedPreferences.setMockInitialValues(prefs);
    container.dispose();
    mockService = MockWhatsNewService();
    container = ProviderContainer(
      overrides: [whatsNewServiceProvider.overrideWithValue(mockService)],
    );
  }

  group('WhatsNewController', () {
    test('returns empty state when index is null', () async {
      when(() => mockService.fetchIndex()).thenAnswer((_) async => null);

      final state = await container.read(whatsNewControllerProvider.future);

      expect(state.hasUnseenRelease, isFalse);
      expect(state.unseenContent, isEmpty);
    });

    test('returns empty state when index is empty', () async {
      when(() => mockService.fetchIndex()).thenAnswer((_) async => []);

      final state = await container.read(whatsNewControllerProvider.future);

      expect(state.hasUnseenRelease, isFalse);
      expect(state.unseenContent, isEmpty);
    });

    test('returns all unseen releases when none seen before', () async {
      when(
        () => mockService.fetchIndex(),
      ).thenAnswer((_) async => [testRelease1, testRelease2]);
      when(
        () => mockService.fetchContent(testRelease1),
      ).thenAnswer((_) async => testContent1);
      when(
        () => mockService.fetchContent(testRelease2),
      ).thenAnswer((_) async => testContent2);

      final state = await container.read(whatsNewControllerProvider.future);

      expect(state.hasUnseenRelease, isTrue);
      expect(state.unseenContent, hasLength(2));
      expect(state.unseenContent[0].release.version, equals('0.9.980'));
      expect(state.unseenContent[1].release.version, equals('0.9.970'));
    });

    test('returns only unseen releases when some already seen', () async {
      remakeContainer(
        prefs: {
          'whats_new_seen_0.9.970': true,
        },
      );

      when(
        () => mockService.fetchIndex(),
      ).thenAnswer((_) async => [testRelease1, testRelease2]);
      when(
        () => mockService.fetchContent(testRelease1),
      ).thenAnswer((_) async => testContent1);

      final state = await container.read(whatsNewControllerProvider.future);

      expect(state.hasUnseenRelease, isTrue);
      expect(state.unseenContent, hasLength(1));
      expect(state.unseenContent[0].release.version, equals('0.9.980'));

      // Should not fetch content for already seen release
      verifyNever(() => mockService.fetchContent(testRelease2));
    });

    test('returns empty state when all releases already seen', () async {
      remakeContainer(
        prefs: {
          'whats_new_seen_0.9.980': true,
          'whats_new_seen_0.9.970': true,
        },
      );

      when(
        () => mockService.fetchIndex(),
      ).thenAnswer((_) async => [testRelease1, testRelease2]);

      final state = await container.read(whatsNewControllerProvider.future);

      expect(state.hasUnseenRelease, isFalse);
      expect(state.unseenContent, isEmpty);

      verifyNever(() => mockService.fetchContent(any()));
    });

    test('markAllAsSeen updates state and preferences', () async {
      remakeContainer();

      when(
        () => mockService.fetchIndex(),
      ).thenAnswer((_) async => [testRelease1, testRelease2]);
      when(
        () => mockService.fetchContent(testRelease1),
      ).thenAnswer((_) async => testContent1);
      when(
        () => mockService.fetchContent(testRelease2),
      ).thenAnswer((_) async => testContent2);

      var state = await container.read(whatsNewControllerProvider.future);
      expect(state.hasUnseenRelease, isTrue);
      expect(state.unseenContent, hasLength(2));

      await container.read(whatsNewControllerProvider.notifier).markAllAsSeen();

      state = container.read(whatsNewControllerProvider).value!;
      expect(state.hasUnseenRelease, isFalse);
      expect(state.unseenContent, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('whats_new_seen_0.9.980'), isTrue);
      expect(prefs.getBool('whats_new_seen_0.9.970'), isTrue);
    });

    test('markAsSeen removes specific release from state', () async {
      remakeContainer();

      when(
        () => mockService.fetchIndex(),
      ).thenAnswer((_) async => [testRelease1, testRelease2]);
      when(
        () => mockService.fetchContent(testRelease1),
      ).thenAnswer((_) async => testContent1);
      when(
        () => mockService.fetchContent(testRelease2),
      ).thenAnswer((_) async => testContent2);

      var state = await container.read(whatsNewControllerProvider.future);
      expect(state.unseenContent, hasLength(2));

      await container
          .read(whatsNewControllerProvider.notifier)
          .markAsSeen('0.9.980');

      state = container.read(whatsNewControllerProvider).value!;
      expect(state.unseenContent, hasLength(1));
      expect(state.unseenContent[0].release.version, equals('0.9.970'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('whats_new_seen_0.9.980'), isTrue);
      expect(prefs.getBool('whats_new_seen_0.9.970'), isNull);
    });

    test('markAllAsSeen does nothing when no content', () async {
      remakeContainer();

      when(() => mockService.fetchIndex()).thenAnswer((_) async => null);

      await container.read(whatsNewControllerProvider.future);
      await container.read(whatsNewControllerProvider.notifier).markAllAsSeen();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.startsWith('whats_new_')), isEmpty);
    });

    test('resetSeenStatus clears preferences and refreshes', () async {
      remakeContainer(
        prefs: {
          'whats_new_seen_0.9.980': true,
          'whats_new_seen_0.9.970': true,
          'other_key': true,
        },
      );

      when(
        () => mockService.fetchIndex(),
      ).thenAnswer((_) async => [testRelease1]);
      when(
        () => mockService.fetchContent(testRelease1),
      ).thenAnswer((_) async => testContent1);

      await container.read(whatsNewControllerProvider.future);
      await container
          .read(whatsNewControllerProvider.notifier)
          .resetSeenStatus();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('whats_new_seen_0.9.980'), isNull);
      expect(prefs.getBool('whats_new_seen_0.9.970'), isNull);
      expect(prefs.getBool('other_key'), isTrue);
    });
  });

  group('shouldAutoShowWhatsNew', () {
    /// Creates a fresh container with the config flag overridden, seeding
    /// SharedPreferences first (the controller reads prefs during build).
    /// Uses the per-test `mockService` from `setUp`, so stubs registered
    /// before this call stay in effect.
    ProviderContainer createContainerWithFlag({
      required bool enabled,
      Map<String, Object> prefs = const {},
    }) {
      SharedPreferences.setMockInitialValues(prefs);
      final mockDb = MockJournalDb();
      when(
        () => mockDb.getConfigFlag(enableWhatsNewFlag),
      ).thenAnswer((_) async => enabled);

      return ProviderContainer(
        overrides: [
          whatsNewServiceProvider.overrideWithValue(mockService),
          journalDbProvider.overrideWithValue(mockDb),
        ],
      );
    }

    test(
      'returns true on first launch when there are unseen releases',
      () async {
        when(
          () => mockService.fetchIndex(),
        ).thenAnswer((_) async => [testRelease1]);
        when(
          () => mockService.fetchContent(testRelease1),
        ).thenAnswer((_) async => testContent1);

        final c = createContainerWithFlag(enabled: true);
        addTearDown(c.dispose);

        final shouldShow = await c.read(
          shouldAutoShowWhatsNewProvider.future,
        );

        expect(shouldShow, isTrue);

        // Should have stored the current version
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('whats_new_last_launched_version'),
          equals('99.99.99'),
        );
      },
    );

    test('returns false on first launch when no releases available', () async {
      when(() => mockService.fetchIndex()).thenAnswer((_) async => null);

      final c = createContainerWithFlag(enabled: true);
      addTearDown(c.dispose);

      final shouldShow = await c.read(
        shouldAutoShowWhatsNewProvider.future,
      );

      expect(shouldShow, isFalse);
    });

    test('returns false when version has not changed', () async {
      final c = createContainerWithFlag(
        enabled: true,
        prefs: {
          'whats_new_last_launched_version': '99.99.99', // Same as mock version
        },
      );
      when(
        () => mockService.fetchIndex(),
      ).thenAnswer((_) async => [testRelease1]);
      when(
        () => mockService.fetchContent(testRelease1),
      ).thenAnswer((_) async => testContent1);

      addTearDown(c.dispose);

      final shouldShow = await c.read(
        shouldAutoShowWhatsNewProvider.future,
      );

      expect(shouldShow, isFalse);
    });

    test('returns true when version changed and has unseen releases', () async {
      final c = createContainerWithFlag(
        enabled: true,
        prefs: {
          'whats_new_last_launched_version': '98.98.98', // Different from mock
        },
      );
      when(
        () => mockService.fetchIndex(),
      ).thenAnswer((_) async => [testRelease1]);
      when(
        () => mockService.fetchContent(testRelease1),
      ).thenAnswer((_) async => testContent1);

      addTearDown(c.dispose);

      final shouldShow = await c.read(
        shouldAutoShowWhatsNewProvider.future,
      );

      expect(shouldShow, isTrue);

      // Should have updated the stored version
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('whats_new_last_launched_version'),
        equals('99.99.99'),
      );
    });

    test('returns false when version changed but no unseen releases', () async {
      when(
        () => mockService.fetchIndex(),
      ).thenAnswer((_) async => [testRelease1]);

      final c = createContainerWithFlag(
        enabled: true,
        prefs: {
          'whats_new_last_launched_version': '98.98.98', // != mock version
          'whats_new_seen_0.9.980': true, // Already seen
        },
      );
      addTearDown(c.dispose);

      final shouldShow = await c.read(
        shouldAutoShowWhatsNewProvider.future,
      );

      expect(shouldShow, isFalse);
    });

    test(
      'returns false when version changed but no releases available',
      () async {
        final c = createContainerWithFlag(
          enabled: true,
          prefs: {
            'whats_new_last_launched_version': '98.98.98',
          },
        );
        when(() => mockService.fetchIndex()).thenAnswer((_) async => null);

        addTearDown(c.dispose);

        final shouldShow = await c.read(
          shouldAutoShowWhatsNewProvider.future,
        );

        expect(shouldShow, isFalse);
      },
    );

    test('returns false when config flag is disabled', () async {
      when(
        () => mockService.fetchIndex(),
      ).thenAnswer((_) async => [testRelease1]);
      when(
        () => mockService.fetchContent(testRelease1),
      ).thenAnswer((_) async => testContent1);

      final c = createContainerWithFlag(enabled: false);
      addTearDown(c.dispose);

      final shouldShow = await c.read(
        shouldAutoShowWhatsNewProvider.future,
      );

      expect(shouldShow, isFalse);

      // Should not have checked version or fetched releases
      verifyNever(() => mockService.fetchIndex());
    });
  });

  group('isNewerVersion', () {
    test('worked examples across part boundaries', () {
      expect(WhatsNewController.isNewerVersion('0.9.804', '0.9.802'), isTrue);
      expect(WhatsNewController.isNewerVersion('0.9.802', '0.9.804'), isFalse);
      expect(WhatsNewController.isNewerVersion('0.9.802', '0.9.802'), isFalse);
      expect(WhatsNewController.isNewerVersion('1.0.0', '0.9.999'), isTrue);
      expect(WhatsNewController.isNewerVersion('100.0.0', '0.9.980'), isTrue);
      // More parts on equal prefix counts as newer.
      expect(WhatsNewController.isNewerVersion('1.0.0.1', '1.0.0'), isTrue);
      // Unparseable parts are treated as 0.
      expect(WhatsNewController.isNewerVersion('1.x.0', '1.0.0'), isFalse);
      expect(WhatsNewController.isNewerVersion('1.1.0', '1.x.0'), isTrue);
    });

    glados.Glados3<int, int, int>(
      glados.IntAnys(glados.any).intInRange(0, 100),
      glados.IntAnys(glados.any).intInRange(0, 100),
      glados.IntAnys(glados.any).intInRange(0, 100),
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'irreflexive, asymmetric, and bump-sensitive over generated versions',
      (major, minor, patch) {
        final version = '$major.$minor.$patch';

        // A version is never newer than itself.
        expect(WhatsNewController.isNewerVersion(version, version), isFalse);

        // Bumping any single part makes it newer — and the comparison is
        // asymmetric.
        final bumps = [
          '${major + 1}.$minor.$patch',
          '$major.${minor + 1}.$patch',
          '$major.$minor.${patch + 1}',
        ];
        for (final bumped in bumps) {
          expect(
            WhatsNewController.isNewerVersion(bumped, version),
            isTrue,
            reason: '$bumped vs $version',
          );
          expect(
            WhatsNewController.isNewerVersion(version, bumped),
            isFalse,
            reason: '$version vs $bumped',
          );
        }
      },
      tags: 'glados',
    );
  });

  group('version gating through build', () {
    test('skips releases newer than the installed app version', () async {
      // The PackageInfo mock reports 99.99.99 — a 100.0.0 release is from
      // the future and must be filtered out, while 0.9.980 still shows.
      final futureRelease = WhatsNewRelease(
        version: '100.0.0',
        date: DateTime(2027),
        title: 'Future Update',
        folder: '100.0.0',
      );

      when(
        () => mockService.fetchIndex(),
      ).thenAnswer((_) async => [futureRelease, testRelease1]);
      when(
        () => mockService.fetchContent(testRelease1),
      ).thenAnswer((_) async => testContent1);

      final state = await container.read(whatsNewControllerProvider.future);

      expect(state.unseenContent, hasLength(1));
      expect(state.unseenContent.single.release.version, '0.9.980');
      verifyNever(() => mockService.fetchContent(futureRelease));
    });
  });
}
