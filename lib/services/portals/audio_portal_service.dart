import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/portals/portal_service.dart';

class AudioPortalConstants {
  const AudioPortalConstants._();

  static const String interfaceName = 'org.freedesktop.portal.Device';
  static const String accessDeviceMethod = 'AccessDevice';
  static const String microphoneDevice = 'microphone';
  static const String cameraDevice = 'camera';
  static const String speakersDevice = 'speakers';
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

      // Get calling app PID
      final pidValue = DBusUint32(pid);

      // Call the access device method for microphone
      final result = await object.callMethod(
        AudioPortalConstants.interfaceName,
        AudioPortalConstants.accessDeviceMethod,
        [
          pidValue, // PID of the calling process
          DBusArray.string(
              [AudioPortalConstants.microphoneDevice]), // Device identifiers
          DBusDict.stringVariant(options),
        ],
      ).timeout(PortalConstants.responseTimeout);

      if (result.returnValues.isEmpty) {
        throw Exception('Audio portal returned no response');
      }

      // Extract the request handle from the response
      final requestHandle = result.returnValues.first as DBusObjectPath;

      // Create a completer to wait for the response signal
      final completer = Completer<bool>();

      // Set up signal subscription for the Response signal
      final signalStream = DBusSignalStream(
        client,
        interface: 'org.freedesktop.portal.Request',
        name: 'Response',
        path: requestHandle,
        signature: DBusSignature('ua{sv}'),
      );

      final signalSubscription = signalStream.listen((DBusSignal signal) {
        try {
          // Parse the response signal
          if (signal.values.isNotEmpty) {
            final code = signal.values[0].asUint32();
            // Response code 0 means success
            if (code == 0) {
              _hasAudioAccess = true;
              completer.complete(true);
            } else {
              completer.complete(false);
            }
          } else {
            completer.complete(false);
          }
        } catch (e) {
          completer.completeError(e);
        }
      });

      // Wait for the response with timeout
      try {
        return await completer.future.timeout(
          PortalConstants.responseTimeout,
          onTimeout: () {
            throw TimeoutException('Audio portal response timed out');
          },
        );
      } finally {
        // Clean up the signal subscription
        await signalSubscription.cancel();
      }
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
    // Short-circuit when not in Flatpak - assume audio is available
    if (!PortalService.shouldUsePortal) {
      return true;
    }

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
