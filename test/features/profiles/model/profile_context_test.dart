import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';

void main() {
  Profile profileOfType(ProfileType type) => Profile(
    id: type == ProfileType.real ? Profile.realProfileId : 'g1',
    type: type,
    name: 'x',
    dirName: type == ProfileType.real ? '' : 'guest_profiles/g1',
    createdAt: DateTime(2026),
  );

  group('ProfileContext.forProfile', () {
    test('real profiles get full capabilities', () {
      final context = ProfileContext.forProfile(
        profile: profileOfType(ProfileType.real),
        root: Directory('/data/lotti'),
      );

      expect(context.isGuest, isFalse);
      expect(context.capabilities.syncEnabled, isTrue);
      expect(context.capabilities.healthImportEnabled, isTrue);
    });

    test('guest profiles structurally exclude sync and health import', () {
      final context = ProfileContext.forProfile(
        profile: profileOfType(ProfileType.guest),
        root: Directory('/data/lotti/guest_profiles/g1'),
      );

      expect(context.isGuest, isTrue);
      expect(context.capabilities.syncEnabled, isFalse);
      expect(context.capabilities.healthImportEnabled, isFalse);
    });
  });
}
