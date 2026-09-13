import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:lotti/services/portals/screenshot_portal_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/screenshot_consts.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

/// Operating-system boundary for screenshot capture.
///
/// Keeping these effects together lets callers exercise capture and recovery
/// without launching desktop tools or changing the real application window.
class ScreenshotHost {
  const ScreenshotHost();

  String get operatingSystem => Platform.operatingSystem;
  bool get shouldUsePortal => PortalService.shouldUsePortal;

  Future<bool> isPortalAvailable() => ScreenshotPortalService.isAvailable();

  Future<String?> captureWithPortal({
    required String directory,
    required String filename,
  }) => ScreenshotPortalService().takeScreenshot(
    directory: directory,
    filename: filename,
    interactive: true,
  );

  Future<String> createDirectory(String relativePath) =>
      createAssetDirectory(relativePath);

  Future<void> minimizeWindow() => windowManager.minimize();
  Future<void> showWindow() => windowManager.show();

  Future<ProcessResult> run(String command, List<String> arguments) =>
      Process.run(command, arguments);

  Future<Process> start(
    String command,
    List<String> arguments, {
    required String workingDirectory,
  }) => Process.start(command, arguments, workingDirectory: workingDirectory);

  Future<void> forwardOutput(Process process) async {
    await Future.wait<void>([
      stdout.addStream(process.stdout),
      stderr.addStream(process.stderr),
    ]);
  }
}

/// Checks if a command is available on the system
Future<bool> isCommandAvailable(
  String command, {
  ScreenshotHost host = const ScreenshotHost(),
}) async {
  try {
    final result = await host.run(whichCommand, [command]);
    return result.exitCode == successExitCode;
  } catch (e) {
    return false;
  }
}

/// Finds the first available screenshot tool on Linux
Future<String?> findAvailableScreenshotTool({
  ScreenshotHost host = const ScreenshotHost(),
}) async {
  for (final tool in linuxScreenshotTools) {
    if (await isCommandAvailable(tool, host: host)) {
      return tool;
    }
  }
  return null;
}

/// Takes a screenshot using the specified Linux tool
Future<void> takeLinuxScreenshot(
  String tool,
  String filename,
  String directory, {
  ScreenshotHost host = const ScreenshotHost(),
}) async {
  final config = screenshotToolConfigs[tool];
  if (config == null) {
    throw Exception('$unsupportedToolMessage$tool');
  }

  final arguments = [...config.arguments, filename];

  final process = await host.start(
    tool,
    arguments,
    workingDirectory: directory,
  );

  final exitCode = await _waitForCaptureProcess(
    process,
    host,
    '$toolFailedMessage$tool timed out after ${screenshotProcessTimeoutSeconds}s',
  );

  if (exitCode != successExitCode) {
    throw Exception(
      '$toolFailedMessage$tool$failedWithExitCodeMessage$exitCode',
    );
  }
}

/// Returns the canonical documents-relative directory for [created].
String screenshotRelativePath(DateTime created) {
  final day = DateFormat(screenshotDateFormat).format(created);
  return '${p.posix.join(screenshotDirectoryPath, day)}/';
}

/// Captures an image and restores the window even if capture fails.
Future<ImageData> takeScreenshot({
  ScreenshotHost host = const ScreenshotHost(),
}) async {
  try {
    final id = uuid.v1();
    final filename = '$id$screenshotFileExtension';
    final created = clock.now();
    final relativePath = screenshotRelativePath(created);
    final directory = await host.createDirectory(relativePath);

    // Check if we should use portal (Flatpak environment)
    if (host.operatingSystem == 'linux' && host.shouldUsePortal) {
      // Check if portal is available
      if (await host.isPortalAvailable()) {
        final screenshotPath = await host.captureWithPortal(
          directory: directory,
          filename: filename,
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
      getIt<DomainLogger>().error(
        LogDomain.screenshots,
        Exception(
          'Screenshot portal failed, falling back to traditional methods',
        ),
        subDomain: 'portal_fallback',
      );
    }

    await host.minimizeWindow();
    await Future<void>.delayed(const Duration(seconds: screenshotDelaySeconds));

    if (host.operatingSystem == 'macos') {
      final process = await host.start(
        screencaptureTool,
        [...screencaptureArguments, filename],
        workingDirectory: directory,
      );

      final exitCode = await _waitForCaptureProcess(
        process,
        host,
        'macOS screencapture timed out after ${screenshotProcessTimeoutSeconds}s',
      );

      if (exitCode != successExitCode) {
        throw Exception('$screencaptureFailedMessage$exitCode');
      }
    } else if (host.operatingSystem == 'linux') {
      final availableTool = await findAvailableScreenshotTool(host: host);

      if (availableTool == null) {
        final availableTools = linuxScreenshotTools.join(', ');
        throw Exception(
          '$noScreenshotToolAvailableMessage$availableTools\n'
          '$installInstructionsMessage',
        );
      }

      await takeLinuxScreenshot(availableTool, filename, directory, host: host);
    } else {
      throw UnsupportedError(
        '$unsupportedPlatformMessage${host.operatingSystem}',
      );
    }

    final imageData = ImageData(
      imageId: id,
      imageFile: filename,
      imageDirectory: relativePath,
      capturedAt: created,
    );

    return imageData;
  } catch (exception, stackTrace) {
    getIt<DomainLogger>().error(
      LogDomain.screenshots,
      exception,
      stackTrace: stackTrace,
    );
    rethrow;
  } finally {
    // Always restore the window, regardless of success or failure
    try {
      await host.showWindow();
    } catch (e) {
      // Log but don't rethrow window restoration errors
      getIt<DomainLogger>().error(
        LogDomain.screenshots,
        e,
        subDomain: 'window_restoration',
      );
    }
  }
}

/// Bounds the whole process wait, including streams a hung process leaves open.
Future<int> _waitForCaptureProcess(
  Process process,
  ScreenshotHost host,
  String timeoutMessage,
) async {
  final exitCode = process.exitCode;
  await Future.wait<Object?>([
    host.forwardOutput(process),
    exitCode,
  ]).timeout(
    const Duration(seconds: screenshotProcessTimeoutSeconds),
    onTimeout: () {
      process.kill();
      throw Exception(timeoutMessage);
    },
  );
  return exitCode;
}
