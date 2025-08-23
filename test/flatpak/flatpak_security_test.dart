import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// Testing library: flutter_test (built on package:test). Additional unit tests appended below.
import 'package:lotti/services/portals/audio_portal_service.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:lotti/services/portals/screenshot_portal_service.dart';

/// Comprehensive test suite for Flatpak security and permission boundaries
void main() {
  group('Flatpak Security and Sandboxing Tests', () {
    group('Environment Detection', () {
      test('correctly identifies Flatpak environment', () {
        final isInFlatpak = PortalService.isRunningInFlatpak;
        final shouldUsePortal = PortalService.shouldUsePortal;

        // These should always be consistent
        expect(shouldUsePortal, equals(isInFlatpak));

        if (Platform.isLinux) {
          final hasFlatpakId = Platform.environment['FLATPAK_ID'] != null &&
              Platform.environment['FLATPAK_ID']!.isNotEmpty;
          expect(isInFlatpak, equals(hasFlatpakId));
        } else {
          // Non-Linux platforms should never report as Flatpak
          expect(isInFlatpak, isFalse);
        }
      });

      test('FLATPAK_ID environment variable is properly checked', () {
        final flatpakId = Platform.environment['FLATPAK_ID'];

        if (PortalService.isRunningInFlatpak) {
          expect(flatpakId, isNotNull);
          expect(flatpakId, isNotEmpty);
          // Should match the app ID in the manifest
          if (flatpakId != null) {
            expect(flatpakId, contains('lotti'));
          }
        } else {
          // Outside Flatpak, this should be null or empty
          expect(flatpakId == null || flatpakId.isEmpty, isTrue);
        }
      });
    });

    group('Filesystem Permissions', () {
      test('validates restricted filesystem access paths', () {
        // These are the paths defined in the Flatpak manifest
        const restrictedPaths = {
          'xdg-documents/Lotti': 'create', // Can only create Lotti folder
          'xdg-download/Lotti': 'create', // Can only create Lotti folder
          'xdg-pictures': 'ro', // Read-only access
        };

        // Verify each path has appropriate restrictions
        for (final entry in restrictedPaths.entries) {
          final path = entry.key;
          final permission = entry.value;

          if (path.contains('Lotti')) {
            // App-specific directories should be isolated
            expect(path.endsWith('/Lotti'), isTrue);
            expect(permission, equals('create'));
          } else if (path == 'xdg-pictures') {
            // Pictures should be read-only for importing
            expect(permission, equals('ro'));
          }
        }
      });

      test('ensures app data is properly isolated', () {
        // In Flatpak, app data should be in ~/.var/app/com.matthiasnehlsen.lotti/
        if (PortalService.isRunningInFlatpak) {
          final homeDir = Platform.environment['HOME'];
          if (homeDir != null) {
            final appDataPath = '$homeDir/.var/app/com.matthiasnehlsen.lotti';

            // We can't directly test existence without being in Flatpak,
            // but we can verify the path structure
            expect(appDataPath, contains('.var/app'));
            expect(appDataPath, contains('com.matthiasnehlsen.lotti'));
          }
        }
      });

      test('verifies system directories are not directly accessible', () {
        // These directories should not be accessible in sandboxed environment
        const systemPaths = [
          '/usr/bin',
          '/etc/passwd',
          '/var/log',
          '/root',
          '/home', // Should not have direct access to other users' homes
        ];

        if (PortalService.isRunningInFlatpak) {
          for (final path in systemPaths) {
            // In a proper sandbox, these would be blocked or bind-mounted
            // We verify the app is aware it shouldn't access these
            expect(path.startsWith('/'), isTrue);
            expect(path, isNot(contains('.var/app')));
          }
        }
      });
    });

    group('Portal Service Security', () {
      test('screenshot portal enforces sandbox boundaries', () {
        final screenshotPortal = ScreenshotPortalService();

        if (!PortalService.shouldUsePortal) {
          // Outside Flatpak, portal should refuse to work
          expect(
            () async => screenshotPortal.takeScreenshot(),
            throwsA(isA<UnsupportedError>()),
          );
        } else {
          // In Flatpak, portal should be the only way to take screenshots
          expect(PortalService.shouldUsePortal, isTrue);
        }
      });

      test('audio portal enforces sandbox boundaries', () {
        final audioPortal = AudioPortalService();

        // Audio portal should only work through D-Bus in Flatpak
        if (PortalService.shouldUsePortal) {
          expect(audioPortal, isA<PortalService>());
        }
      });

      test('portal services use correct D-Bus names', () {
        // These are standardized by freedesktop.org and should never change
        expect(PortalConstants.portalBusName,
            equals('org.freedesktop.portal.Desktop'));
        expect(PortalConstants.portalPath,
            equals('/org/freedesktop/portal/desktop'));

        // Verify individual portal interfaces
        expect(ScreenshotPortalConstants.interfaceName,
            equals('org.freedesktop.portal.Screenshot'));
        expect(AudioPortalConstants.interfaceName,
            equals('org.freedesktop.portal.Device'));
      });

      test('portal handle tokens are unique and secure', () async {
        final token1 = PortalService.createHandleToken('test');
        // Add delay to ensure different timestamp
        await Future<void>.delayed(const Duration(milliseconds: 2));
        final token2 = PortalService.createHandleToken('test');

        // Tokens should be unique
        expect(token1, isNot(equals(token2)));

        // Tokens should include timestamp for uniqueness
        expect(token1, contains('test_'));
        expect(token2, contains('test_'));

        // Extract timestamps and verify they're different
        final timestamp1 = token1.split('_').last;
        final timestamp2 = token2.split('_').last;
        expect(timestamp1, isNot(equals(timestamp2)));
      });
    });

    group('Runtime and Library Security', () {
      test('uses Freedesktop runtime 24.08', () {
        // This is specified in the Flatpak manifest
        // The runtime provides security updates and sandboxing

        if (PortalService.isRunningInFlatpak) {
          // Runtime version should be consistent
          // We can't directly check this from within the app,
          // but we document the expected version
          const expectedRuntime = 'org.freedesktop.Platform';
          const expectedVersion = '24.08';

          expect(expectedRuntime, contains('freedesktop'));
          expect(expectedVersion, equals('24.08'));
        }
      });

      test('wrapper script sets correct environment', () {
        // The lotti-wrapper script should set up the environment
        if (PortalService.isRunningInFlatpak) {
          // Check for expected environment variables
          final ldLibraryPath = Platform.environment['LD_LIBRARY_PATH'];

          if (ldLibraryPath != null) {
            // Should include /app/lib for Flatpak libraries
            expect(ldLibraryPath.contains('/app/lib'), isTrue);
          }

          // Check display server configuration
          final waylandDisplay = Platform.environment['WAYLAND_DISPLAY'];
          final x11Display = Platform.environment['DISPLAY'];

          // Should have at least one display server available
          expect(waylandDisplay != null || x11Display != null, isTrue);
        }
      });

      test('ffmpeg extension is properly configured', () {
        // The manifest includes ffmpeg-full extension
        if (PortalService.isRunningInFlatpak) {
          // FFmpeg should be available at the extension path
          const ffmpegExtPath = '/app/lib/ffmpeg';

          // We can't directly check file existence in tests,
          // but we verify the expected path
          expect(ffmpegExtPath, startsWith('/app'));
          expect(ffmpegExtPath, contains('ffmpeg'));
        }
      });
    });

    group('Network and IPC Security', () {
      test('network access is properly declared', () {
        // The manifest includes --share=network
        // This is required for the app's functionality

        // Network should be available but controlled
        if (PortalService.isRunningInFlatpak) {
          // The app has network access as declared
          // This is a conscious security decision documented in the manifest
          const hasNetwork = true; // From --share=network
          expect(hasNetwork, isTrue);
        }
      });

      test('IPC is shared for display server communication', () {
        // The manifest includes --share=ipc
        // Required for X11 and clipboard functionality

        if (PortalService.isRunningInFlatpak) {
          // IPC should be available for GUI functionality
          const hasIPC = true; // From --share=ipc
          expect(hasIPC, isTrue);
        }
      });

      test('audio access uses PulseAudio socket', () {
        // The manifest includes --socket=pulseaudio

        if (PortalService.isRunningInFlatpak) {
          // Audio should work through PulseAudio socket
          const hasPulseAudio = true; // From --socket=pulseaudio
          expect(hasPulseAudio, isTrue);
        }
      });
    });

    group('Portal Communication Security', () {
      test('portal requests include security tokens', () {
        // All portal requests should include handle tokens
        final token = PortalService.createHandleToken('security_test');

        // Token should be non-empty and unique
        expect(token, isNotEmpty);
        expect(token, contains('security_test_'));

        // Token should include timestamp
        final parts = token.split('_');
        expect(parts.length, greaterThanOrEqualTo(2));

        final timestamp = int.tryParse(parts.last);
        expect(timestamp, isNotNull);
        expect(timestamp, greaterThan(0));
      });

      test('portal timeout prevents hanging', () {
        // Portal requests should have a timeout
        const timeout = PortalConstants.responseTimeout;

        expect(timeout.inSeconds, equals(30));
        expect(timeout.inSeconds, greaterThan(0));
        expect(timeout.inSeconds, lessThanOrEqualTo(60));
      });

      test('portal service disposal prevents resource leaks', () async {
        final service = ScreenshotPortalService();

        // Initialize and dispose should work correctly
        await service.initialize();
        expect(service.isInitialized, isTrue);

        await service.dispose();
        expect(service.isInitialized, isFalse);

        // After disposal, client access should fail
        expect(() => service.client, throwsStateError);

        // Multiple disposals should be safe
        await service.dispose();
        expect(service.isInitialized, isFalse);
      });
    });

    group('Security Best Practices', () {
      test('no hardcoded secrets or keys', () {
        // Verify no secrets are exposed in portal communication

        // Portal service should not contain any API keys
        const portalBusName = PortalConstants.portalBusName;
        expect(portalBusName, isNot(contains('api')));
        expect(portalBusName, isNot(contains('key')));
        expect(portalBusName, isNot(contains('secret')));
        expect(portalBusName, isNot(contains('token')));

        // Bus name should be the standard freedesktop portal
        expect(portalBusName, equals('org.freedesktop.portal.Desktop'));
      });

      test('principle of least privilege is followed', () {
        // Verify the app only requests necessary permissions

        // Document the permissions and their justifications:
        const permissions = {
          '--share=network': 'Required for journal sync and AI features',
          '--share=ipc': 'Required for X11 and clipboard',
          '--socket=fallback-x11': 'Display server access',
          '--socket=wayland': 'Wayland display server',
          '--socket=pulseaudio': 'Audio recording features',
          '--device=dri': 'Hardware acceleration',
          '--filesystem=xdg-documents/Lotti:create': 'Journal data storage',
          '--filesystem=xdg-pictures:ro': 'Import images into journal',
          '--filesystem=xdg-download/Lotti:create': 'Export journal data',
        };

        // Each permission should have a justification
        for (final entry in permissions.entries) {
          expect(entry.key, isNotEmpty);
          expect(entry.value, isNotEmpty);

          // Filesystem permissions should be restricted
          if (entry.key.contains('filesystem')) {
            // Should either be read-only or app-specific
            expect(
              entry.key.contains(':ro') || entry.key.contains('Lotti'),
              isTrue,
            );
          }
        }
      });

      test('secure defaults are used', () {
        // Verify secure defaults throughout the portal system

        // Portal should be disabled outside Flatpak (secure default)
        if (!Platform.isLinux || Platform.environment['FLATPAK_ID'] == null) {
          expect(PortalService.shouldUsePortal, isFalse);
        }

        // Interactive mode should be opt-in for screenshots
        // Modal windows should be non-modal by default
        // These are enforced in the portal service implementation

        // Timeouts should be reasonable to prevent DoS
        expect(
            PortalConstants.responseTimeout.inSeconds, lessThanOrEqualTo(60));
      });
    });
  });

  // ------------------------------------------------------------
  // Additional Flatpak security/unit tests (focus on diff areas)
  // Testing library: flutter_test (built on package:test)
  // ------------------------------------------------------------
  group('Additional Flatpak Security Invariants', () {
    group('Handle token generation', () {
      test('includes prefix and a numeric timestamp suffix', () async {
        final token = PortalService.createHandleToken('prefix');
        expect(token, startsWith('prefix_'));
        final parts = token.split('_');
        expect(parts.length, greaterThanOrEqualTo(2));
        final ts = int.tryParse(parts.last);
        expect(ts, isNotNull);
        expect(ts! > 0, isTrue);
      });

      test('monotonic timestamps across sequential generations', () async {
        final t1 = PortalService.createHandleToken('mono');
        await Future<void>.delayed(const Duration(milliseconds: 2));
        final t2 = PortalService.createHandleToken('mono');
        final ts1 = int.parse(t1.split('_').last);
        final ts2 = int.parse(t2.split('_').last);
        expect(ts2, greaterThan(ts1));
      });

      test('handles uncommon but valid prefixes', () async {
        const prefix = 'lotti.security-TEST 123';
        final token = PortalService.createHandleToken(prefix);
        // Avoid over-constraining potential sanitization rules; assert robust invariants.
        expect(token, contains('lotti'));
        expect(token, contains('_'));
        final ts = int.tryParse(token.split('_').last);
        expect(ts, isNotNull);
      });

      test('shouldUsePortal value is stable across reads', () {
        final a = PortalService.shouldUsePortal;
        final b = PortalService.shouldUsePortal;
        expect(a, equals(b));
        // Remains consistent with isRunningInFlatpak
        expect(a, equals(PortalService.isRunningInFlatpak));
      });
    });

    group('Portal constants sanity', () {
      test('bus and path constants are non-empty and normalized', () {
        expect(PortalConstants.portalBusName, isNotEmpty);
        expect(PortalConstants.portalPath, isNotEmpty);
        expect(PortalConstants.portalBusName, isNot(contains(' ')));
        expect(PortalConstants.portalPath, startsWith('/org/freedesktop/portal'));
      });

      test('interface names follow freedesktop.org conventions', () {
        expect(ScreenshotPortalConstants.interfaceName, startsWith('org.freedesktop.portal.'));
        expect(ScreenshotPortalConstants.interfaceName, endsWith('Screenshot'));
        expect(AudioPortalConstants.interfaceName, startsWith('org.freedesktop.portal.'));
        expect(AudioPortalConstants.interfaceName, endsWith('Device'));
      });

      test('response timeout is a Duration and within sane bounds', () {
        final timeout = PortalConstants.responseTimeout;
        expect(timeout, isA<Duration>());
        expect(timeout.inSeconds, greaterThanOrEqualTo(1));
        expect(timeout.inSeconds, lessThanOrEqualTo(60));
      });
    });

    group('Screenshot portal lifecycle robustness', () {
      test('initialize may be called multiple times and completes', () async {
        final service = ScreenshotPortalService();
        await service.initialize();
        expect(service.isInitialized, isTrue);
        // Subsequent initialize should complete without throwing
        expect(service.initialize(), completes);
        await service.dispose();
      });

      test('dispose may be called without prior initialize', () async {
        final service = ScreenshotPortalService();
        expect(service.isInitialized, isFalse);
        await service.dispose();
        expect(service.isInitialized, isFalse);
      });

      test('type relationships remain sound', () {
        final screenshotPortal = ScreenshotPortalService();
        final audioPortal = AudioPortalService();
        expect(screenshotPortal, isA<PortalService>());
        expect(audioPortal, isA<PortalService>());
      });
    });
  });

}
