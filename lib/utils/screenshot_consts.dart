/// Screenshot-related constants and configuration
///
/// This file contains all constants related to screenshot functionality,
/// including tool names, file extensions, error messages, and timing values.
/// Following the codebase pattern of centralized constants for maintainability.
library;

// File and path constants
const String screenshotFileExtension = '.screenshot.jpg';

/// Relative path for screenshot storage within the app's documents directory.
/// This ensures compatibility with sandboxed environments (Snap, Flatpak, macOS, Windows)
/// where absolute paths like '/images/' are not writable.
/// The actual full path is constructed by createAssetDirectory() using the platform's
/// documents directory + this relative path.
const String screenshotDirectoryPath = 'images/';

const String screenshotDateFormat = 'yyyy-MM-dd';

// Timing constants
const int screenshotDelaySeconds = 1;
const int screenshotProcessTimeoutSeconds = 30;

/// Window minimization delay to ensure proper window state before screenshot
const int windowMinimizationDelayMs = 500;

// Domain constants for logging
const String screenshotDomain = 'SCREENSHOT';

// D-Bus portal constants
const String dbusPortalDesktopName = 'org.freedesktop.portal.Desktop';
const String dbusPortalDesktopPath = '/org/freedesktop/portal/desktop';
const String dbusPortalScreenshotInterface =
    'org.freedesktop.portal.Screenshot';
const String dbusPortalRequestInterface = 'org.freedesktop.portal.Request';
const String dbusPortalResponseSignal = 'Response';

// Portal option keys
const String portalHandleTokenKey = 'handle_token';
const String portalModalKey = 'modal';
const String portalInteractiveKey = 'interactive';
const String portalUriKey = 'uri';

// Token generation format
const String screenshotTokenPrefix = 'lotti_screenshot_';

// Portal response codes
const int portalSuccessResponse = 0;

// Linux screenshot tools (in order of preference)
const String spectacleTool = 'spectacle';
const String gnomeScreenshotTool = 'gnome-screenshot';
const String scrotTool = 'scrot';
const String importTool = 'import';

// macOS screenshot tool
const String screencaptureTool = 'screencapture';

// System commands
const String whichCommand = 'which';

// Tool-specific arguments
const List<String> spectacleArguments = ['-f', '-b', '-n', '-o'];
const List<String> gnomeScreenshotArguments = ['-f'];
const List<String> scrotArguments = [];
const List<String> importArguments = ['-window', 'root'];
const List<String> screencaptureArguments = ['-tjpg'];

// Error messages
const String noScreenshotToolAvailableMessage =
    'No screenshot tool available. Please install one of: ';
const String installInstructionsMessage = 'You can install them with:\n'
    '  sudo apt install spectacle (KDE)\n'
    '  sudo apt install gnome-screenshot (GNOME)\n'
    '  sudo apt install scrot (lightweight)\n'
    '  sudo apt install imagemagick (for import command)';

const String unsupportedToolMessage = 'Unsupported screenshot tool: ';
const String toolFailedMessage = 'Screenshot tool ';
const String failedWithExitCodeMessage = ' failed with exit code ';
const String screencaptureFailedMessage =
    'macOS screencapture failed with exit code ';
const String unsupportedPlatformMessage =
    'Screenshot functionality is not supported on ';

// Flatpak portal specific error messages
const String portalNoUriMessage = 'Screenshot succeeded but no URI provided';
const String portalUnexpectedUriMessage = 'Unexpected screenshot URI format: ';
const String portalFileNotFoundMessage = 'Screenshot file not found at: ';
const String portalTimeoutMessage = 'Screenshot portal timed out after ';
const String portalCancelledMessage = 'Screenshot cancelled or failed: ';

// File URI constants
const String fileUriScheme = 'file://';

// Process configuration
/// Set to false to prevent shell injection vulnerabilities.
/// Since we use Process.start() with direct executable and argument lists,
/// we don't need shell features and this provides better security.
const bool runInShell = false;
const int successExitCode = 0;

/// List of Linux screenshot tools to try in order of preference
const List<String> linuxScreenshotTools = [
  spectacleTool,
  gnomeScreenshotTool,
  scrotTool,
  importTool,
];

/// Screenshot tool configuration
class ScreenshotToolConfig {
  const ScreenshotToolConfig({
    required this.name,
    required this.arguments,
    required this.description,
    required this.installCommand,
  });

  final String name;
  final List<String> arguments;
  final String description;
  final String installCommand;
}

/// Configuration for each screenshot tool
const Map<String, ScreenshotToolConfig> screenshotToolConfigs = {
  spectacleTool: ScreenshotToolConfig(
    name: 'Spectacle',
    arguments: spectacleArguments,
    description: 'KDE screenshot tool',
    installCommand: 'sudo apt install spectacle',
  ),
  gnomeScreenshotTool: ScreenshotToolConfig(
    name: 'GNOME Screenshot',
    arguments: gnomeScreenshotArguments,
    description: 'GNOME screenshot tool',
    installCommand: 'sudo apt install gnome-screenshot',
  ),
  scrotTool: ScreenshotToolConfig(
    name: 'Scrot',
    arguments: scrotArguments,
    description: 'Lightweight screenshot tool',
    installCommand: 'sudo apt install scrot',
  ),
  importTool: ScreenshotToolConfig(
    name: 'ImageMagick Import',
    arguments: importArguments,
    description: 'ImageMagick screenshot tool',
    installCommand: 'sudo apt install imagemagick',
  ),
};
