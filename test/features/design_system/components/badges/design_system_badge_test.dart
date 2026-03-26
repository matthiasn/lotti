import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemBadge', () {
    testWidgets('renders the primary dot badge from tokens', (tester) async {
      await _pumpBadge(
        tester,
        const DesignSystemBadge.dot(),
      );

      final decoration = _badgeDecoration(tester);

      expect(_badgeSize(tester), const Size.square(8));
      expect(
        decoration.color,
        dsTokensLight.colors.alert.info.defaultColor,
      );
      expect(
        decoration.borderRadius,
        BorderRadius.circular(dsTokensLight.spacing.step3 / 2),
      );
      expect(decoration.border, isNull);
    });

    testWidgets('renders the warning dot badge from tokens', (tester) async {
      await _pumpBadge(
        tester,
        const DesignSystemBadge.dot(
          tone: DesignSystemBadgeTone.warning,
        ),
      );

      final decoration = _badgeDecoration(tester);

      expect(
        decoration.color,
        dsTokensLight.colors.alert.warning.defaultColor,
      );
    });

    testWidgets('supports an explicit semantics label for dot badges', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      await _pumpBadge(
        tester,
        const DesignSystemBadge.dot(
          semanticLabel: 'Unread notifications',
        ),
      );

      expect(find.bySemanticsLabel('Unread notifications'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('renders the secondary dot badge visibly from tokens', (
      tester,
    ) async {
      await _pumpBadge(
        tester,
        const DesignSystemBadge.dot(
          tone: DesignSystemBadgeTone.secondary,
        ),
      );

      final decoration = _badgeDecoration(tester);

      expect(
        decoration.color,
        dsTokensLight.colors.alert.info.defaultColor,
      );
      expect(decoration.border, isNull);
    });

    testWidgets('renders the secondary number badge from tokens', (
      tester,
    ) async {
      await _pumpBadge(
        tester,
        const DesignSystemBadge.number(
          value: '10',
          tone: DesignSystemBadgeTone.secondary,
        ),
      );

      final decoration = _badgeDecoration(tester);
      final richText = _findTextNode(tester, '10');

      expect(_badgeSize(tester), const Size.square(20));
      expect(decoration.color, dsTokensLight.colors.alert.info.defaultColor);
      expectTextStyle(
        richText.text.style!,
        dsTokensLight.typography.styles.others.caption,
        dsTokensLight.colors.text.onInteractiveAlert,
      );
    });

    testWidgets('lets number badges grow for wider values', (tester) async {
      await _pumpBadge(
        tester,
        const DesignSystemBadge.number(
          value: '99+',
          tone: DesignSystemBadgeTone.secondary,
        ),
      );

      final size = _badgeSize(tester);

      expect(size.height, 20);
      expect(size.width, greaterThan(size.height));
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('applies horizontal padding for 3+ char number badges', (
      tester,
    ) async {
      await _pumpBadge(
        tester,
        const DesignSystemBadge.number(value: '999+'),
      );

      final size = _badgeSize(tester);
      final decoration = _badgeDecoration(tester);

      // Should be a pill shape (wider than tall) with rounded corners
      expect(size.width, greaterThan(size.height));
      expect(size.height, 20);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(10), // badgeHeight / 2
      );
    });

    testWidgets('compact number badges remain square', (tester) async {
      await _pumpBadge(
        tester,
        const DesignSystemBadge.number(value: '5'),
      );

      final size = _badgeSize(tester);

      // 1-2 char numbers should be square
      expect(size.width, size.height);
    });

    testWidgets('renders the filled danger badge from tokens', (tester) async {
      await _pumpBadge(
        tester,
        const DesignSystemBadge.filled(
          label: 'Danger',
          tone: DesignSystemBadgeTone.danger,
        ),
      );

      final decoration = _badgeDecoration(tester);
      final richText = _findTextNode(tester, 'Danger');

      expect(_badgeSize(tester).height, 20);
      expect(
        decoration.color,
        dsTokensLight.colors.alert.error.defaultColor,
      );
      expect(decoration.border, isNull);
      expectTextStyle(
        richText.text.style!,
        dsTokensLight.typography.styles.others.caption,
        dsTokensLight.colors.text.onInteractiveAlert,
      );
    });

    testWidgets('renders the primary outlined badge from tokens', (
      tester,
    ) async {
      await _pumpBadge(
        tester,
        const DesignSystemBadge.outlined(label: 'Outlined'),
      );

      final decoration = _badgeDecoration(tester);
      final border = decoration.border! as Border;
      final richText = _findTextNode(tester, 'Outlined');

      expect(_badgeSize(tester).height, 20);
      expect(decoration.color, isNull);
      expect(
        border.top.width,
        dsTokensLight.spacing.step1 / 2,
      );
      expect(
        border.top.color,
        dsTokensLight.colors.alert.info.defaultColor,
      );
      expectTextStyle(
        richText.text.style!,
        dsTokensLight.typography.styles.others.caption,
        dsTokensLight.colors.alert.info.defaultColor,
      );
    });

    testWidgets('renders the secondary outlined badge with a border', (
      tester,
    ) async {
      await _pumpBadge(
        tester,
        const DesignSystemBadge.outlined(
          label: 'Outlined',
          tone: DesignSystemBadgeTone.secondary,
        ),
      );

      final decoration = _badgeDecoration(tester);
      final border = decoration.border! as Border;
      final richText = _findTextNode(tester, 'Outlined');

      expect(decoration.color, dsTokensLight.colors.surface.enabled);
      expect(
        border.top.color,
        dsTokensLight.colors.alert.info.defaultColor,
      );
      expectTextStyle(
        richText.text.style!,
        dsTokensLight.typography.styles.others.caption,
        dsTokensLight.colors.alert.info.defaultColor,
      );
    });

    testWidgets('renders the success icon badge from tokens', (tester) async {
      await _pumpBadge(
        tester,
        const DesignSystemBadge.icon(
          icon: Icons.check_rounded,
          tone: DesignSystemBadgeTone.success,
          semanticLabel: 'Success status',
        ),
      );

      final decoration = _badgeDecoration(tester);
      final iconTheme = tester.widget<IconTheme>(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconTheme &&
              widget.data.size == dsTokensLight.typography.lineHeight.caption &&
              widget.data.color == dsTokensLight.colors.text.onInteractiveAlert,
        ),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_rounded));

      expect(_badgeSize(tester), const Size.square(20));
      expect(
        decoration.color,
        dsTokensLight.colors.alert.success.defaultColor,
      );
      expect(
        iconTheme.data.size,
        dsTokensLight.typography.lineHeight.caption,
      );
      expect(
        iconTheme.data.color,
        dsTokensLight.colors.text.onInteractiveAlert,
      );
      expect(icon.icon, Icons.check_rounded);
      expect(find.bySemanticsLabel('Success status'), findsOneWidget);
    });

    testWidgets('supports semanticLabel on number badges', (tester) async {
      final semantics = tester.ensureSemantics();

      await _pumpBadge(
        tester,
        const DesignSystemBadge.number(
          value: '5',
          semanticLabel: '5 unread messages',
        ),
      );

      expect(find.bySemanticsLabel('5 unread messages'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('supports semanticLabel on filled badges', (tester) async {
      final semantics = tester.ensureSemantics();

      await _pumpBadge(
        tester,
        const DesignSystemBadge.filled(
          label: 'New',
          semanticLabel: 'New items available',
        ),
      );

      expect(find.bySemanticsLabel('New items available'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('supports semanticLabel on outlined badges', (tester) async {
      final semantics = tester.ensureSemantics();

      await _pumpBadge(
        tester,
        const DesignSystemBadge.outlined(
          label: 'Beta',
          semanticLabel: 'Beta feature',
        ),
      );

      expect(find.bySemanticsLabel('Beta feature'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('excludeFromSemantics works on filled badges', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      await _pumpBadge(
        tester,
        const DesignSystemBadge.filled(
          key: Key('hidden-badge'),
          label: 'Hidden',
          excludeFromSemantics: true,
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('hidden-badge')),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('keeps badge geometry fixed when text scaling is increased', (
      tester,
    ) async {
      await _pumpBadge(
        tester,
        const DesignSystemBadge.filled(label: 'Scaled'),
        mediaQueryData: phoneMediaQueryData.copyWith(
          textScaler: const TextScaler.linear(2),
        ),
      );

      final richText = _findTextNode(tester, 'Scaled');

      expect(_badgeSize(tester).height, 20);
      expect(richText.textScaler, TextScaler.noScaling);
    });

    testWidgets('uses the active dark theme tokens', (tester) async {
      await _pumpBadge(
        tester,
        const DesignSystemBadge.filled(label: 'Primary'),
        theme: DesignSystemTheme.dark(),
      );

      final decoration = _badgeDecoration(tester);
      final richText = _findTextNode(tester, 'Primary');

      expect(
        decoration.color,
        dsTokensDark.colors.alert.info.defaultColor,
      );
      expectTextStyle(
        richText.text.style!,
        dsTokensDark.typography.styles.others.caption,
        dsTokensDark.colors.text.onInteractiveAlert,
      );
    });
  });
}

Future<void> _pumpBadge(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  MediaQueryData? mediaQueryData,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      child,
      theme: theme ?? DesignSystemTheme.light(),
      mediaQueryData: mediaQueryData,
    ),
  );
}

BoxDecoration _badgeDecoration(WidgetTester tester) {
  final decoratedBox = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
  return decoratedBox.decoration as BoxDecoration;
}

Size _badgeSize(WidgetTester tester) {
  return tester.getSize(find.byType(DecoratedBox));
}

RichText _findTextNode(WidgetTester tester, String label) {
  return tester.widget<RichText>(
    find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == label,
    ),
  );
}
