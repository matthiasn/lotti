import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_contact_row.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_five_slot_nav_bar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

const _wideRow = 400.0;
const _minimumSidebarWidth = 200.0;

void main() {
  Widget wrap(Widget child, {double width = _wideRow}) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
  }

  const emailKey = Key('email');
  const manualKey = Key('manual');
  const githubKey = Key('github');
  const discordKey = Key('discord');
  const actionKeys = [emailKey, manualKey, githubKey, discordKey];

  DesignSystemContactRow buildRow({void Function(String)? onAction}) {
    return DesignSystemContactRow(
      actions: [
        DesignSystemContactAction(
          icon: const Icon(Icons.mail_outline_rounded),
          label: 'Contact Us',
          iconKey: emailKey,
          onPressed: () => onAction?.call('email'),
        ),
        DesignSystemContactAction(
          icon: const Icon(Icons.menu_book_outlined),
          label: 'Manual',
          iconKey: manualKey,
          onPressed: () => onAction?.call('manual'),
        ),
        DesignSystemContactAction(
          icon: const Icon(Icons.code),
          label: 'GitHub',
          iconKey: githubKey,
          onPressed: () => onAction?.call('github'),
        ),
        DesignSystemContactAction(
          icon: const Icon(Icons.forum_outlined),
          label: 'Discord',
          iconKey: discordKey,
          onPressed: () => onAction?.call('discord'),
        ),
      ],
    );
  }

  group('DesignSystemContactRow rendering', () {
    testWidgets('renders every destination as a glyph-only action', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      expect(find.text('Contact Us'), findsNothing);
      expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.byIcon(Icons.code), findsOneWidget);
      expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
    });

    testWidgets('draws no rule above the group', (tester) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      // These are the quietest controls either navigation surface has. A
      // divider gave them the weight of a section boundary, announcing a
      // separation from Settings that neither surface actually has.
      expect(find.byType(DesignSystemDivider), findsNothing);
    });

    testWidgets('separates itself from the content above with spacing', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      // Distance is the whole separation now, so it belongs to the band
      // rather than to whatever the host happens to put above it.
      final band = tester.getRect(find.byType(DesignSystemContactRow));
      final firstAction = tester.getRect(find.byKey(emailKey));
      expect(firstAction.top - band.top, dsTokensDark.spacing.step2);
    });

    testWidgets('keeps the actions in the supplied order', (tester) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      final xs = [
        for (final key in actionKeys) tester.getCenter(find.byKey(key)).dx,
      ];
      expect(xs, orderedEquals([...xs]..sort()));
    });
  });

  group('DesignSystemContactRow activation', () {
    testWidgets('each glyph invokes only its own callback', (tester) async {
      final actions = <String>[];
      await tester.pumpWidget(wrap(buildRow(onAction: actions.add)));
      await tester.pump();

      for (final key in actionKeys) {
        await tester.tap(find.byKey(key));
        await tester.pump();
      }

      expect(actions, ['email', 'manual', 'github', 'discord']);
    });
  });

  group('DesignSystemContactRow layout', () {
    testWidgets('right-aligns four uniform targets as one contiguous group', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      final targets = [
        for (final key in actionKeys) tester.getRect(find.byKey(key)),
      ];
      const expectedSize = Size.square(
        DesignSystemFiveSlotNavBar.minTapTarget,
      );

      for (final target in targets) {
        expect(target.size, expectedSize);
        expect(target.center.dy, closeTo(targets.first.center.dy, 0.5));
      }
      for (var i = 1; i < targets.length; i++) {
        expect(targets[i].left, closeTo(targets[i - 1].right, 0.5));
      }

      expect(
        targets.last.right,
        closeTo(_wideRow - dsTokensDark.spacing.step3, 0.5),
      );
    });

    testWidgets('fits the complete group at the sidebar minimum width', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(buildRow(), width: _minimumSidebarWidth),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final row = tester.getRect(find.byType(DesignSystemContactRow));
      final targets = [
        for (final key in actionKeys) tester.getRect(find.byKey(key)),
      ];
      expect(targets.first.left, greaterThanOrEqualTo(row.left));
      expect(targets.last.right, lessThan(row.right));
      expect(targets.map((target) => target.center.dy).toSet(), hasLength(1));
    });

    testWidgets('insets the actions inside the full-bleed band', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      final row = tester.getRect(find.byType(DesignSystemContactRow));
      final lastAction = tester.getRect(find.byKey(discordKey));

      // `step3`, not the rail's `step5` gutter: four 44 px targets need
      // 176 px and a step5-inset 200 px rail leaves only 168 px, so the group
      // would wrap. This is the reason the band is full-bleed at all.
      expect(row.right - lastAction.right, dsTokensDark.spacing.step3);
    });
  });

  group('DesignSystemContactRow theming', () {
    testWidgets('sizes and tints every glyph from one ambient icon theme', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      for (final icon in [
        Icons.mail_outline_rounded,
        Icons.menu_book_outlined,
        Icons.code,
        Icons.forum_outlined,
      ]) {
        final iconTheme = IconTheme.of(tester.element(find.byIcon(icon)));
        expect(iconTheme.size, IconSizes.m);
        expect(iconTheme.color, dsTokensDark.colors.text.mediumEmphasis);
      }
    });
  });

  group('DesignSystemContactRow semantics', () {
    testWidgets('gives every glyph an accessible button name', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      for (final label in ['Contact Us', 'Manual', 'GitHub', 'Discord']) {
        final finder = find.bySemanticsLabel(label);
        expect(finder, findsOneWidget);
        expect(
          tester
              .getSemantics(finder)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
      }

      handle.dispose();
    });

    testWidgets('activating a glyph through semantics fires its callback', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final actions = <String>[];
      await tester.pumpWidget(wrap(buildRow(onAction: actions.add)));
      await tester.pump();

      final node = tester.getSemantics(find.bySemanticsLabel('Contact Us'));
      // ignore: deprecated_member_use
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.tap,
      );
      await tester.pump();

      expect(actions, ['email']);
      handle.dispose();
    });

    testWidgets('offers every glyph a tooltip for pointer users', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      final tooltips = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((tooltip) => tooltip.message)
          .toList();
      expect(
        tooltips,
        containsAll(['Contact Us', 'Manual', 'GitHub', 'Discord']),
      );
    });
  });
}
