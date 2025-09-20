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

    getIt<LoggingService>().captureException(
      'DEBUG: takeScreenshot called with directory=$directory, filename=$filename',
      domain: 'ScreenshotPortalService',
      subDomain: 'takeScreenshot_start',
    );

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
      getIt<LoggingService>().captureException(
        'DEBUG: Calling portal Screenshot method',
        domain: 'ScreenshotPortalService',
        subDomain: 'calling_method',
      );

      final result = await object.callMethod(
        ScreenshotPortalConstants.interfaceName,
        ScreenshotPortalConstants.screenshotMethod,
        [
          const DBusString(''), // parent_window (empty for root)
          DBusDict.stringVariant(options),
        ],
      ).timeout(PortalConstants.responseTimeout);

      if (result.returnValues.isEmpty) {
        throw Exception('Screenshot portal returned no response');
      }

      // Extract the request handle from the response
      final requestHandle = result.returnValues.first as DBusObjectPath;

      getIt<LoggingService>().captureException(
        'DEBUG: Got request handle: ${requestHandle.value}',
        domain: 'ScreenshotPortalService',
        subDomain: 'request_handle',
      );

      // Create a completer to wait for the response signal
      final completer = Completer<String?>();

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
          getIt<LoggingService>().captureException(
            'DEBUG: Received signal with ${signal.values.length} values',
            domain: 'ScreenshotPortalService',
            subDomain: 'signal_received',
          );

          // Parse the response signal
          if (signal.values.length >= 2) {
            final code = signal.values[0].asUint32();
            final results = signal.values[1].asDict();

            getIt<LoggingService>().captureException(
              'DEBUG: Response code=$code, results keys=${results.keys.map((k) => k.asString()).join(", ")}',
              domain: 'ScreenshotPortalService',
              subDomain: 'signal_parsed',
            );

            if (code == 0) {
              // Success - extract the URI from results
              final uriValue = results[const DBusString('uri')];

              // The value might be a DBusVariant containing a DBusString
              String? uri;
              if (uriValue is DBusVariant) {
                final innerValue = uriValue.value;
                if (innerValue is DBusString) {
                  uri = innerValue.value;
                }
              } else if (uriValue is DBusString) {
                uri = uriValue.value;
              }

              getIt<LoggingService>().captureException(
                'DEBUG: uriValue type=${uriValue?.runtimeType}, uri=$uri',
                domain: 'ScreenshotPortalService',
                subDomain: 'uri_type',
              );

              if (uri != null) {
                getIt<LoggingService>().captureException(
                  'DEBUG: Got URI: $uri',
                  domain: 'ScreenshotPortalService',
                  subDomain: 'uri_received',
                );

                // Convert file:// URI to local file system path
                if (uri.startsWith('file://')) {
                  final path = Uri.parse(uri).toFilePath();
                  completer.complete(path);
                } else {
                  completer.complete(null);
                }
              } else {
                getIt<LoggingService>().captureException(
                  'DEBUG: Could not extract URI from results',
                  domain: 'ScreenshotPortalService',
                  subDomain: 'no_uri',
                );
                completer.complete(null);
              }
            } else {
              // Non-zero code indicates failure
              getIt<LoggingService>().captureException(
                'DEBUG: Portal returned non-zero code: $code',
                domain: 'ScreenshotPortalService',
                subDomain: 'non_zero_code',
              );
              completer.complete(null);
            }
          } else {
            completer.complete(null);
          }
        } catch (e) {
          getIt<LoggingService>().captureException(
            'DEBUG: Error in signal handler: $e',
            domain: 'ScreenshotPortalService',
            subDomain: 'signal_error',
          );
          completer.completeError(e);
        }
      });

      try {
        // Wait for the response with timeout
        final screenshotPath = await completer.future.timeout(
          PortalConstants.responseTimeout,
          onTimeout: () {
            throw Exception('Screenshot portal request timed out');
          },
        );

        return screenshotPath;
      } finally {
        // Clean up signal subscription
        await signalSubscription.cancel();
      }
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
