import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/screenshot_consts.dart';

void main() {
  group('Screenshot Constants', () {
    group('File and Path Constants', () {
      test('should have correct file extension', () {
        expect(screenshotFileExtension, equals('.screenshot.jpg'));
      });

      test('should have correct directory path', () {
        expect(screenshotDirectoryPath, equals('images/'));
      });

      test('should have correct date format', () {
        expect(screenshotDateFormat, equals('yyyy-MM-dd'));
      });
    });

    group('Timing Constants', () {
      test('should have positive delay seconds', () {
        expect(screenshotDelaySeconds, isPositive);
        expect(screenshotDelaySeconds, isA<int>());
      });

      test('should have positive process timeout seconds', () {
        expect(screenshotProcessTimeoutSeconds, isPositive);
        expect(screenshotProcessTimeoutSeconds, isA<int>());
      });

      test('should have reasonable timeout values', () {
        expect(screenshotDelaySeconds, greaterThan(0));
        expect(screenshotProcessTimeoutSeconds,
            greaterThan(screenshotDelaySeconds));
      });
    });

    group('Domain Constants', () {
      test('should have correct screenshot domain', () {
        expect(screenshotDomain, equals('SCREENSHOT'));
      });
    });

    group('Linux Screenshot Tools', () {
      test('should have all expected Linux tools', () {
        expect(linuxScreenshotTools, contains(spectacleTool));
        expect(linuxScreenshotTools, contains(gnomeScreenshotTool));
        expect(linuxScreenshotTools, contains(scrotTool));
        expect(linuxScreenshotTools, contains(importTool));
      });

      test('should have correct tool names', () {
        expect(spectacleTool, equals('spectacle'));
        expect(gnomeScreenshotTool, equals('gnome-screenshot'));
        expect(scrotTool, equals('scrot'));
        expect(importTool, equals('import'));
      });

      test('should have correct macOS tool name', () {
        expect(screencaptureTool, equals('screencapture'));
      });

      test('should have correct system command', () {
        expect(whichCommand, equals('which'));
      });
    });

    group('Tool Arguments', () {
      test('should have correct spectacle arguments', () {
        expect(spectacleArguments, equals(['-f', '-b', '-n', '-o']));
      });

      test('should have correct gnome-screenshot arguments', () {
        expect(gnomeScreenshotArguments, equals(['-f']));
      });

      test('should have correct scrot arguments', () {
        expect(scrotArguments, equals([]));
      });

      test('should have correct import arguments', () {
        expect(importArguments, equals(['-window', 'root']));
      });

      test('should have correct screencapture arguments', () {
        expect(screencaptureArguments, equals(['-tjpg']));
      });
    });

    group('Error Messages', () {
      test('should have helpful no tool available message', () {
        expect(noScreenshotToolAvailableMessage,
            contains('No screenshot tool available'));
      });

      test('should have install instructions message', () {
        expect(installInstructionsMessage, contains('sudo apt install'));
        expect(installInstructionsMessage, contains('spectacle'));
        expect(installInstructionsMessage, contains('gnome-screenshot'));
        expect(installInstructionsMessage, contains('scrot'));
        expect(installInstructionsMessage, contains('imagemagick'));
      });

      test('should have unsupported tool message', () {
        expect(unsupportedToolMessage, contains('Unsupported screenshot tool'));
      });

      test('should have tool failed message', () {
        expect(toolFailedMessage, contains('Screenshot tool'));
      });

      test('should have failed with exit code message', () {
        expect(failedWithExitCodeMessage, contains('failed with exit code'));
      });

      test('should have screencapture failed message', () {
        expect(
            screencaptureFailedMessage, contains('macOS screencapture failed'));
      });

      test('should have unsupported platform message', () {
        expect(unsupportedPlatformMessage,
            contains('Screenshot functionality is not supported'));
      });
    });

    group('Process Configuration', () {
      test('should have correct run in shell setting', () {
        expect(runInShell, isFalse);
      });

      test('should have correct success exit code', () {
        expect(successExitCode, equals(0));
      });
    });

    group('Screenshot Tool Configurations', () {
      test('should have configuration for all Linux tools', () {
        for (final tool in linuxScreenshotTools) {
          final config = screenshotToolConfigs[tool];
          expect(config, isNotNull,
              reason: 'Tool $tool should have configuration');
        }
      });

      test('should have complete configuration for spectacle', () {
        final config = screenshotToolConfigs[spectacleTool];
        expect(config, isNotNull);
        expect(config!.name, equals('Spectacle'));
        expect(config.arguments, equals(spectacleArguments));
        expect(config.description, equals('KDE screenshot tool'));
        expect(config.installCommand, equals('sudo apt install spectacle'));
      });

      test('should have complete configuration for gnome-screenshot', () {
        final config = screenshotToolConfigs[gnomeScreenshotTool];
        expect(config, isNotNull);
        expect(config!.name, equals('GNOME Screenshot'));
        expect(config.arguments, equals(gnomeScreenshotArguments));
        expect(config.description, equals('GNOME screenshot tool'));
        expect(
            config.installCommand, equals('sudo apt install gnome-screenshot'));
      });

      test('should have complete configuration for scrot', () {
        final config = screenshotToolConfigs[scrotTool];
        expect(config, isNotNull);
        expect(config!.name, equals('Scrot'));
        expect(config.arguments, equals(scrotArguments));
        expect(config.description, equals('Lightweight screenshot tool'));
        expect(config.installCommand, equals('sudo apt install scrot'));
      });

      test('should have complete configuration for import', () {
        final config = screenshotToolConfigs[importTool];
        expect(config, isNotNull);
        expect(config!.name, equals('ImageMagick Import'));
        expect(config.arguments, equals(importArguments));
        expect(config.description, equals('ImageMagick screenshot tool'));
        expect(config.installCommand, equals('sudo apt install imagemagick'));
      });
    });

    group('ScreenshotToolConfig Class', () {
      test('should create configuration with all required fields', () {
        const config = ScreenshotToolConfig(
          name: 'Test Tool',
          arguments: ['-test'],
          description: 'Test description',
          installCommand: 'sudo apt install test',
        );

        expect(config.name, equals('Test Tool'));
        expect(config.arguments, equals(['-test']));
        expect(config.description, equals('Test description'));
        expect(config.installCommand, equals('sudo apt install test'));
      });

      test('should handle empty arguments list', () {
        const config = ScreenshotToolConfig(
          name: 'Test Tool',
          arguments: [],
          description: 'Test description',
          installCommand: 'sudo apt install test',
        );

        expect(config.arguments, isEmpty);
      });

      test('should handle multiple arguments', () {
        const config = ScreenshotToolConfig(
          name: 'Test Tool',
          arguments: ['-arg1', '-arg2', 'value'],
          description: 'Test description',
          installCommand: 'sudo apt install test',
        );

        expect(config.arguments, equals(['-arg1', '-arg2', 'value']));
        expect(config.arguments.length, equals(3));
      });
    });

    group('Configuration Validation', () {
      test('all tool configurations should have non-empty names', () {
        for (final config in screenshotToolConfigs.values) {
          expect(config.name, isNotEmpty);
        }
      });

      test('all tool configurations should have non-empty descriptions', () {
        for (final config in screenshotToolConfigs.values) {
          expect(config.description, isNotEmpty);
        }
      });

      test('all tool configurations should have non-empty install commands',
          () {
        for (final config in screenshotToolConfigs.values) {
          expect(config.installCommand, isNotEmpty);
        }
      });

      test('all tool configurations should have valid argument lists', () {
        for (final config in screenshotToolConfigs.values) {
          expect(config.arguments, isA<List<String>>());
        }
      });

      test('tool configurations should match their tool constants', () {
        for (final tool in linuxScreenshotTools) {
          final config = screenshotToolConfigs[tool];
          expect(config, isNotNull);

          // Verify the tool name in config matches the constant
          switch (tool) {
            case 'spectacle':
              expect(config!.name, equals('Spectacle'));
            case 'gnome-screenshot':
              expect(config!.name, equals('GNOME Screenshot'));
            case 'scrot':
              expect(config!.name, equals('Scrot'));
            case 'import':
              expect(config!.name, equals('ImageMagick Import'));
          }
        }
      });
    });

    group('Constants Consistency', () {
      test('Linux tools list should match tool configurations', () {
        expect(
            linuxScreenshotTools.length, equals(screenshotToolConfigs.length));

        for (final tool in linuxScreenshotTools) {
          expect(screenshotToolConfigs.containsKey(tool), isTrue);
        }
      });

      test('tool arguments should match configuration arguments', () {
        expect(screenshotToolConfigs[spectacleTool]!.arguments,
            equals(spectacleArguments));
        expect(screenshotToolConfigs[gnomeScreenshotTool]!.arguments,
            equals(gnomeScreenshotArguments));
        expect(screenshotToolConfigs[scrotTool]!.arguments,
            equals(scrotArguments));
        expect(screenshotToolConfigs[importTool]!.arguments,
            equals(importArguments));
      });

      test('error messages should be properly formatted', () {
        expect(noScreenshotToolAvailableMessage, endsWith(': '));
        expect(unsupportedToolMessage, endsWith(': '));
        expect(toolFailedMessage, endsWith(' '));
        expect(
            failedWithExitCodeMessage, startsWith(' failed with exit code '));
      });
    });
  });
}
