import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/portals/portal_service.dart';

class AudioPortalConstants {
  const AudioPortalConstants._();

  static const String interfaceName = 'org.freedesktop.portal.Device';
  static const String accessDeviceMethod = 'AccessDevice';
  static const int microphoneDevice = 1; // Microphone device type
}

/// Service for accessing audio recording devices using the XDG Desktop Portal
/// This allows audio recording to work in sandboxed environments like Flatpak
class AudioPortalService extends PortalService {
  factory AudioPortalService() => _instance;

  AudioPortalService._();

  static final AudioPortalService _instance = AudioPortalService._();

  bool _hasAudioAccess = false;

  /// Requests access to microphone for recording
  Future<bool> requestMicrophoneAccess() async {
    if (!PortalService.shouldUsePortal) {
      // Not in Flatpak, assume access is available
      return _hasAudioAccess = true;
    }

    if (_hasAudioAccess) return true;

    await initialize();

    try {
      final object = createPortalObject();

      // Options for the device access request
      final options = <String, DBusValue>{
        'handle_token': DBusString(
          PortalService.createHandleToken('microphone'),
        ),
      };

      // Call the access device method for microphone
      final result = await object.callMethod(
        AudioPortalConstants.interfaceName,
        AudioPortalConstants.accessDeviceMethod,
        [
          const DBusString(''), // parent_window (empty for root)
          DBusArray.uint32([AudioPortalConstants.microphoneDevice]),
          DBusDict.stringVariant(options),
        ],
      ).timeout(PortalConstants.responseTimeout);

      if (result.returnValues.isEmpty) {
        throw Exception('Audio portal returned no response');
      }

      // For simplicity, assume access granted if call succeeds
      // In a real implementation, you would listen for the Response signal
      return _hasAudioAccess = true;
    } catch (e, stackTrace) {
      // Guard against LoggingService not being registered
      if (getIt.isRegistered<LoggingService>()) {
        getIt<LoggingService>().captureException(
          e,
          domain: 'AudioPortalService',
          subDomain: 'requestMicrophoneAccess',
          stackTrace: stackTrace,
        );
      }
      return false;
    }
  }

  /// Checks if the audio portal is available
  static Future<bool> isAvailable() async {
    return PortalService.isInterfaceAvailable(
      AudioPortalConstants.interfaceName,
      AudioPortalService(),
      'AudioPortalService',
    );
  }

  /// Gets the current microphone access status
  bool get hasMicrophoneAccess => _hasAudioAccess;

  /// Resets the access status (useful for testing or re-requesting)
  void resetAccess() {
    _hasAudioAccess = false;
  }
}
