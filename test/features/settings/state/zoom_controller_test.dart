import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/settings/state/zoom_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

/// Creates a fresh [ProviderContainer] with [SettingsDb.itemByKey] stubbed
/// to return [storedValue] for the zoom scale key.
Future<ProviderContainer> _createContainerWithPersistedScale(
  String? storedValue,
) async {
  await tearDownTestGetIt();
  final mocks = await setUpTestGetIt();
  if (storedValue != null) {
    when(
      () => mocks.settingsDb.itemByKey('ZOOM_SCALE'),
    ).thenAnswer((_) async => storedValue);
  }
  return ProviderContainer();
}

/// Waits for the async hydration in [ZoomController] to settle.
///
/// Returns the final scale value. If the state changes from the default,
/// the completer resolves immediately. Otherwise waits up to [timeout]
/// before returning the current (unchanged) value.
Future<double> _awaitHydration(
  ProviderContainer container, {
  Duration timeout = const Duration(milliseconds: 50),
}) async {
  final completer = Completer<double>();
  container.listen(zoomControllerProvider, (prev, next) {
    if (!completer.isCompleted && next != defaultZoomScale) {
      completer.complete(next);
    }
  });
  // ignore: cascade_invocations
  container.read(zoomControllerProvider);

  final result = await Future.any([
    completer.future,
    Future<double>.delayed(timeout, () => defaultZoomScale),
  ]);
  return result;
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    await setUpTestGetIt();
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
  });

  group('ZoomController build', () {
    test('returns defaultZoomScale on init', () {
      expect(container.read(zoomControllerProvider), defaultZoomScale);
    });

    test('loads persisted scale from SettingsDb', () async {
      container.dispose();
      container = await _createContainerWithPersistedScale('1.50');

      final result = await _awaitHydration(container);
      expect(result, 1.5);
    });

    test('ignores persisted value below minZoomScale', () async {
      container.dispose();
      container = await _createContainerWithPersistedScale('0.1');

      final result = await _awaitHydration(container);
      expect(result, defaultZoomScale);
    });

    test('ignores persisted value above maxZoomScale', () async {
      container.dispose();
      container = await _createContainerWithPersistedScale('5.0');

      final result = await _awaitHydration(container);
      expect(result, defaultZoomScale);
    });

    test('ignores non-numeric persisted value', () async {
      container.dispose();
      container = await _createContainerWithPersistedScale('abc');

      final result = await _awaitHydration(container);
      expect(result, defaultZoomScale);
    });

    test('accepts persisted value at minZoomScale boundary', () async {
      container.dispose();
      container = await _createContainerWithPersistedScale('0.50');

      final result = await _awaitHydration(container);
      expect(result, minZoomScale);
    });

    test('accepts persisted value at maxZoomScale boundary', () async {
      container.dispose();
      container = await _createContainerWithPersistedScale('3.00');

      final result = await _awaitHydration(container);
      expect(result, maxZoomScale);
    });

    test('ignores null persisted value', () async {
      container.dispose();
      container = await _createContainerWithPersistedScale(null);

      final result = await _awaitHydration(container);
      expect(result, defaultZoomScale);
    });
  });

  group('ZoomController zoomIn', () {
    test('increases scale by zoomStep', () {
      container.read(zoomControllerProvider.notifier).zoomIn();
      expect(container.read(zoomControllerProvider), closeTo(1.1, 0.001));
    });

    test('accumulates over multiple calls', () {
      container.read(zoomControllerProvider.notifier)
        ..zoomIn()
        ..zoomIn()
        ..zoomIn();
      expect(container.read(zoomControllerProvider), closeTo(1.3, 0.001));
    });

    test('clamps at maxZoomScale', () {
      final notifier = container.read(zoomControllerProvider.notifier);
      for (var i = 0; i < 30; i++) {
        notifier.zoomIn();
      }
      expect(container.read(zoomControllerProvider), maxZoomScale);
    });

    test('persists to SettingsDb', () {
      container.read(zoomControllerProvider.notifier).zoomIn();
      verify(
        () => getIt<SettingsDb>().saveSettingsItem('ZOOM_SCALE', '1.10'),
      ).called(1);
    });
  });

  group('ZoomController zoomOut', () {
    test('decreases scale by zoomStep', () {
      container.read(zoomControllerProvider.notifier).zoomOut();
      expect(container.read(zoomControllerProvider), closeTo(0.9, 0.001));
    });

    test('clamps at minZoomScale', () {
      final notifier = container.read(zoomControllerProvider.notifier);
      for (var i = 0; i < 20; i++) {
        notifier.zoomOut();
      }
      expect(container.read(zoomControllerProvider), minZoomScale);
    });

    test('persists to SettingsDb', () {
      container.read(zoomControllerProvider.notifier).zoomOut();
      verify(
        () => getIt<SettingsDb>().saveSettingsItem('ZOOM_SCALE', '0.90'),
      ).called(1);
    });
  });

  group('ZoomController resetZoom', () {
    test('returns to defaultZoomScale', () {
      container.read(zoomControllerProvider.notifier)
        ..zoomIn()
        ..zoomIn()
        ..resetZoom();
      expect(container.read(zoomControllerProvider), defaultZoomScale);
    });

    test('persists to SettingsDb', () {
      container.read(zoomControllerProvider.notifier).resetZoom();
      verify(
        () => getIt<SettingsDb>().saveSettingsItem('ZOOM_SCALE', '1.00'),
      ).called(1);
    });
  });

  group('ZoomController roundtrip', () {
    test('zoomIn then zoomOut returns to original', () {
      container.read(zoomControllerProvider.notifier)
        ..zoomIn()
        ..zoomOut();
      expect(container.read(zoomControllerProvider), closeTo(1.0, 0.001));
    });
  });
}
