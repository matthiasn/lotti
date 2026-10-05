import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:lotti/features/profiles/service/profile_switcher.dart';
import 'package:lotti/features/profiles/service/profile_switcher_scope.dart';
import 'package:lotti/services/app_lifecycle_holder.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('ProfileSwitcherScope', () {
    ProfileSwitcher buildSwitcher(Directory root) => ProfileSwitcher(
      registry: ProfileRegistry(realRoot: root),
      lifecycleHolder: AppLifecycleHolder(),
      onSwitchStarted: () async {},
      onSwitchCompleted: () {},
      settleFrame: () async {},
      teardownOverride: () async {},
      bootstrapGeneration: (_) async {},
      // Never called: the teardown seam replaces the whole teardown.
      disposeServices: (_) async => const [],
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

    testWidgets('maybeOf() is null without a scope and the switcher within', (
      tester,
    ) async {
      final root = Directory.systemTemp.createTempSync('lotti_scope_');
      addTearDown(() => root.deleteSync(recursive: true));
      final switcher = buildSwitcher(root);
      ProfileSwitcher? outside;
      ProfileSwitcher? inside;

      await tester.pumpWidget(
        Column(
          textDirection: TextDirection.ltr,
          children: [
            Builder(
              builder: (context) {
                outside = ProfileSwitcherScope.maybeOf(context);
                return const SizedBox.shrink();
              },
            ),
            ProfileSwitcherScope(
              switcher: switcher,
              child: Builder(
                builder: (context) {
                  inside = ProfileSwitcherScope.maybeOf(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      );

      expect(outside, isNull);
      expect(identical(inside, switcher), isTrue);
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
