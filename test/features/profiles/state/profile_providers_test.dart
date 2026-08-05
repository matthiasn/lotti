import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';

void main() {
  ProfileContext contextOfType(ProfileType type) => ProfileContext.forProfile(
    profile: Profile(
      id: type == ProfileType.real ? Profile.realProfileId : 'g1',
      type: type,
      name: 'x',
      dirName: type == ProfileType.real ? '' : 'guest_profiles/g1',
      createdAt: DateTime(2026),
    ),
    root: Directory('/data/lotti'),
  );

  ProviderContainer containerWith(ProfileContext context) {
    final container = ProviderContainer(
      overrides: [profileContextProvider.overrideWithValue(context)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('profile providers', () {
    test('real profile: sync available, demo inactive', () {
      final container = containerWith(contextOfType(ProfileType.real));

      expect(container.read(syncFeatureAvailableProvider), isTrue);
      expect(container.read(healthImportFeatureAvailableProvider), isTrue);
      expect(container.read(demoModeActiveProvider), isFalse);
    });

    test('guest profile: sync unavailable, demo active', () {
      final container = containerWith(contextOfType(ProfileType.guest));

      expect(container.read(syncFeatureAvailableProvider), isFalse);
      expect(container.read(healthImportFeatureAvailableProvider), isFalse);
      expect(container.read(demoModeActiveProvider), isTrue);
    });

    test('unoverridden context resolves loudly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(profileContextProvider),
        throwsA(
          isA<ProviderException>().having(
            (exception) => exception.exception,
            'exception',
            isUnimplementedError,
          ),
        ),
      );
    });

    test('fallbacks without override match the real-profile defaults', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(syncFeatureAvailableProvider), isTrue);
      expect(container.read(healthImportFeatureAvailableProvider), isTrue);
      expect(container.read(demoModeActiveProvider), isFalse);
    });
  });
}
