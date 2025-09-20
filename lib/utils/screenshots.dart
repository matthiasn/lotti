import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:lotti/services/portals/screenshot_portal_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/screenshot_consts.dart';
import 'package:window_manager/window_manager.dart';

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

Future<ImageData> takeScreenshot() async {
  try {
    final id = uuid.v1();
    final filename = '$id$screenshotFileExtension';
    final created = DateTime.now();
    final day = DateFormat(screenshotDateFormat).format(created);
    final relativePath = '$screenshotDirectoryPath$day/';
    final directory = await createAssetDirectory(relativePath);

    // Debug logging for portal detection
    getIt<LoggingService>().captureException(
      'DEBUG: Screenshot portal check - Linux=${Platform.isLinux}, '
      'FLATPAK_ID=${Platform.environment['FLATPAK_ID']}, '
      'container=${Platform.environment['container']}, '
      'shouldUsePortal=${PortalService.shouldUsePortal}',
      domain: screenshotDomain,
      subDomain: 'portal_debug',
    );

    // Check if we should use portal (Flatpak environment)
    if (Platform.isLinux && PortalService.shouldUsePortal) {
      getIt<LoggingService>().captureException(
        'DEBUG: Attempting to use portal service',
        domain: screenshotDomain,
        subDomain: 'portal_attempt',
      );
      final portalService = ScreenshotPortalService();

      // Check if portal is available
      final isAvailable = await ScreenshotPortalService.isAvailable();
      getIt<LoggingService>().captureException(
        'DEBUG: Portal isAvailable = $isAvailable',
        domain: screenshotDomain,
        subDomain: 'portal_available',
      );

      if (isAvailable) {
        getIt<LoggingService>().captureException(
          'DEBUG: Calling portal.takeScreenshot()',
          domain: screenshotDomain,
          subDomain: 'portal_call',
        );
        final screenshotPath = await portalService.takeScreenshot(
          directory: directory,
          filename: filename,
          interactive: true,
        );
        getIt<LoggingService>().captureException(
          'DEBUG: Portal returned path = $screenshotPath',
          domain: screenshotDomain,
          subDomain: 'portal_result',
        );

        if (screenshotPath != null) {
          final imageData = ImageData(
            imageId: id,
            imageFile: filename,
            imageDirectory: relativePath,
            capturedAt: created,
          );
          return imageData;
        }
      }

      // If portal fails, fall through to traditional methods
      getIt<LoggingService>().captureException(
        Exception(
            'Screenshot portal failed, falling back to traditional methods'),
        domain: screenshotDomain,
        subDomain: 'portal_fallback',
      );
    }

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

    return imageData;
  } catch (exception, stackTrace) {
    getIt<LoggingService>().captureException(
      exception,
      domain: screenshotDomain,
      stackTrace: stackTrace,
    );
    rethrow;
  } finally {
    // Always restore the window, regardless of success or failure
    try {
      await windowManager.show();
    } catch (e) {
      // Log but don't rethrow window restoration errors
      getIt<LoggingService>().captureException(
        e,
        domain: screenshotDomain,
        subDomain: 'window_restoration',
      );
    }
  }
}
