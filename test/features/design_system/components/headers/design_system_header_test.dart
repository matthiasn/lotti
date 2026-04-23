import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/avatars/design_system_avatar.dart';
import 'package:lotti/features/design_system/components/breadcrumbs/design_system_breadcrumbs.dart';
import 'package:lotti/features/design_system/components/headers/design_system_header.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void _useWideViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('DesignSystemHeader', () {
    testWidgets('renders the desktop shell with token-driven title styling', (
      tester,
    ) async {
      _useWideViewport(tester);
      const leadingKey = Key('leading');
      const primaryActionKey = Key('primary-action');
      const trailingActionKey = Key('trailing-action');
      const avatarKey = Key('avatar');

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
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
      final headerShell = find
          .descendant(
            of: find.byType(DesignSystemHeader),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is SizedBox &&
                  widget.height == DesignSystemHeader.desktopHeight,
            ),
          )
          .first;

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

      final headerShell = find
          .descendant(
            of: find.byType(DesignSystemHeader),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is SizedBox &&
                  widget.height == DesignSystemHeader.desktopHeight,
            ),
          )
          .first;

      expect(
        tester.getSize(headerShell).height,
        DesignSystemHeader.desktopHeight,
      );
      expect(find.text('Only title'), findsOneWidget);
      expect(find.byType(DesignSystemBreadcrumbs), findsNothing);
      expect(find.byType(DesignSystemAvatar), findsNothing);
    });

    testWidgets(
      'long title without breadcrumbs ellipsizes inside its Expanded slot '
      'rather than overflowing the row',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const SizedBox(
              width: 720,
              child: DesignSystemHeader(
                leading: SizedBox.square(dimension: 36),
                title:
                    'This is a very long page title that should truncate before the action area',
                primaryAction: SizedBox(width: 179, height: 36),
                trailingActions: [
                  SizedBox.square(dimension: 36),
                  SizedBox.square(dimension: 36),
                ],
              ),
            ),
            theme: DesignSystemTheme.light(),
          ),
        );

        await tester.pump();

        expect(find.byType(DesignSystemHeader), findsOneWidget);
        expect(tester.takeException(), isNull);
        final title = tester.widget<Text>(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.data != null &&
                w.data!.startsWith('This is a very long'),
          ),
        );
        expect(title.overflow, TextOverflow.ellipsis);
        expect(title.maxLines, 1);
      },
    );

    testWidgets(
      'breadcrumbs expand to fill the remaining width while title stays '
      'intrinsic and the trailing cluster snaps to the right edge — the '
      'layout invariant removed when Flexible/Expanded split 50/50',
      (tester) async {
        _useWideViewport(tester);
        const trailingKey = Key('trailing-cluster');
        const breadcrumbsKey = Key('breadcrumbs-scroll');

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            SizedBox(
              width: 1440,
              child: DesignSystemHeader(
                leading: const SizedBox.square(dimension: 36),
                title: 'Sync',
                breadcrumbs: DesignSystemBreadcrumbs(
                  key: breadcrumbsKey,
                  items: [
                    DesignSystemBreadcrumbItem(
                      label: 'Settings',
                      onPressed: () {},
                    ),
                    DesignSystemBreadcrumbItem(
                      label: 'Integrations',
                      onPressed: () {},
                    ),
                    DesignSystemBreadcrumbItem(
                      label: 'Third-party sync providers',
                      onPressed: () {},
                    ),
                    const DesignSystemBreadcrumbItem(
                      label: 'Configuration details',
                      selected: true,
                      showChevron: false,
                    ),
                  ],
                ),
                trailingActions: const [
                  SizedBox.square(key: trailingKey, dimension: 36),
                ],
              ),
            ),
            theme: DesignSystemTheme.light(),
          ),
        );

        await tester.pump();
        expect(tester.takeException(), isNull);

        final headerRect = tester.getRect(find.byType(DesignSystemHeader));
        final trailingRect = tester.getRect(find.byKey(trailingKey));
        // The breadcrumbs `Expanded` wraps a SingleChildScrollView that
        // we use as a direct proxy for the allocated width — its
        // ancestor Expanded sizes it to fill remaining row space.
        final breadcrumbsScrollRect = tester.getRect(
          find.ancestor(
            of: find.byKey(breadcrumbsKey),
            matching: find.byType(SingleChildScrollView),
          ),
        );

        // Trailing cluster snaps to within ~tokens.spacing.step6 of the
        // right edge (the header's horizontal padding). If the
        // breadcrumbs column were only allocated 50%, the trailing
        // would sit well to the left of the right edge.
        expect(
          headerRect.right - trailingRect.right,
          lessThan(48),
          reason:
              'trailing should be flush with the header right edge, got '
              '${headerRect.right - trailingRect.right} px gap',
        );

        // Breadcrumbs scroll box occupies the bulk of the row between
        // title and trailing — comfortably more than half the header
        // width now that it is the sole flex child.
        expect(
          breadcrumbsScrollRect.width,
          greaterThan(headerRect.width * 0.6),
          reason:
              'breadcrumbs should fill remaining width, got '
              '${breadcrumbsScrollRect.width} px out of ${headerRect.width}',
        );
      },
    );
  });
}
