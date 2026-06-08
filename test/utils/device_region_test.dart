import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/device_region.dart';

class _FakeDeviceRegion extends DeviceRegion {
  const _FakeDeviceRegion(this.region);

  final String? region;

  @override
  Future<String?> regionCode({bool? isMacOS, String? localeName}) async =>
      region;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(deviceRegionChannelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void stubChannel(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async => handler(call));
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('DeviceRegion.regionCode', () {
    test('macOS: the native region wins over the UI-language locale', () async {
      stubChannel((call) {
        expect(call.method, 'getRegionCode');
        return 'DE';
      });

      final region = await const DeviceRegion().regionCode(
        isMacOS: true,
        localeName: 'en_US',
      );

      expect(region, 'DE');
    });

    test(
      'macOS: empty native result falls back to the locale region',
      () async {
        stubChannel((_) => null);

        final region = await const DeviceRegion().regionCode(
          isMacOS: true,
          localeName: 'en_DE',
        );

        expect(region, 'DE');
      },
    );

    test('macOS: a channel failure falls back to the locale region', () async {
      stubChannel((_) => throw PlatformException(code: 'unavailable'));

      final region = await const DeviceRegion().regionCode(
        isMacOS: true,
        localeName: 'en_GB',
      );

      expect(region, 'GB');
    });

    test(
      'non-macOS: uses the locale region without touching the channel',
      () async {
        var channelCalled = false;
        stubChannel((_) {
          channelCalled = true;
          return 'XX';
        });

        final region = await const DeviceRegion().regionCode(
          isMacOS: false,
          localeName: 'de_DE.UTF-8',
        );

        expect(region, 'DE');
        expect(channelCalled, isFalse);
      },
    );

    test('non-macOS: a region-less locale yields null', () async {
      final region = await const DeviceRegion().regionCode(
        isMacOS: false,
        localeName: 'en',
      );

      expect(region, isNull);
    });
  });

  group('firstDayOfWeekIndexProvider', () {
    Future<int> resolve(String? region) async {
      final container = ProviderContainer(
        overrides: [
          deviceRegionProvider.overrideWithValue(_FakeDeviceRegion(region)),
        ],
      );
      addTearDown(container.dispose);
      return container.read(firstDayOfWeekIndexProvider.future);
    }

    test('US region starts the week on Sunday', () async {
      expect(await resolve('US'), 0);
    });

    test('European region starts the week on Monday', () async {
      expect(await resolve('DE'), 1);
    });

    test('unknown/null region defaults to Monday', () async {
      expect(await resolve(null), 1);
    });
  });
}
