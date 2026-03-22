import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/avatars/design_system_avatar.dart';
import 'package:lotti/features/design_system/components/breadcrumbs/design_system_breadcrumbs.dart';
import 'package:lotti/features/design_system/components/headers/design_system_header.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  group('DesignSystemHeader', () {
    testWidgets('renders the desktop shell with token-driven title styling', (
      tester,
    ) async {
      const leadingKey = Key('leading');
      const primaryActionKey = Key('primary-action');
      const trailingActionKey = Key('trailing-action');
      const avatarKey = Key('avatar');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 1440,
            child: DesignSystemHeader(
              leading: const SizedBox.square(
                key: leadingKey,
                dimension: 36,
              ),
              title: 'API Configuration',
              breadcrumbs: DesignSystemBreadcrumbs(
                items: [
                  DesignSystemBreadcrumbItem(
                    label: 'Settings',
                    onPressed: () {},
                  ),
                  const DesignSystemBreadcrumbItem(
                    label: 'API Configuration',
                    selected: true,
                    showChevron: false,
                  ),
                ],
              ),
              primaryAction: const SizedBox(
                key: primaryActionKey,
                width: 179,
                height: 36,
              ),
              trailingActions: const [
                SizedBox.square(key: trailingActionKey, dimension: 36),
              ],
              trailingAvatar: DesignSystemAvatar(
                key: avatarKey,
                image: dsPlaceholderImage,
                size: DesignSystemAvatarSize.m32,
              ),
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final title = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data == 'API Configuration' &&
              widget.style?.fontSize == dsTokensLight.typography.size.heading2,
        ),
      );
      final headerShell = find.descendant(
        of: find.byType(DesignSystemHeader),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox &&
              widget.height == DesignSystemHeader.desktopHeight,
        ),
      );

      expect(
        tester.getSize(headerShell).height,
        DesignSystemHeader.desktopHeight,
      );
      expect(find.byKey(leadingKey), findsOneWidget);
      expect(find.byKey(primaryActionKey), findsOneWidget);
      expect(find.byKey(trailingActionKey), findsOneWidget);
      expect(find.byKey(avatarKey), findsOneWidget);
      expect(title.style?.fontSize, dsTokensLight.typography.size.heading2);
      expect(title.style?.fontWeight, dsTokensLight.typography.weight.bold);
      expect(title.style?.color, dsTokensLight.colors.text.highEmphasis);
    });

    testWidgets('omits optional slots without changing the desktop height', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 960,
            child: DesignSystemHeader(title: 'Only title'),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final headerShell = find.descendant(
        of: find.byType(DesignSystemHeader),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox &&
              widget.height == DesignSystemHeader.desktopHeight,
        ),
      );

      expect(
        tester.getSize(headerShell).height,
        DesignSystemHeader.desktopHeight,
      );
      expect(find.text('Only title'), findsOneWidget);
      expect(find.byType(DesignSystemBreadcrumbs), findsNothing);
      expect(find.byType(DesignSystemAvatar), findsNothing);
    });

    testWidgets('handles long titles and breadcrumb content without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 720,
            child: DesignSystemHeader(
              leading: const SizedBox.square(dimension: 36),
              title:
                  'This is a very long page title that should truncate before the action area',
              breadcrumbs: DesignSystemBreadcrumbs(
                items: [
                  DesignSystemBreadcrumbItem(
                    label: 'Settings',
                    onPressed: () {},
                  ),
                  const DesignSystemBreadcrumbItem(
                    label: 'API Configuration',
                    selected: true,
                    showChevron: false,
                  ),
                ],
              ),
              primaryAction: const SizedBox(width: 179, height: 36),
              trailingActions: const [
                SizedBox.square(dimension: 36),
                SizedBox.square(dimension: 36),
              ],
              trailingAvatar: DesignSystemAvatar(
                image: dsPlaceholderImage,
                size: DesignSystemAvatarSize.m32,
              ),
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      await tester.pump();

      expect(find.byType(DesignSystemHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
