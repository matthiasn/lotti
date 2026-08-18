import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/relationships/util/contact_channel_uri.dart';

/// Platform declarations the relationship contact features depend on, checked
/// against the real files rather than test-local copies — the
/// `test/flatpak/flatpak_security_test.dart` precedent.
///
/// These are the failures this suite exists to catch, none of which any Dart
/// test would otherwise see:
///
/// - a regenerated `Info.plist` or `AndroidManifest.xml` silently dropping a
///   usage description or permission, turning the contact picker into a
///   permission crash on device,
/// - a `<queries>` declaration drifting away from `ACTION_VIEW`, which leaves
///   `canLaunchUrl` reporting false on Android 11+ and every quick action
///   greyed out,
/// - [ContactAction] gaining a scheme that no platform declares.
///
/// Comments are stripped before every assertion. Both manifests explain their
/// own declarations in prose that names the very permissions and schemes
/// under test, so a naive substring check would read the explanation as the
/// declaration — and, for `WRITE_CONTACTS`, assert the exact opposite of what
/// the file says.
String _stripXmlComments(String source) =>
    source.replaceAll(RegExp('<!--.*?-->', dotAll: true), '');

String _readStripped(String path) =>
    _stripXmlComments(File(path).readAsStringSync());

String _infoPlist() => _readStripped('ios/Runner/Info.plist');

String _androidManifest() =>
    _readStripped('android/app/src/main/AndroidManifest.xml');

/// The `<string>` value following `<key>[key]</key>`, or null when absent.
String? _plistString(String plist, String key) {
  final match = RegExp(
    '<key>$key</key>\\s*<string>(.*?)</string>',
    dotAll: true,
  ).firstMatch(plist);
  return match?.group(1);
}

/// The `<string>` entries of the `<array>` following `<key>[key]</key>`.
List<String> _plistArray(String plist, String key) {
  final block = RegExp(
    '<key>$key</key>\\s*<array>(.*?)</array>',
    dotAll: true,
  ).firstMatch(plist);
  if (block == null) return const [];
  return RegExp(
    '<string>(.*?)</string>',
    dotAll: true,
  ).allMatches(block.group(1)!).map((m) => m.group(1)!.trim()).toList();
}

List<String> _usesPermissions(String manifest) => RegExp(
  r'<uses-permission\s+android:name="([^"]+)"',
).allMatches(manifest).map((m) => m.group(1)!).toList();

/// One `<intent>` inside the manifest's `<queries>` block.
typedef _QueryIntent = ({String? action, String? scheme});

List<_QueryIntent> _queryIntents(String manifest) {
  final queries = RegExp(
    '<queries>(.*?)</queries>',
    dotAll: true,
  ).firstMatch(manifest);
  if (queries == null) return const [];

  return RegExp(
    '<intent>(.*?)</intent>',
    dotAll: true,
  ).allMatches(queries.group(1)!).map((intent) {
    final body = intent.group(1)!;
    return (
      action: RegExp(
        r'<action\s+android:name="([^"]+)"',
      ).firstMatch(body)?.group(1),
      scheme: RegExp(
        r'<data\s+android:scheme="([^"]+)"',
      ).firstMatch(body)?.group(1),
    );
  }).toList();
}

/// Every scheme the app can hand to `url_launcher` for a contact channel.
Set<String> _launchableSchemes() =>
    ContactAction.values.map(schemeForContactAction).toSet();

void main() {
  group('flutter_contacts dependency', () {
    test('is declared as a direct dependency, not pulled in transitively', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(
        pubspec,
        contains(RegExp(r'^\s{2}flutter_contacts:\s*\^?\d', multiLine: true)),
        reason:
            'the contact picker imports it directly, so it must be a '
            'direct dependency with a pinned constraint',
      );
    });

    test('resolves in the lockfile as a direct main dependency', () {
      final lock = File('pubspec.lock').readAsStringSync();
      final entry = RegExp(
        r'^  flutter_contacts:\n(?:.*\n)*?    dependency: "?([a-z ]+)"?\n',
        multiLine: true,
      ).firstMatch(lock);

      expect(entry, isNotNull, reason: 'flutter_contacts absent from lockfile');
      expect(entry!.group(1), 'direct main');
    });
  });

  group('iOS — Info.plist', () {
    test('declares a contacts usage description', () {
      final description = _plistString(
        _infoPlist(),
        'NSContactsUsageDescription',
      );

      expect(
        description,
        isNotNull,
        reason: 'without it, the first contact-picker call terminates the app',
      );
      expect(description!.trim(), isNotEmpty);
    });

    test('explains the real reason rather than reusing the placeholder copy '
        'carried by permission-library-only keys', () {
      final description = _plistString(
        _infoPlist(),
        'NSContactsUsageDescription',
      )!;

      expect(
        description,
        isNot(contains('Not actually used')),
        reason:
            'contacts are genuinely read here, and App Review rejects '
            'purpose strings that do not state a purpose',
      );
      expect(
        description.length,
        greaterThan(30),
        reason:
            'a one-word string reads as boilerplate to review and to '
            'the user being asked for their address book',
      );
    });

    test('declares every scheme the quick actions can launch', () {
      final declared = _plistArray(
        _infoPlist(),
        'LSApplicationQueriesSchemes',
      ).toSet();

      expect(
        declared,
        containsAll(_launchableSchemes()),
        reason:
            'canLaunchUrl returns false for any scheme absent here, '
            'missing: ${_launchableSchemes().difference(declared)}',
      );
    });

    test('declares no scheme the app never launches', () {
      final declared = _plistArray(
        _infoPlist(),
        'LSApplicationQueriesSchemes',
      ).toSet();

      expect(
        declared.difference(_launchableSchemes()),
        isEmpty,
        reason:
            'querying schemes the app cannot use is unexplained '
            'capability at App Review time',
      );
    });
  });

  group('Android — AndroidManifest.xml', () {
    test('requests permission to read contacts', () {
      expect(
        _usesPermissions(_androidManifest()),
        contains('android.permission.READ_CONTACTS'),
      );
    });

    test('does not request permission to write contacts', () {
      expect(
        _usesPermissions(_androidManifest()),
        isNot(contains('android.permission.WRITE_CONTACTS')),
        reason:
            'import copies out of the address book and never back into '
            'it; asking for write access would be unjustified at install '
            'time (ADR 0041)',
      );
    });

    test('declares a queries block for package visibility', () {
      expect(
        _queryIntents(_androidManifest()),
        isNotEmpty,
        reason:
            'without <queries>, Android 11+ hides every dialer, SMS and '
            'mail app from resolution',
      );
    });

    test('resolves every query through ACTION_VIEW, the action '
        'url_launcher actually fires', () {
      final intents = _queryIntents(_androidManifest());

      for (final intent in intents) {
        expect(
          intent.action,
          'android.intent.action.VIEW',
          reason:
              'url_launcher_android builds both canLaunchUrl and '
              'launchUrl as ACTION_VIEW intents; a DIAL or SENDTO '
              'declaration matches nothing it asks about, so the button '
              'renders disabled with no error anywhere',
        );
      }
    });

    test('covers every scheme the quick actions can launch', () {
      final declared = _queryIntents(
        _androidManifest(),
      ).map((intent) => intent.scheme).whereType<String>().toSet();

      expect(
        declared,
        containsAll(_launchableSchemes()),
        reason: 'missing: ${_launchableSchemes().difference(declared)}',
      );
    });

    test('gives every query intent a scheme to match on', () {
      for (final intent in _queryIntents(_androidManifest())) {
        expect(
          intent.scheme,
          isNotNull,
          reason:
              'a schemeless <intent> widens visibility beyond what the '
              'feature needs',
        );
      }
    });
  });

  group('both platforms agree with the Dart action vocabulary', () {
    test('every ContactAction scheme is declared on iOS and Android', () {
      final ios = _plistArray(
        _infoPlist(),
        'LSApplicationQueriesSchemes',
      ).toSet();
      final android = _queryIntents(
        _androidManifest(),
      ).map((intent) => intent.scheme).whereType<String>().toSet();

      for (final action in ContactAction.values) {
        final scheme = schemeForContactAction(action);
        expect(ios, contains(scheme), reason: '$action undeclared on iOS');
        expect(
          android,
          contains(scheme),
          reason: '$action undeclared on Android',
        );
      }
    });
  });

  group('OS floors flutter_contacts 2.3.1 pins', () {
    // The open question plan v2 phase 7 left for implementation time. The
    // plugin requires Android minSdk 24 and iOS 13.0; the app already sits
    // above both, so no bump was needed. These pin that headroom so a future
    // lowering surfaces here instead of as a build failure on device.
    test('Android minSdkVersion stays at or above 24', () {
      final gradle = File('android/app/build.gradle').readAsStringSync();
      final minSdk = RegExp(
        r'minSdkVersion\s+(\d+)',
      ).firstMatch(gradle)?.group(1);

      expect(minSdk, isNotNull, reason: 'minSdkVersion not found in gradle');
      expect(int.parse(minSdk!), greaterThanOrEqualTo(24));
    });

    test('iOS deployment target stays at or above 13.0', () {
      final podfile = File('ios/Podfile').readAsStringSync();
      final target = RegExp(
        r"platform :ios, '([\d.]+)'",
      ).firstMatch(podfile)?.group(1);

      expect(target, isNotNull, reason: 'platform :ios not found in Podfile');

      final parts = target!.split('.').map(int.parse).toList();
      final major = parts.first;
      final minor = parts.length > 1 ? parts[1] : 0;

      expect(
        major > 13 || (major == 13 && minor >= 0),
        isTrue,
        reason: 'iOS deployment target $target is below flutter_contacts 13.0',
      );
    });
  });
}
