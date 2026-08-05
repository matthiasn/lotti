import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/app_bootstrap.dart';
import 'package:lotti/app_root.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:lotti/features/profiles/service/profile_switcher.dart';

void main() {
  group('ProfileSwitchSplash', () {
    testWidgets('shows a bare progress indicator with no app chrome', (
      tester,
    ) async {
      await tester.pumpWidget(const ProfileSwitchSplash());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Deliberately provider- and localization-free: nothing from the old
      // generation may be needed to render it.
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('ProfileSwitcherScope', () {
    ProfileSwitcher buildSwitcher(Directory root) => ProfileSwitcher(
      registry: ProfileRegistry(realRoot: root),
      lifecycleHolder: AppLifecycleHolder(),
      onSwitchStarted: () async {},
      onSwitchCompleted: () {},
      settleFrame: () async {},
      teardownOverride: () async {},
      bootstrapOverride: () async {},
    );

    testWidgets('of() resolves the switcher from above the scope', (
      tester,
    ) async {
      final root = Directory.systemTemp.createTempSync('lotti_scope_');
      addTearDown(() => root.deleteSync(recursive: true));
      final switcher = buildSwitcher(root);
      late ProfileSwitcher resolved;

      await tester.pumpWidget(
        ProfileSwitcherScope(
          switcher: switcher,
          child: Builder(
            builder: (context) {
              resolved = ProfileSwitcherScope.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(identical(resolved, switcher), isTrue);
    });

    testWidgets('updateShouldNotify fires only on a new switcher instance', (
      tester,
    ) async {
      final root = Directory.systemTemp.createTempSync('lotti_scope_');
      addTearDown(() => root.deleteSync(recursive: true));
      final switcherA = buildSwitcher(root);
      final switcherB = buildSwitcher(root);

      final scopeA = ProfileSwitcherScope(
        switcher: switcherA,
        child: const SizedBox.shrink(),
      );
      final scopeSameSwitcher = ProfileSwitcherScope(
        switcher: switcherA,
        child: const SizedBox.shrink(),
      );
      final scopeB = ProfileSwitcherScope(
        switcher: switcherB,
        child: const SizedBox.shrink(),
      );

      expect(scopeSameSwitcher.updateShouldNotify(scopeA), isFalse);
      expect(scopeB.updateShouldNotify(scopeA), isTrue);
    });
  });
}
