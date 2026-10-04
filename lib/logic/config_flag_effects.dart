import 'package:lotti/database/database.dart';

/// What a toggled config flag sets in motion beyond being stored — today, a
/// notification preference rescheduling this device's alarms the moment it
/// flips.
///
/// Persistence lives below the features, so it applies the effects through
/// this interface. The composition root registers the notifications
/// feature's `NotificationPreferenceEffects` under it.
abstract interface class ConfigFlagEffects {
  /// Applies the consequences of [flag]'s new value.
  Future<void> apply(ConfigFlag flag);
}
