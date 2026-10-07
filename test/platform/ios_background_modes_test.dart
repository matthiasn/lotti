import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The iOS background modes and location purpose strings, checked against the
/// real `Info.plist` — the `relationship_contacts_config_test.dart` precedent.
///
/// App Review rejects a background mode the app has no persistent feature
/// for (guideline 2.5.4), so each mode declared here must be one a reviewer
/// can be shown in use:
///
/// - `audio` keeps an audio-note recording (`record`, `.playAndRecord`) and
///   audio-note playback (media_kit's mpv, `.playback`) running once the user
///   leaves the app.
/// - `location` is not declared: the app reads one position fix when an
///   entry is created (`AppleLocationSource`) and never tracks location in
///   the background.
String _infoPlist() => File(
  'ios/Runner/Info.plist',
).readAsStringSync().replaceAll(RegExp('<!--.*?-->', dotAll: true), '');

List<String> _backgroundModes() {
  final block = RegExp(
    r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>',
    dotAll: true,
  ).firstMatch(_infoPlist());
  expect(block, isNotNull, reason: 'UIBackgroundModes missing from plist');
  return RegExp(
    '<string>(.*?)</string>',
  ).allMatches(block!.group(1)!).map((m) => m.group(1)!.trim()).toList();
}

void main() {
  group('iOS — UIBackgroundModes', () {
    test('declares audio, so recording and playback survive backgrounding', () {
      expect(_backgroundModes(), contains('audio'));
    });

    test('does not declare location, which has no persistent feature', () {
      expect(
        _backgroundModes(),
        isNot(contains('location')),
        reason:
            'App Review rejected 1.0.18 under 2.5.4 for declaring '
            'background location with no feature that needs it',
      );
    });
  });

  group('iOS — location permission', () {
    test('declares a when-in-use purpose string', () {
      expect(
        _infoPlist(),
        contains('<key>NSLocationWhenInUseUsageDescription</key>'),
        reason:
            'geolocator_apple requests when-in-use only while this key is '
            'present; without it, it falls through to requesting Always',
      );
    });
  });
}
