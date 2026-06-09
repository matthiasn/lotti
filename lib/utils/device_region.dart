import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/utils/first_day_of_week.dart';

@visibleForTesting
const deviceRegionChannelName = 'com.matthiasn.lotti/device_region';

const _deviceRegionChannel = MethodChannel(deviceRegionChannelName);

/// Resolves the device's ISO-3166 region (e.g. `DE`, `US`).
///
/// macOS hides the System-Settings *Region* from Flutter's locale APIs —
/// both `PlatformDispatcher.locales` and `Platform.localeName` report the UI
/// *language* (often `en_US`), never the region — so on macOS the region is
/// fetched natively over [deviceRegionChannelName]. Every other platform
/// carries the region in [Platform.localeName].
class DeviceRegion {
  const DeviceRegion({this.methodChannel = _deviceRegionChannel});

  final MethodChannel methodChannel;

  /// The device region, or null when it cannot be determined.
  ///
  /// [isMacOS] and [localeName] are injectable seams for tests; in
  /// production they default to the running platform.
  Future<String?> regionCode({bool? isMacOS, String? localeName}) async {
    final macOS = isMacOS ?? Platform.isMacOS;
    if (macOS) {
      try {
        final code = await methodChannel.invokeMethod<String>('getRegionCode');
        if (code != null && code.trim().isNotEmpty) return code.trim();
      } on Object {
        // Channel missing or failed — fall through to locale-name parsing.
      }
    }
    return regionFromLocaleName(localeName ?? Platform.localeName);
  }
}

/// The platform region resolver. Overridden in tests.
final deviceRegionProvider = Provider<DeviceRegion>(
  (ref) => const DeviceRegion(),
  name: 'deviceRegionProvider',
);

/// First weekday (`0 = Sunday` … `6 = Saturday`) for the device region.
///
/// Resolves the region via [deviceRegionProvider] and maps it through the
/// CLDR table, so US devices start the week on Sunday while European devices
/// start on Monday. Defaults to Monday for unknown regions.
final firstDayOfWeekIndexProvider = FutureProvider<int>((ref) async {
  final region = await ref.watch(deviceRegionProvider).regionCode();
  return firstDayOfWeekIndexForCountry(region);
}, name: 'firstDayOfWeekIndexProvider');
