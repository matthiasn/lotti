import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/whats_new/model/whats_new_content.dart';
import 'package:lotti/features/whats_new/model/whats_new_release.dart';
import 'package:lotti/features/whats_new/repository/whats_new_service.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockWhatsNewService extends Mock implements WhatsNewService {}

class FakeWhatsNewRelease extends Fake implements WhatsNewRelease {}

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
            'version': '99.99.99', // High version to include all test releases
            'buildNumber': '1',
          };
        }
        return null;
      },
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
      when(() => mockService.fetchIndex())
          .thenAnswer((_) async => [testRelease1, testRelease2]);
      when(() => mockService.fetchContent(testRelease1))
          .thenAnswer((_) async => testContent1);
      when(() => mockService.fetchContent(testRelease2))
          .thenAnswer((_) async => testContent2);

      final state = await container.read(whatsNewControllerProvider.future);

      expect(state.hasUnseenRelease, isTrue);
      expect(state.unseenContent, hasLength(2));
      expect(state.unseenContent[0].release.version, equals('0.9.980'));
      expect(state.unseenContent[1].release.version, equals('0.9.970'));
    });

    test('returns only unseen releases when some already seen', () async {
      SharedPreferences.setMockInitialValues({
        'whats_new_seen_0.9.970': true,
      });

      container.dispose();
      mockService = MockWhatsNewService();
      container = ProviderContainer(
        overrides: [
          whatsNewServiceProvider.overrideWithValue(mockService),
        ],
      );

      when(() => mockService.fetchIndex())
          .thenAnswer((_) async => [testRelease1, testRelease2]);
      when(() => mockService.fetchContent(testRelease1))
          .thenAnswer((_) async => testContent1);

      final state = await container.read(whatsNewControllerProvider.future);

      expect(state.hasUnseenRelease, isTrue);
      expect(state.unseenContent, hasLength(1));
      expect(state.unseenContent[0].release.version, equals('0.9.980'));

      // Should not fetch content for already seen release
      verifyNever(() => mockService.fetchContent(testRelease2));
    });

    test('returns empty state when all releases already seen', () async {
      SharedPreferences.setMockInitialValues({
        'whats_new_seen_0.9.980': true,
        'whats_new_seen_0.9.970': true,
      });

      container.dispose();
      mockService = MockWhatsNewService();
      container = ProviderContainer(
        overrides: [
          whatsNewServiceProvider.overrideWithValue(mockService),
        ],
      );

      when(() => mockService.fetchIndex())
          .thenAnswer((_) async => [testRelease1, testRelease2]);

      final state = await container.read(whatsNewControllerProvider.future);

      expect(state.hasUnseenRelease, isFalse);
      expect(state.unseenContent, isEmpty);

      verifyNever(() => mockService.fetchContent(any()));
    });

    test('markAllAsSeen updates state and preferences', () async {
      container.dispose();
      mockService = MockWhatsNewService();
      container = ProviderContainer(
        overrides: [
          whatsNewServiceProvider.overrideWithValue(mockService),
        ],
      );

      when(() => mockService.fetchIndex())
          .thenAnswer((_) async => [testRelease1, testRelease2]);
      when(() => mockService.fetchContent(testRelease1))
          .thenAnswer((_) async => testContent1);
      when(() => mockService.fetchContent(testRelease2))
          .thenAnswer((_) async => testContent2);

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
      container.dispose();
      mockService = MockWhatsNewService();
      container = ProviderContainer(
        overrides: [
          whatsNewServiceProvider.overrideWithValue(mockService),
        ],
      );

      when(() => mockService.fetchIndex())
          .thenAnswer((_) async => [testRelease1, testRelease2]);
      when(() => mockService.fetchContent(testRelease1))
          .thenAnswer((_) async => testContent1);
      when(() => mockService.fetchContent(testRelease2))
          .thenAnswer((_) async => testContent2);

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
      container.dispose();
      mockService = MockWhatsNewService();
      container = ProviderContainer(
        overrides: [
          whatsNewServiceProvider.overrideWithValue(mockService),
        ],
      );

      when(() => mockService.fetchIndex()).thenAnswer((_) async => null);

      await container.read(whatsNewControllerProvider.future);
      await container.read(whatsNewControllerProvider.notifier).markAllAsSeen();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.startsWith('whats_new_')), isEmpty);
    });

    test('resetSeenStatus clears preferences and refreshes', () async {
      SharedPreferences.setMockInitialValues({
        'whats_new_seen_0.9.980': true,
        'whats_new_seen_0.9.970': true,
        'other_key': true,
      });

      container.dispose();
      mockService = MockWhatsNewService();
      container = ProviderContainer(
        overrides: [
          whatsNewServiceProvider.overrideWithValue(mockService),
        ],
      );

      when(() => mockService.fetchIndex())
          .thenAnswer((_) async => [testRelease1]);
      when(() => mockService.fetchContent(testRelease1))
          .thenAnswer((_) async => testContent1);

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
}
