import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

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
          // Parse the response signal
          if (signal.values.length >= 2) {
            final code = signal.values[0].asUint32();
            final results = signal.values[1].asDict();

            if (code == 0) {
              // Success - extract the file path from results
              final path = ScreenshotPortalService.parseUriFromResults(results);
              completer.complete(path);
            } else {
              // Non-zero code indicates failure
              // Code 1 = User cancelled, Code 2 = Other error
              final errorMessage = code == 1
                  ? 'Screenshot cancelled by user'
                  : 'Screenshot portal returned error code: $code';

              getIt<LoggingService>().captureException(
                errorMessage,
                domain: 'ScreenshotPortalService',
                subDomain: 'portal_error',
              );
              completer.complete(null);
            }
          } else {
            completer.complete(null);
          }
        } catch (e) {
          getIt<LoggingService>().captureException(
            e,
            domain: 'ScreenshotPortalService',
            subDomain: 'signal_error',
          );
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
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

        // If we have a path and a target directory/filename, copy/move the file
        if (screenshotPath != null && directory != null && filename != null) {
          return await ScreenshotPortalService.persistScreenshot(
            screenshotPath,
            directory,
            filename,
          );
        }

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

  /// Extracts and normalizes the file path from a portal response map.
  ///
  /// The `results` map is expected to be a DBus dict keyed by `DBusString`.
  /// The URI value may be either a `DBusVariant(DBusString)` or a `DBusString`.
  /// Returns a local file system path if the URI uses the `file://` scheme,
  /// otherwise returns null.
  @visibleForTesting
  static String? parseUriFromResults(Map<DBusValue, DBusValue> results) {
    final uriValue = results[const DBusString('uri')];

    String? uri;
    if (uriValue is DBusVariant) {
      final innerValue = uriValue.value;
      if (innerValue is DBusString) {
        uri = innerValue.value;
      }
    } else if (uriValue is DBusString) {
      uri = uriValue.value;
    }

    if (uri == null) return null;
    if (!uri.startsWith('file://')) return null;

    return Uri.parse(uri).toFilePath();
  }

  /// Persists a temporary screenshot to the given directory/filename.
  ///
  /// Ensures the target directory exists, attempts a fast rename first, and
  /// falls back to a copy when a cross-device rename fails. Any failure is
  /// logged and the original `screenshotPath` is returned.
  @visibleForTesting
  static Future<String> persistScreenshot(
    String screenshotPath,
    String directory,
    String filename,
  ) async {
    try {
      final sourceFile = File(screenshotPath);
      final targetPath = p.join(directory, filename);

      // Ensure target directory exists (async)
      final targetDir = Directory(directory);
      // ignore: avoid_slow_async_io
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Try fast move first, fall back to copy if rename across devices fails
      try {
        await sourceFile.rename(targetPath);
      } catch (_) {
        await sourceFile.copy(targetPath);
      }

      return targetPath;
    } catch (e, st) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'ScreenshotPortalService',
        subDomain: 'file_copy_error',
        stackTrace: st,
      );
      return screenshotPath;
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
