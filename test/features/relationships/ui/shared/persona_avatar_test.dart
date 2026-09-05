import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('personaAccentForId', () {
    test('is stable for the same id across calls', () {
      final a = personaAccentForId('rel-1', Brightness.dark);
      final b = personaAccentForId('rel-1', Brightness.dark);
      expect(a, b);
    });

    test('is stable across brightness only when the palette agrees', () {
      // Different brightness can resolve to a different value; the contract
      // is stability *per brightness*, not across brightness.
      final dark = personaAccentForId('rel-1', Brightness.dark);
      final light = personaAccentForId('rel-1', Brightness.light);
      expect(dark, isA<Color>());
      expect(light, isA<Color>());
    });

    test('distributes across ids (not every id maps to the same accent)', () {
      final accents = {
        for (final id in ['rel-1', 'rel-2', 'rel-3', 'rel-4', 'rel-5', 'rel-6'])
          id: personaAccentForId(id, Brightness.dark),
      };
      expect(accents.values.toSet().length, greaterThan(1));
    });

    test('every accent comes from the exported token sets — no widget-local '
        'color literals', () {
      for (final brightness in Brightness.values) {
        final tokens = brightness == Brightness.dark
            ? dsTokensDark
            : dsTokensLight;
        final tokenAccents = {
          tokens.colors.interactive.enabled,
          GoalAccentHues.neon(brightness),
          GoalAccentHues.aurora(brightness),
          tokens.colors.alert.warning.ink,
          tokens.colors.alert.info.ink,
          tokens.colors.alert.success.ink,
        };
        for (var i = 0; i < 64; i++) {
          expect(
            tokenAccents,
            contains(personaAccentForId('rel-$i', brightness)),
            reason:
                'persona accents must resolve to design-system tokens so '
                'palette changes propagate from the token export',
          );
        }
      }
    });
  });

  group('personaInitial', () {
    test('returns the uppercased first letter of a name', () {
      expect(personaInitial('Anna'), 'A');
      expect(personaInitial('ben'), 'B');
      expect(personaInitial('  carla  '), 'C');
    });

    test('falls back to a middot for empty or null names', () {
      expect(personaInitial(''), '·');
      expect(personaInitial(null), '·');
      expect(personaInitial('   '), '·');
    });
  });

  group('PersonaAvatar', () {
    testWidgets('renders the initial and derives the accent from id', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: LegacyMaterialBridge.builder,
          theme: resolveTestTheme(),
          home: const PersonaAvatar(initial: 'A', id: 'rel-1'),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      // The avatar circle is a Container with a BoxShape.circle decoration.
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('honours an explicit accent over the id', (tester) async {
      const accent = Color(0xFF123456);
      await tester.pumpWidget(
        MaterialApp(
          builder: LegacyMaterialBridge.builder,
          theme: resolveTestTheme(),
          home: const PersonaAvatar(initial: 'A', id: 'rel-1', accent: accent),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, accent.withValues(alpha: 0.20));
    });

    testWidgets('asserts when neither id nor accent is given', (tester) async {
      // The constructor's `id != null || accent != null` assertion is a
      // hard failure, so constructing it directly is the cleanest proof.
      expect(
        () => PersonaAvatar(initial: 'A'),
        throwsA(isA<Object>()),
      );
    });

    testWidgets('uses the middot for an empty initial', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: LegacyMaterialBridge.builder,
          theme: resolveTestTheme(),
          home: const PersonaAvatar(initial: '', id: 'rel-1'),
        ),
      );
      expect(find.text('·'), findsOneWidget);
    });
  });
}
