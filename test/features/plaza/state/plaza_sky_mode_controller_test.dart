import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/plaza/state/plaza_sky_mode_controller.dart';
import 'package:lotti/features/plaza/ui/plaza_palette.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  late TestGetItMocks mocks;
  late ProviderContainer container;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mocks = await setUpTestGetIt();
    when(
      () => mocks.settingsDb.itemByKey(any<String>()),
    ).thenAnswer((_) async => null);
    when(
      () => mocks.settingsDb.saveSettingsItem(any<String>(), any<String>()),
    ).thenAnswer((_) async => 1);
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
  });

  /// Drains the pending microtasks of the controller's async load.
  Future<void> awaitHydration() async {
    for (var i = 0; i < 16; i++) {
      await Future<void>.value();
    }
  }

  PlazaSkyMode read() => container.read(plazaSkyModeProvider);
  PlazaSkyModeController notifier() =>
      container.read(plazaSkyModeProvider.notifier);

  /// Swaps a mock logger into getIt and returns it.
  MockDomainLogger installMockLogger() {
    final logger = MockDomainLogger();
    when(
      () => logger.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
        message: any<String>(named: 'message'),
      ),
    ).thenReturn(null);
    getIt
      ..unregister<DomainLogger>()
      ..registerSingleton<DomainLogger>(logger);
    return logger;
  }

  test('the district opens at night until told otherwise', () async {
    expect(read(), PlazaSkyMode.night);
    await awaitHydration();
    expect(read(), PlazaSkyMode.night);
    verify(() => mocks.settingsDb.itemByKey(plazaSkyModeSettingsKey)).called(1);
  });

  test('a remembered daylight preference is restored', () async {
    when(
      () => mocks.settingsDb.itemByKey(plazaSkyModeSettingsKey),
    ).thenAnswer((_) async => PlazaSkyMode.day.name);
    expect(read(), PlazaSkyMode.night, reason: 'before the read resolves');
    await awaitHydration();
    expect(read(), PlazaSkyMode.day);
  });

  test('a preference written by another build falls back to night', () async {
    when(
      () => mocks.settingsDb.itemByKey(plazaSkyModeSettingsKey),
    ).thenAnswer((_) async => 'golden-hour');
    await awaitHydration();
    expect(read(), PlazaSkyMode.night);
  });

  test('switching the sky persists it under the shared key', () async {
    await awaitHydration();
    notifier().set(PlazaSkyMode.day);
    expect(read(), PlazaSkyMode.day);
    await awaitHydration();
    verify(
      () => mocks.settingsDb.saveSettingsItem(
        plazaSkyModeSettingsKey,
        PlazaSkyMode.day.name,
      ),
    ).called(1);
  });

  test('switching to the mode already showing writes nothing', () async {
    await awaitHydration();
    notifier().set(PlazaSkyMode.night);
    await awaitHydration();
    verifyNever(
      () => mocks.settingsDb.saveSettingsItem(any<String>(), any<String>()),
    );
  });

  test('a choice made mid-load is not undone by the stored one', () async {
    // The walker switches to daylight while the initial read is still in
    // flight; the night that comes back must not overwrite it.
    when(
      () => mocks.settingsDb.itemByKey(plazaSkyModeSettingsKey),
    ).thenAnswer((_) async => PlazaSkyMode.night.name);
    notifier().set(PlazaSkyMode.day);
    await awaitHydration();
    expect(read(), PlazaSkyMode.day);
  });

  test(
    'an unreadable preference is logged and leaves night standing',
    () async {
      final logger = installMockLogger();
      when(
        () => mocks.settingsDb.itemByKey(plazaSkyModeSettingsKey),
      ).thenThrow(Exception('settings unavailable'));
      await awaitHydration();
      expect(read(), PlazaSkyMode.night);
      verify(
        () => logger.error(
          LogDomain.settings,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'plazaSkyMode.load',
        ),
      ).called(1);
    },
  );

  test('a failed write keeps the choice for this session', () async {
    final logger = installMockLogger();
    when(
      () => mocks.settingsDb.saveSettingsItem(any<String>(), any<String>()),
    ).thenThrow(Exception('disk full'));
    await awaitHydration();
    notifier().set(PlazaSkyMode.day);
    await awaitHydration();
    expect(read(), PlazaSkyMode.day);
    verify(
      () => logger.error(
        LogDomain.settings,
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: 'plazaSkyMode.persist',
      ),
    ).called(1);
  });

  test('without a settings database the sky still switches', () async {
    getIt.unregister<SettingsDb>();
    await awaitHydration();
    expect(read(), PlazaSkyMode.night);
    notifier().set(PlazaSkyMode.day);
    await awaitHydration();
    expect(read(), PlazaSkyMode.day);
  });
}
