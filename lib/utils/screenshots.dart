import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/screenshot_consts.dart';
import 'package:path/path.dart' as path;
import 'package:window_manager/window_manager.dart';

/// Checks if we're running in a Flatpak environment
bool isRunningInFlatpak() {
  // Check for Flatpak-specific environment variables or files
  return Platform.environment.containsKey('FLATPAK_ID') ||
      File('/.flatpak-info').existsSync();
}

/// Safely restores the window, ignoring any errors during restoration
Future<void> _safelyRestoreWindow() async {
  try {
    await windowManager.show();
  } catch (_) {
    // Ignore errors during window restoration
    // This ensures the function is safe to call in error handling paths
  }
}

/// Validates that the D-Bus portal service is available
Future<bool> _isPortalAvailable() async {
  try {
    final client = DBusClient.session();
    try {
      final portal = DBusRemoteObject(
        client,
        name: dbusPortalDesktopName,
        path: DBusObjectPath(dbusPortalDesktopPath),
      );

      // Try to introspect the portal to see if it's available
      await portal.introspect();
      return true;
    } finally {
      await client.close();
    }
  } catch (_) {
    return false;
  }
}

/// Checks if a command is available on the system
Future<bool> isCommandAvailable(String command) async {
  try {
    final result = await Process.run(whichCommand, [command]);
    return result.exitCode == successExitCode;
  } catch (e) {
    return false;
  }
}

/// Finds the first available screenshot tool on Linux
Future<String?> findAvailableScreenshotTool() async {
  for (final tool in linuxScreenshotTools) {
    if (await isCommandAvailable(tool)) {
      return tool;
    }
  }
  return null;
}

/// Takes a screenshot using the specified Linux tool
Future<void> takeLinuxScreenshot(
    String tool, String filename, String directory) async {
  final config = screenshotToolConfigs[tool];
  if (config == null) {
    throw Exception('$unsupportedToolMessage$tool');
  }

  final arguments = [...config.arguments, filename];

  final process = await Process.start(
    tool,
    arguments,
    workingDirectory: directory,
  );

  await stdout.addStream(process.stdout);
  await stderr.addStream(process.stderr);

  final exitCode = await process.exitCode.timeout(
    const Duration(seconds: screenshotProcessTimeoutSeconds),
    onTimeout: () {
      process.kill();
      throw Exception(
          '$toolFailedMessage$tool timed out after ${screenshotProcessTimeoutSeconds}s');
    },
  );

  if (exitCode != successExitCode) {
    throw Exception(
        '$toolFailedMessage$tool$failedWithExitCodeMessage$exitCode');
  }
}

/// Takes a screenshot using the Flatpak portal
Future<ImageData> takeFlatpakPortalScreenshot() async {
  try {
    // Validate portal availability first
    if (!await _isPortalAvailable()) {
      throw Exception('D-Bus screenshot portal is not available');
    }

    final id = uuid.v1();
    final filename = '$id$screenshotFileExtension';
    final created = DateTime.now();
    final day = DateFormat(screenshotDateFormat).format(created);
    final relativePath = '$screenshotDirectoryPath$day/';
    final directory = await createAssetDirectory(relativePath);
    final fullPath = path.join(directory, filename);

    // Minimize window before taking screenshot
    await windowManager.minimize();

    // Add a small delay to ensure window is fully minimized
    await Future<void>.delayed(
        const Duration(milliseconds: windowMinimizationDelayMs));

    // Connect to D-Bus session bus
    final client = DBusClient.session();

    getIt<LoggingService>().captureEvent(
      'Starting Flatpak screenshot portal request',
      domain: screenshotDomain,
    );

    try {
      // Create a unique token for this request
      final token =
          '$screenshotTokenPrefix${DateTime.now().millisecondsSinceEpoch}';

      // Call the Screenshot portal
      final portal = DBusRemoteObject(
        client,
        name: dbusPortalDesktopName,
        path: DBusObjectPath(dbusPortalDesktopPath),
      );

      // Prepare options for the screenshot
      final options = <String, DBusValue>{
        portalHandleTokenKey: DBusString(token),
        portalModalKey: const DBusBoolean(false),
        portalInteractiveKey: const DBusBoolean(false),
      };

      // Call Screenshot method
      final result = await portal.callMethod(
        dbusPortalScreenshotInterface,
        'Screenshot',
        [
          const DBusString(''), // parent_window - empty for non-interactive
          DBusDict.stringVariant(options),
        ],
        replySignature: DBusSignature('o'),
      );

      // Get the request path
      final requestPath = (result.values[0] as DBusObjectPath).value;

      // Wait for the response signal
      final completer = Completer<String>();

      // Subscribe to Response signal using DBusSignalStream
      final signalStream = DBusSignalStream(
        client,
        sender: dbusPortalDesktopName,
        path: DBusObjectPath(requestPath),
        interface: dbusPortalRequestInterface,
        name: dbusPortalResponseSignal,
      );

      final subscription = signalStream.listen((signal) {
        if (signal.values.length >= 2) {
          final response = signal.values[0] as DBusUint32;
          final results = signal.values[1] as DBusDict;

          if (response.value == portalSuccessResponse) {
            // Success - extract URI from results dictionary
            final resultsMap = results.asStringVariantDict();
            final uriVariant = resultsMap[portalUriKey];
            if (uriVariant != null) {
              final uri = (uriVariant as DBusString).value;
              getIt<LoggingService>().captureEvent(
                'Screenshot portal succeeded with URI: $uri',
                domain: screenshotDomain,
              );
              completer.complete(uri);
            } else {
              completer.completeError(
                Exception(portalNoUriMessage),
              );
            }
          } else {
            // User cancelled or error
            getIt<LoggingService>().captureEvent(
              'Screenshot portal failed with response: ${response.value}',
              domain: screenshotDomain,
            );
            completer.completeError(
              Exception('$portalCancelledMessage${response.value}'),
            );
          }
        }
      });

      // Wait for the result with timeout
      final screenshotUri = await completer.future.timeout(
        const Duration(seconds: screenshotProcessTimeoutSeconds),
        onTimeout: () {
          subscription.cancel();
          throw TimeoutException(
            '$portalTimeoutMessage${screenshotProcessTimeoutSeconds}s',
          );
        },
      );

      await subscription.cancel();

      // Copy the screenshot file to our directory
      // The URI is typically file:///path/to/screenshot.png
      if (screenshotUri.startsWith(fileUriScheme)) {
        final sourcePath = Uri.parse(screenshotUri).toFilePath();
        final sourceFile = File(sourcePath);

        if (sourceFile.existsSync()) {
          // Read the source file and write to our destination
          await sourceFile.copy(fullPath);

          // Clean up the temporary file
          try {
            await sourceFile.delete();
          } catch (_) {
            // Ignore deletion errors
          }
        } else {
          throw Exception('$portalFileNotFoundMessage$sourcePath');
        }
      } else {
        throw Exception('$portalUnexpectedUriMessage$screenshotUri');
      }

      final imageData = ImageData(
        imageId: id,
        imageFile: filename,
        imageDirectory: relativePath,
        capturedAt: created,
      );

      // Restore window after screenshot
      await _safelyRestoreWindow();

      return imageData;
    } finally {
      await client.close();
    }
  } catch (exception, stackTrace) {
    // Ensure window is restored even on error
    await _safelyRestoreWindow();

    getIt<LoggingService>().captureException(
      exception,
      domain: screenshotDomain,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

Future<ImageData> takeScreenshot() async {
  try {
    // Check if running in Flatpak and use portal if so
    if (isRunningInFlatpak()) {
      getIt<LoggingService>().captureEvent(
        'Using Flatpak screenshot portal',
        domain: screenshotDomain,
      );
      return takeFlatpakPortalScreenshot();
    }

    final id = uuid.v1();
    final filename = '$id$screenshotFileExtension';
    final created = DateTime.now();
    final day = DateFormat(screenshotDateFormat).format(created);
    final relativePath = '$screenshotDirectoryPath$day/';
    final directory = await createAssetDirectory(relativePath);

    await windowManager.minimize();

    await Future<void>.delayed(const Duration(seconds: screenshotDelaySeconds));

    if (Platform.isMacOS) {
      final process = await Process.start(
        screencaptureTool,
        [...screencaptureArguments, filename],
        workingDirectory: directory,
      );

      await stdout.addStream(process.stdout);
      await stderr.addStream(process.stderr);

      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: screenshotProcessTimeoutSeconds),
        onTimeout: () {
          process.kill();
          throw Exception(
              'macOS screencapture timed out after ${screenshotProcessTimeoutSeconds}s');
        },
      );

      if (exitCode != successExitCode) {
        throw Exception('$screencaptureFailedMessage$exitCode');
      }
    } else if (Platform.isLinux) {
      final availableTool = await findAvailableScreenshotTool();

      if (availableTool == null) {
        final availableTools = linuxScreenshotTools.join(', ');
        throw Exception('$noScreenshotToolAvailableMessage$availableTools\n'
            '$installInstructionsMessage');
      }

      await takeLinuxScreenshot(availableTool, filename, directory);
    } else {
      throw UnsupportedError(
          '$unsupportedPlatformMessage${Platform.operatingSystem}');
    }

    final imageData = ImageData(
      imageId: id,
      imageFile: filename,
      imageDirectory: relativePath,
      capturedAt: created,
    );

    await _safelyRestoreWindow();

    return imageData;
  } catch (exception, stackTrace) {
    getIt<LoggingService>().captureException(
      exception,
      domain: screenshotDomain,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
