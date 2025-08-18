import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/portals/portal_service.dart';

class ScreenshotPortalConstants {
  const ScreenshotPortalConstants._();
  
  static const String interfaceName = 'org.freedesktop.portal.Screenshot';
  static const String screenshotMethod = 'Screenshot';
  static const String pickColorMethod = 'PickColor';
}

/// Service for taking screenshots using the XDG Desktop Portal
/// This allows screenshots to work in sandboxed environments like Flatpak
class ScreenshotPortalService extends PortalService {
  factory ScreenshotPortalService() => _instance;
  
  ScreenshotPortalService._();

  static final ScreenshotPortalService _instance = ScreenshotPortalService._();

  /// Takes a screenshot using the portal
  /// Returns the path to the saved screenshot file
  Future<String?> takeScreenshot({
    bool interactive = false,
    String? directory,
    String? filename,
  }) async {
    if (!PortalService.shouldUsePortal) {
      throw UnsupportedError(
        'Screenshot portal should only be used in Flatpak environment',
      );
    }

    await initialize();

    try {
      final object = createPortalObject();

      // Options for the screenshot
      final options = <String, DBusValue>{
        'handle_token': DBusString(
          PortalService.createHandleToken('screenshot'),
        ),
      };

      if (interactive) {
        options['interactive'] = const DBusBoolean(true);
      }

      // Call the screenshot method
      final result = await object
          .callMethod(
            ScreenshotPortalConstants.interfaceName,
            ScreenshotPortalConstants.screenshotMethod,
            [
              const DBusString(''), // parent_window (empty for root)
              DBusDict.stringVariant(options),
            ],
          )
          .timeout(PortalConstants.responseTimeout);

      if (result.returnValues.isEmpty) {
        throw Exception('Screenshot portal returned no response');
      }

      // For simplicity, we'll use a basic approach without signal listening
      // In a real portal implementation, you would listen for the Response signal
      // For now, we'll return null to indicate portal screenshot is not fully implemented
      getIt<LoggingService>().captureException(
        Exception(
          'Portal screenshot implementation is incomplete - signal listening not implemented',
        ),
        domain: 'ScreenshotPortalService',
        subDomain: 'takeScreenshot',
      );
      
      return null;
    } catch (e, stackTrace) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'ScreenshotPortalService',
        subDomain: 'takeScreenshot',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Checks if the screenshot portal is available
  static Future<bool> isAvailable() async {
    return PortalService.isInterfaceAvailable(
      ScreenshotPortalConstants.interfaceName,
      ScreenshotPortalService(),
      'ScreenshotPortalService',
    );
  }
}
