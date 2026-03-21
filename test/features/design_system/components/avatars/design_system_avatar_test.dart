import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/avatars/design_system_avatar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  group('DesignSystemAvatar', () {
    testWidgets('renders the default l40 enabled avatar from tokens', (
      tester,
    ) async {
      const avatarKey = Key('default-avatar');

      await _pumpAvatar(
        tester,
        DesignSystemAvatar(
          key: avatarKey,
          image: dsPlaceholderImage,
          semanticsLabel: 'User avatar',
        ),
      );

      final size = tester.getSize(find.byKey(avatarKey));
      final decoration = _avatarDecoration(tester, avatarKey);
      final border = decoration.border! as Border;

      expect(size, const Size.square(40));
      expect(decoration.shape, BoxShape.circle);
      expect(border.top.width, 2);
      expect(
        border.top.color,
        dsTokensLight.colors.decorative.level02,
      );
      expect(decoration.image, isNotNull);
      expect(decoration.image!.fit, BoxFit.cover);
    });

    testWidgets('renders connected status with success color', (
      tester,
    ) async {
      const avatarKey = Key('connected-avatar');

      await _pumpAvatar(
        tester,
        DesignSystemAvatar(
          key: avatarKey,
          image: dsPlaceholderImage,
          status: DesignSystemAvatarStatus.connected,
          semanticsLabel: 'Connected user',
        ),
      );

      final border = _avatarDecoration(tester, avatarKey).border! as Border;

      expect(
        border.top.color,
        dsTokensLight.colors.alert.success.defaultColor,
      );
    });

    testWidgets('renders away status with warning color', (tester) async {
      const avatarKey = Key('away-avatar');

      await _pumpAvatar(
        tester,
        DesignSystemAvatar(
          key: avatarKey,
          image: dsPlaceholderImage,
          status: DesignSystemAvatarStatus.away,
          semanticsLabel: 'Away user',
        ),
      );

      final border = _avatarDecoration(tester, avatarKey).border! as Border;

      expect(
        border.top.color,
        dsTokensLight.colors.alert.warning.defaultColor,
      );
    });

    testWidgets('renders busy status with error color', (tester) async {
      const avatarKey = Key('busy-avatar');

      await _pumpAvatar(
        tester,
        DesignSystemAvatar(
          key: avatarKey,
          image: dsPlaceholderImage,
          status: DesignSystemAvatarStatus.busy,
          semanticsLabel: 'Busy user',
        ),
      );

      final border = _avatarDecoration(tester, avatarKey).border! as Border;

      expect(
        border.top.color,
        dsTokensLight.colors.alert.error.defaultColor,
      );
    });

    group('sizes and border widths', () {
      final sizeSpecs = {
        DesignSystemAvatarSize.xs20: (dimension: 20.0, borderWidth: 1.0),
        DesignSystemAvatarSize.s24: (dimension: 24.0, borderWidth: 1.0),
        DesignSystemAvatarSize.m32: (dimension: 32.0, borderWidth: 1.0),
        DesignSystemAvatarSize.l40: (dimension: 40.0, borderWidth: 2.0),
        DesignSystemAvatarSize.xl48: (dimension: 48.0, borderWidth: 2.0),
        DesignSystemAvatarSize.xxl64: (dimension: 64.0, borderWidth: 2.0),
        DesignSystemAvatarSize.xxxl80: (dimension: 80.0, borderWidth: 3.0),
        DesignSystemAvatarSize.jumbo96: (dimension: 96.0, borderWidth: 4.0),
      };

      for (final MapEntry(:key, :value) in sizeSpecs.entries) {
        testWidgets(
          'renders ${key.name} at ${value.dimension}px with '
          '${value.borderWidth}px border',
          (tester) async {
            final avatarKey = Key('${key.name}-avatar');

            await _pumpAvatar(
              tester,
              DesignSystemAvatar(
                key: avatarKey,
                image: dsPlaceholderImage,
                size: key,
                semanticsLabel: '${key.name} avatar',
              ),
            );

            final size = tester.getSize(find.byKey(avatarKey));
            final border =
                _avatarDecoration(tester, avatarKey).border! as Border;

            expect(size, Size.square(value.dimension));
            expect(border.top.width, value.borderWidth);
          },
        );
      }
    });

    testWidgets('provides semantics label and image trait', (tester) async {
      const avatarKey = Key('semantics-avatar');

      await _pumpAvatar(
        tester,
        DesignSystemAvatar(
          key: avatarKey,
          image: dsPlaceholderImage,
          semanticsLabel: 'Profile picture',
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(avatarKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Profile picture' &&
                widget.properties.image == true,
          ),
        ),
      );

      expect(semantics.properties.label, 'Profile picture');
      expect(semantics.properties.image, isTrue);
    });

    testWidgets('uses dark theme tokens for status colors', (tester) async {
      const avatarKey = Key('dark-connected');

      await _pumpAvatar(
        tester,
        DesignSystemAvatar(
          key: avatarKey,
          image: dsPlaceholderImage,
          status: DesignSystemAvatarStatus.connected,
          semanticsLabel: 'Dark avatar',
        ),
        theme: DesignSystemTheme.dark(),
      );

      final border = _avatarDecoration(tester, avatarKey).border! as Border;

      expect(
        border.top.color,
        dsTokensDark.colors.alert.success.defaultColor,
      );
    });

    testWidgets(
      'enabled border adapts to dark theme via decorative token',
      (tester) async {
        const avatarKey = Key('dark-enabled');

        await _pumpAvatar(
          tester,
          DesignSystemAvatar(
            key: avatarKey,
            image: dsPlaceholderImage,
            semanticsLabel: 'Dark enabled avatar',
          ),
          theme: DesignSystemTheme.dark(),
        );

        final border = _avatarDecoration(tester, avatarKey).border! as Border;

        expect(
          border.top.color,
          dsTokensDark.colors.decorative.level02,
        );
      },
    );
  });
}

Future<void> _pumpAvatar(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      child,
      theme: theme ?? DesignSystemTheme.light(),
    ),
  );
}

BoxDecoration _avatarDecoration(WidgetTester tester, Key key) {
  final decoratedBox = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byKey(key),
      matching: find.byType(DecoratedBox),
    ),
  );
  return decoratedBox.decoration as BoxDecoration;
}
