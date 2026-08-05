import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_contact_row.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_five_slot_nav_bar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

/// A rail with room for the label and all three glyphs on one line.
///
/// Sized against the *test* font, whose glyphs are considerably wider than the
/// shipping one — "Contact Us" measures 160 px here where the real face gives
/// about half that. Both fixtures are therefore calibrated to observed widths
/// rather than to sidebar constants; the sidebar can be dragged anywhere
/// between `minSidebarWidth` (200) and `maxSidebarWidth` (500), so each
/// fixture stands for one side of the wrap threshold rather than for a
/// specific pane width.
const _wideRow = 400.0;

/// A rail too narrow for one line: three 48 px targets alone leave 24 px, and
/// the label needs far more than that.
const _narrowRow = 168.0;

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

  const manualKey = Key('manual');
  const githubKey = Key('github');
  const discordKey = Key('discord');
  const labelKey = Key('label');

  DesignSystemContactRow buildRow({
    VoidCallback? onLabelPressed,
    void Function(String)? onAction,
    String label = 'Contact Us',
  }) {
    return DesignSystemContactRow(
      label: label,
      labelIcon: Icons.mail_outline_rounded,
      labelKey: labelKey,
      onLabelPressed: onLabelPressed ?? () {},
      actions: [
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
    testWidgets('renders the label and every action glyph', (tester) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      expect(find.text('Contact Us'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.byIcon(Icons.code), findsOneWidget);
      expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
    });

    testWidgets('separates itself from what sits above with a rule', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      expect(find.byType(DesignSystemDivider), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(DesignSystemDivider)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text('Contact Us')).dy),
        reason: 'the rule belongs above the row, not through it',
      );
    });

    testWidgets('keeps the actions in the order they were given', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      final xs = [
        for (final key in [manualKey, githubKey, discordKey])
          tester.getCenter(find.byKey(key)).dx,
      ];

      expect(xs, orderedEquals([...xs]..sort()));
    });
  });

  group('DesignSystemContactRow activation', () {
    testWidgets('tapping the label invokes only the label callback', (
      tester,
    ) async {
      var labelTaps = 0;
      final actions = <String>[];

      await tester.pumpWidget(
        wrap(
          buildRow(
            onLabelPressed: () => labelTaps++,
            onAction: actions.add,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(labelKey));
      await tester.pump();

      expect(labelTaps, 1);
      expect(actions, isEmpty);
    });

    testWidgets('each glyph invokes its own callback and no other', (
      tester,
    ) async {
      final actions = <String>[];

      await tester.pumpWidget(wrap(buildRow(onAction: actions.add)));
      await tester.pump();

      await tester.tap(find.byKey(githubKey));
      await tester.pump();
      expect(actions, ['github']);

      await tester.tap(find.byKey(discordKey));
      await tester.pump();
      expect(actions, ['github', 'discord']);

      await tester.tap(find.byKey(manualKey));
      await tester.pump();
      expect(actions, ['github', 'discord', 'manual']);
    });

    testWidgets('every target clears the navigation tap floor', (tester) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      for (final key in [manualKey, githubKey, discordKey]) {
        final size = tester.getSize(find.byKey(key));
        expect(
          size.width,
          greaterThanOrEqualTo(DesignSystemFiveSlotNavBar.minTapTarget),
        );
        expect(
          size.height,
          greaterThanOrEqualTo(DesignSystemFiveSlotNavBar.minTapTarget),
        );
      }

      // The label legitimately sits one step lower, at `DesignSystemInlineAction`'s
      // own `spacing.step8` floor. The 44 px rule exists because a glyph-only
      // control has no label to borrow hit area from; this one is ~90 px of
      // text and glyph wide, so height is not its only dimension.
      expect(
        tester.getSize(find.byKey(labelKey)).height,
        greaterThanOrEqualTo(dsTokensDark.spacing.step8),
      );
    });
  });

  group('DesignSystemContactRow layout', () {
    testWidgets('pushes label and glyphs to opposite edges when both fit', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      final labelRect = tester.getRect(find.byKey(labelKey));
      final discordRect = tester.getRect(find.byKey(discordKey));

      // Each sits on its own edge of the band's inset — the wrap's free space
      // all goes between them, not around them.
      final inset = dsTokensDark.spacing.step3;
      expect(labelRect.left, inset);
      expect(discordRect.right, _wideRow - inset);
      // One line: their vertical centres coincide.
      expect(labelRect.center.dy, closeTo(discordRect.center.dy, 0.5));
    });

    testWidgets(
      'drops the glyph group below the label when the rail is narrow',
      (tester) async {
        await tester.pumpWidget(wrap(buildRow(), width: _narrowRow));
        await tester.pump();

        final labelRect = tester.getRect(find.byKey(labelKey));
        final manualRect = tester.getRect(find.byKey(manualKey));

        expect(
          manualRect.top,
          greaterThanOrEqualTo(labelRect.bottom),
          reason:
              'the glyphs should take their own line, not overlap the label',
        );
      },
    );

    testWidgets('keeps the glyph group intact rather than splitting it', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildRow(), width: _narrowRow));
      await tester.pump();

      // Wrapping the glyphs individually would leave a ragged two-then-one
      // stack; they travel as one unit precisely to avoid that.
      final centres = [
        for (final key in [manualKey, githubKey, discordKey])
          tester.getCenter(find.byKey(key)).dy,
      ];
      expect(centres.toSet(), hasLength(1));
    });

    testWidgets('leaves the default rail enough width for the label', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      // The budget, not the laid-out line: the test face is far wider than the
      // shipping one ("Contact Us" measures 160 px here against roughly half
      // that in Inter), so asserting "these two sit on one row" at 224 px would
      // test the test font. What must hold regardless of face is that the glyph
      // group leaves the label a workable share of the rail — at 48 px targets
      // the group alone took 144 of 224 and the row wrapped at the *default*
      // sidebar width, making the fallback the common case.
      const railContentWidth = 224.0; // defaultSidebarWidth 256 − 2 × 16 gutter
      final group = tester
          .getRect(find.byKey(manualKey))
          .expandToInclude(tester.getRect(find.byKey(discordKey)));

      expect(group.width, 3 * DesignSystemFiveSlotNavBar.minTapTarget);
      expect(railContentWidth - group.width, greaterThanOrEqualTo(90));
    });

    testWidgets('insets the label ink from its own content', (tester) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      // The hover and press fill paint to the target's bounds. Flush against
      // the content they read as a rendering fault rather than as a control —
      // which is exactly what a bare, unpadded tap target looked like here.
      final target = tester.getRect(find.byKey(labelKey));
      final glyph = tester.getRect(find.byIcon(Icons.mail_outline_rounded));
      final text = tester.getRect(find.text('Contact Us'));

      expect(target.left, lessThan(glyph.left));
      expect(target.right, greaterThan(text.right));
      expect(target.top, lessThan(text.top));
      expect(target.bottom, greaterThan(text.bottom));
    });

    testWidgets('runs the rule full width while insetting the content', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      // The band is handed the sidebar's full width (see
      // `DesktopNavigationSidebar.footerBand`) and owns its own inset. The
      // rule spends none of it: a divider stopping short of both edges reads
      // as a row that failed to line up rather than as the foot of the panel.
      final rule = tester.getRect(find.byType(DesignSystemDivider));
      final row = tester.getRect(find.byType(DesignSystemContactRow));
      expect(rule.left, row.left);
      expect(rule.right, row.right);

      // The content does not — otherwise the label's hover fill would bleed
      // off the rail edge.
      final label = tester.getRect(find.byKey(labelKey));
      final lastGlyph = tester.getRect(find.byKey(discordKey));
      expect(label.left, greaterThan(row.left));
      expect(lastGlyph.right, lessThan(row.right));
    });

    testWidgets('leads the label with its glyph', (tester) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      // At rest a caption-tier action has neither fill nor border, so the
      // glyph is the only thing marking the words as tappable.
      final glyph = tester.getRect(find.byIcon(Icons.mail_outline_rounded));
      final text = tester.getRect(find.text('Contact Us'));
      expect(glyph.right, lessThanOrEqualTo(text.left));
      expect(glyph.center.dy, closeTo(text.center.dy, 1));
    });

    testWidgets('renders a long label without overflowing', (tester) async {
      await tester.pumpWidget(
        wrap(
          buildRow(
            label: 'Kontaktiere uns über eine ausgesprochen lange Beschriftung',
          ),
          width: _narrowRow,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      final text = tester.widget<Text>(
        find.text('Kontaktiere uns über eine ausgesprochen lange Beschriftung'),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });

  group('DesignSystemContactRow theming', () {
    testWidgets('sizes and tints glyphs from one ambient icon theme', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      // Glyphs read the row's IconTheme instead of each carrying their own
      // size and colour — that is what lets a bundled vector mark match the
      // font icons beside it.
      for (final icon in [
        Icons.menu_book_outlined,
        Icons.code,
        Icons.forum_outlined,
      ]) {
        final iconTheme = IconTheme.of(tester.element(find.byIcon(icon)));
        expect(iconTheme.size, IconSizes.m);
        expect(iconTheme.color, dsTokensDark.colors.text.mediumEmphasis);
      }
    });

    testWidgets('renders the label at the caption tier, not the body tier', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      // Caption is the tier the sidebar's own saved-filter rows use. At the
      // body tier this footer out-weighed the destinations above it, which is
      // backwards: nothing down here is a destination.
      final style = tester.widget<Text>(find.text('Contact Us')).style!;
      expect(style.color, dsTokensDark.colors.text.mediumEmphasis);
      expect(
        style.fontSize,
        dsTokensDark.typography.styles.others.caption.fontSize,
      );
      expect(
        style.fontSize,
        lessThan(dsTokensDark.typography.styles.body.bodyMedium.fontSize!),
      );
    });
  });

  group('DesignSystemContactRow semantics', () {
    testWidgets('announces the label affordance as a button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      expect(
        find.bySemanticsLabel('Contact Us'),
        findsOneWidget,
        reason: 'exactly one node — the visual subtree must not add a second',
      );

      handle.dispose();
    });

    testWidgets('gives every glyph a name a screen reader can read out', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      for (final label in ['Manual', 'GitHub', 'Discord']) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
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

      final node = tester.getSemantics(find.bySemanticsLabel('Discord'));
      // ignore: deprecated_member_use
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.tap,
      );
      await tester.pump();

      expect(actions, ['discord']);
      handle.dispose();
    });

    testWidgets('offers each glyph a tooltip for pointer users', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildRow()));
      await tester.pump();

      final tooltips = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((tooltip) => tooltip.message)
          .toList();
      expect(tooltips, containsAll(['Manual', 'GitHub', 'Discord']));
    });
  });
}
