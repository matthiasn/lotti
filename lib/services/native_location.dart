import 'package:flutter/services.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

/// One position fix from the device's own location stack.
///
/// Optional fields are null when the platform did not report a valid value,
/// rather than carrying the platform's "invalid" sentinel (Apple reports an
/// unknown course or speed as -1, and an unmeasured altitude as 0).
class NativeLocationFix {
  const NativeLocationFix({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.heading,
    this.speed,
    this.speedAccuracy,
  });

  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? heading;
  final double? speed;
  final double? speedAccuracy;
}

/// A platform's native location source.
///
/// Only open-source code sits behind this: CoreLocation on Apple platforms and
/// the AOSP `LocationManager` on Android. Google Play Services' fused location
/// provider is deliberately absent, so builds for de-Googled devices and
/// F-Droid carry no proprietary location code.
abstract interface class NativeLocationSource {
  /// Asks for permission if it has not been decided yet, then reads the
  /// current position.
  ///
  /// Returns null when the user refuses permission, location services are
  /// switched off, or the platform has no valid fix — the caller falls back to
  /// IP geolocation. Throws when the
  /// platform fails to produce a fix within [timeout].
  Future<NativeLocationFix?> currentLocation({required Duration timeout});
}

/// CoreLocation through `geolocator_apple`, on iOS and macOS.
class AppleLocationSource implements NativeLocationSource {
  AppleLocationSource({GeolocatorPlatform? platform})
    : _platform = platform ?? GeolocatorPlatform.instance;

  final GeolocatorPlatform _platform;

  @override
  Future<NativeLocationFix?> currentLocation({
    required Duration timeout,
  }) async {
    if (!await _platform.isLocationServiceEnabled()) return null;

    var permission = await _platform.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _platform.requestPermission();
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return null;
    }

    final position = await _platform.getCurrentPosition(
      locationSettings: LocationSettings(timeLimit: timeout),
    );
    // CoreLocation reports a negative horizontal accuracy when the
    // coordinates themselves are invalid; there is no fix to record.
    if (position.accuracy < 0) return null;
    return NativeLocationFix(
      latitude: position.latitude,
      longitude: position.longitude,
      // Altitude is only measured when its vertical accuracy is positive;
      // otherwise CoreLocation leaves a 0 placeholder, which is not sea level.
      altitude: position.altitudeAccuracy > 0 ? position.altitude : null,
      accuracy: position.accuracy,
      heading: _validOrNull(position.heading),
      speed: _validOrNull(position.speed),
      speedAccuracy: _validOrNull(position.speedAccuracy),
    );
  }

  /// CoreLocation marks an unknown course, speed or speed accuracy with a
  /// negative value.
  static double? _validOrNull(double value) => value < 0 ? null : value;
}

/// The AOSP `LocationManager`, through the app's own `LottiLocationPlugin`.
class AndroidLocationSource implements NativeLocationSource {
  AndroidLocationSource({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  /// Must match `LottiLocationPlugin.CHANNEL` on the Kotlin side.
  static const channelName = 'com.matthiasn.lotti/location';

  final MethodChannel _channel;

  @override
  Future<NativeLocationFix?> currentLocation({
    required Duration timeout,
  }) async {
    final fix = await _channel.invokeMapMethod<String, Object?>(
      'getCurrentLocation',
      {'timeoutMs': timeout.inMilliseconds},
    );
    if (fix == null) return null;
    return NativeLocationFix(
      latitude: _required(fix, 'latitude'),
      longitude: _required(fix, 'longitude'),
      altitude: _optional(fix, 'altitude'),
      accuracy: _optional(fix, 'accuracy'),
      heading: _optional(fix, 'heading'),
      speed: _optional(fix, 'speed'),
      speedAccuracy: _optional(fix, 'speedAccuracy'),
    );
  }

  static double _required(Map<String, Object?> fix, String key) {
    final value = fix[key];
    if (value is! num) {
      throw FormatException('Location fix is missing "$key"', fix);
    }
    return value.toDouble();
  }

  static double? _optional(Map<String, Object?> fix, String key) =>
      (fix[key] as num?)?.toDouble();
}
