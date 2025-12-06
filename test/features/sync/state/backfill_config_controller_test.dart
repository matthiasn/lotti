import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/state/backfill_config_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('BackfillConfigController', () {
    test('initial state defaults to enabled', () async {
      final state =
          await container.read(backfillConfigControllerProvider.future);
      expect(state, isTrue);
    });

    test('initial state reads from SharedPreferences when set to false',
        () async {
      SharedPreferences.setMockInitialValues({'backfill_enabled': false});
      container = ProviderContainer();

      final state =
          await container.read(backfillConfigControllerProvider.future);
      expect(state, isFalse);
    });

    test('initial state reads from SharedPreferences when set to true',
        () async {
      SharedPreferences.setMockInitialValues({'backfill_enabled': true});
      container = ProviderContainer();

      final state =
          await container.read(backfillConfigControllerProvider.future);
      expect(state, isTrue);
    });

    test('setEnabled updates state to false', () async {
      final controller =
          container.read(backfillConfigControllerProvider.notifier);

      await controller.setEnabled(enabled: false);

      final state =
          await container.read(backfillConfigControllerProvider.future);
      expect(state, isFalse);
    });

    test('setEnabled updates state to true', () async {
      SharedPreferences.setMockInitialValues({'backfill_enabled': false});
      container = ProviderContainer();
      final controller =
          container.read(backfillConfigControllerProvider.notifier);

      await controller.setEnabled(enabled: true);

      final state =
          await container.read(backfillConfigControllerProvider.future);
      expect(state, isTrue);
    });

    test('toggle switches from enabled to disabled', () async {
      SharedPreferences.setMockInitialValues({'backfill_enabled': true});
      container = ProviderContainer();
      final controller =
          container.read(backfillConfigControllerProvider.notifier);

      // Wait for initial state to load
      await container.read(backfillConfigControllerProvider.future);

      await controller.toggle();

      final state =
          await container.read(backfillConfigControllerProvider.future);
      expect(state, isFalse);
    });

    test('toggle switches from disabled to enabled', () async {
      SharedPreferences.setMockInitialValues({'backfill_enabled': false});
      container = ProviderContainer();
      final controller =
          container.read(backfillConfigControllerProvider.notifier);

      // Wait for initial state to load
      await container.read(backfillConfigControllerProvider.future);

      await controller.toggle();

      final state =
          await container.read(backfillConfigControllerProvider.future);
      expect(state, isTrue);
    });

    test('setEnabled persists to SharedPreferences', () async {
      final controller =
          container.read(backfillConfigControllerProvider.notifier);

      await controller.setEnabled(enabled: false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('backfill_enabled'), isFalse);
    });
  });

  group('isBackfillEnabled', () {
    test('returns true when not set', () async {
      SharedPreferences.setMockInitialValues({});
      final result = await isBackfillEnabled();
      expect(result, isTrue);
    });

    test('returns false when set to false', () async {
      SharedPreferences.setMockInitialValues({'backfill_enabled': false});
      final result = await isBackfillEnabled();
      expect(result, isFalse);
    });

    test('returns true when set to true', () async {
      SharedPreferences.setMockInitialValues({'backfill_enabled': true});
      final result = await isBackfillEnabled();
      expect(result, isTrue);
    });
  });
}
