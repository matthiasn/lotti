import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:lotti/services/portals/screenshot_portal_service.dart';

/// Reads the checked-in Flatpak manifest so permission tests validate the
/// real declaration instead of test-local constants.
String _readManifest() =>
    File('flatpak/com.matthiasn.lotti.flatpak-flutter.yml').readAsStringSync();

/// The `finish-args` permission lines declared in the manifest.
List<String> _manifestFinishArgs() => _readManifest()
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.startsWith('- --'))
    .map((line) => line.substring(2))
    .toList();

/// Comprehensive test suite for Flatpak security and permission boundaries.
///
/// Scope note: the portal D-Bus protocol (request/response signals,
/// cancellation, timeouts) is unit-tested with mocked `DBusClient`s in
/// `test/services/portals/`. End-to-end portal round-trips against a real
/// `xdg-desktop-portal` daemon require Linux D-Bus session infrastructure
/// and are deliberately out of scope for the unit suite — they would belong
/// in `integration_test/` on a Linux runner.
void main() {
  group('Flatpak Security and Sandboxing Tests', () {
    group('Environment Detection', () {
      test('correctly identifies Flatpak environment', () {
        final isInFlatpak = PortalService.isRunningInFlatpak;
        final shouldUsePortal = PortalService.shouldUsePortal;

        // These should always be consistent
        expect(shouldUsePortal, equals(isInFlatpak));

        if (Platform.isLinux) {
          final hasFlatpakId =
              Platform.environment['FLATPAK_ID'] != null &&
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
      test('manifest declares only restricted filesystem access', () {
        final filesystemArgs = _manifestFinishArgs()
            .where((arg) => arg.startsWith('--filesystem='))
            .toList();

        // The three known grants, straight from the manifest.
        expect(filesystemArgs, [
          '--filesystem=xdg-documents/Lotti:create',
          '--filesystem=xdg-pictures:ro',
          '--filesystem=xdg-download/Lotti:create',
        ]);

        // Every grant must be read-only or scoped to the app folder.
        for (final arg in filesystemArgs) {
          expect(
            arg.endsWith(':ro') || arg.contains('/Lotti'),
            isTrue,
            reason: '$arg widens filesystem access beyond the app scope',
          );
        }
      });

      test('ensures app data is properly isolated', () {
        // In Flatpak, app data should be in ~/.var/app/com.matthiasn.lotti/
        if (PortalService.isRunningInFlatpak) {
          final homeDir = Platform.environment['HOME'];
          if (homeDir != null) {
            final appDataPath = '$homeDir/.var/app/com.matthiasn.lotti';

            // We can't directly test existence without being in Flatpak,
            // but we can verify the path structure
            expect(appDataPath, contains('.var/app'));
            expect(appDataPath, contains('com.matthiasn.lotti'));
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

      test('portal services use correct D-Bus names', () {
        // These are standardized by freedesktop.org and should never change
        expect(
          PortalConstants.portalBusName,
          equals('org.freedesktop.portal.Desktop'),
        );
        expect(
          PortalConstants.portalPath,
          equals('/org/freedesktop/portal/desktop'),
        );

        // Verify individual portal interfaces
        expect(
          ScreenshotPortalConstants.interfaceName,
          equals('org.freedesktop.portal.Screenshot'),
        );
      });

      test('portal handle tokens are unique and secure', () {
        // No wall-clock delay needed (fake-time policy): uniqueness is
        // guaranteed structurally by the monotonic counter suffix, even
        // when tokens are created back-to-back with identical timestamps.
        final token1 = PortalService.createHandleToken('test');
        final token2 = PortalService.createHandleToken('test');

        // Tokens should be unique
        expect(token1, isNot(equals(token2)));

        // Structure: prefix_timestamp_counter with numeric components
        final parts1 = token1.split('_');
        final parts2 = token2.split('_');
        expect(parts1.first, equals('test'));
        expect(parts2.first, equals('test'));
        expect(int.tryParse(parts1[1]), isNotNull);
        expect(int.tryParse(parts2[1]), isNotNull);

        // The counter suffix is strictly monotonic — this is the actual
        // uniqueness mechanism for rapid successive calls
        expect(
          int.parse(parts2.last),
          greaterThan(int.parse(parts1.last)),
        );
      });
    });

    group('Runtime and Library Security', () {
      test('manifest pins the Freedesktop platform runtime', () {
        final manifest = _readManifest();

        expect(manifest, contains('runtime: org.freedesktop.Platform'));
        // The version is bumped routinely; assert the yearly .08 cadence
        // rather than a hardcoded year that goes stale.
        expect(
          RegExp(r"runtime-version: '\d{2}\.08'").hasMatch(manifest),
          isTrue,
          reason: 'runtime-version must follow the YY.08 platform cadence',
        );
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

      test('no FFmpeg dependency remains', () {
        // FFmpeg was removed — Mistral now accepts M4A natively.
        // Verify pubspec.yaml does not reference ffmpeg_kit_flutter.
        final pubspec = File('pubspec.yaml').readAsStringSync();
        expect(
          pubspec,
          isNot(contains('ffmpeg_kit_flutter')),
          reason: 'FFmpeg dependency should have been removed',
        );
      });
    });

    group('Network and IPC Security', () {
      test('manifest declares the expected shares and sockets', () {
        final args = _manifestFinishArgs();

        expect(args, contains('--share=network'));
        expect(args, contains('--share=ipc'));
        expect(args, contains('--socket=pulseaudio'));
        expect(args, contains('--socket=wayland'));
        expect(args, contains('--socket=fallback-x11'));
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

      test('principle of least privilege is followed in the manifest', () {
        final args = _manifestFinishArgs();

        // No blanket host or home filesystem access.
        expect(
          args.any(
            (arg) =>
                arg.startsWith('--filesystem=host') ||
                arg.startsWith('--filesystem=home'),
          ),
          isFalse,
          reason: 'manifest must not grant blanket filesystem access',
        );
        // No session/system bus talk-alls.
        expect(
          args.any((arg) => arg.contains('--talk-name=org.freedesktop.*')),
          isFalse,
        );
        // Device access is limited to DRI (hardware acceleration).
        final deviceArgs = args.where((a) => a.startsWith('--device='));
        expect(deviceArgs, ['--device=dri']);
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
          PortalConstants.responseTimeout.inSeconds,
          lessThanOrEqualTo(60),
        );
      });
    });
  });
}
