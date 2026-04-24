import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_tree_row.dart';

import '../../../../widget_test_utils.dart';

SettingsNode _branch({NodeBadge? badge}) => SettingsNode(
  id: 'sync',
  icon: Icons.sync_rounded,
  title: 'Sync',
  desc: 'Configure sync and view stats',
  badge: badge,
  children: const [
    SettingsNode(
      id: 'sync/backfill',
      icon: Icons.cloud_download_outlined,
      title: 'Backfill',
      desc: 'Manage sync gap recovery',
      panel: 'sync-backfill',
    ),
  ],
);

SettingsNode _leaf({NodeBadge? badge, String desc = 'Feature flags'}) =>
    SettingsNode(
      id: 'flags',
      icon: Icons.flag_outlined,
      title: 'Flags',
      desc: desc,
      panel: 'flags',
      badge: badge,
    );

Future<void> _pumpRow(
  WidgetTester tester, {
  required SettingsNode node,
  bool onActivePath = false,
  bool isExpanded = false,
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Material(
        child: SizedBox(
          width: 400,
          child: SettingsTreeRow(
            node: node,
            depth: 0,
            onActivePath: onActivePath,
            isExpanded: isExpanded,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('SettingsTreeRow — content', () {
    testWidgets('renders title and description', (tester) async {
      await _pumpRow(tester, node: _leaf());
      expect(find.text('Flags'), findsOneWidget);
      expect(find.text('Feature flags'), findsOneWidget);
    });

    testWidgets('renders the node icon', (tester) async {
      await _pumpRow(tester, node: _leaf());
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    });

    testWidgets('description is omitted when the node desc is empty', (
      tester,
    ) async {
      await _pumpRow(tester, node: _leaf(desc: ''));
      // Title still present, and the title+desc inner Column collapses
      // to a single Text child. We find that inner column (the one
      // directly wrapping the title in an Expanded) and assert its
      // child count so the "if desc.isNotEmpty" branch is exercised
      // — `findsNothing` on text '' would match even if the widget
      // shipped an empty Text placeholder.
      expect(find.text('Flags'), findsOneWidget);
      final titleColumn = tester.widget<Column>(
        find
            .ancestor(
              of: find.text('Flags'),
              matching: find.byType(Column),
            )
            .first,
      );
      expect(titleColumn.children, hasLength(1));
    });
  });

  group('SettingsTreeRow — branch chevron', () {
    testWidgets('renders a chevron for branches', (tester) async {
      await _pumpRow(tester, node: _branch());
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('omits chevron for leaves', (tester) async {
      await _pumpRow(tester, node: _leaf());
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('chevron is rotated a quarter-turn when the branch is open', (
      tester,
    ) async {
      await _pumpRow(tester, node: _branch(), isExpanded: true);
      await tester.pump(const Duration(milliseconds: 300));
      final rotation = tester.widget<AnimatedRotation>(
        find.ancestor(
          of: find.byIcon(Icons.chevron_right_rounded),
          matching: find.byType(AnimatedRotation),
        ),
      );
      expect(rotation.turns, 0.25);
    });

    testWidgets('chevron is zero-turn when the branch is closed', (
      tester,
    ) async {
      await _pumpRow(tester, node: _branch());
      final rotation = tester.widget<AnimatedRotation>(
        find.ancestor(
          of: find.byIcon(Icons.chevron_right_rounded),
          matching: find.byType(AnimatedRotation),
        ),
      );
      expect(rotation.turns, 0);
    });
  });

  group('SettingsTreeRow — badge', () {
    testWidgets('renders a badge label when present', (tester) async {
      await _pumpRow(
        tester,
        node: _leaf(
          badge: const NodeBadge(label: 'v2.4', tone: NodeTone.info),
        ),
      );
      expect(find.text('v2.4'), findsOneWidget);
    });

    testWidgets('omits the badge chip when no badge is set', (tester) async {
      await _pumpRow(tester, node: _leaf());
      expect(find.text('v2.4'), findsNothing);
      expect(find.text('Live'), findsNothing);
    });

    testWidgets('renders each NodeTone without throwing', (tester) async {
      for (final tone in NodeTone.values) {
        await _pumpRow(
          tester,
          node: _leaf(
            badge: NodeBadge(label: tone.name, tone: tone),
          ),
        );
        expect(find.text(tone.name), findsOneWidget);
      }
    });
  });

  group('SettingsTreeRow — interaction', () {
    testWidgets('tap invokes the onTap callback', (tester) async {
      var taps = 0;
      await _pumpRow(
        tester,
        node: _leaf(),
        onTap: () => taps++,
      );
      await tester.tap(find.byType(SettingsTreeRow));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('SettingsTreeRow — semantics', () {
    testWidgets('exposes button + selected + label for a selected leaf', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        node: _leaf(),
        onActivePath: true,
      );
      final node = tester.getSemantics(find.byType(SettingsTreeRow));
      final flags = node.getSemanticsData().flagsCollection;
      expect(node.label, contains('Flags'));
      expect(flags.isButton, isTrue);
      expect(flags.isSelected, Tristate.isTrue);
    });

    testWidgets('branches with isExpanded=true expose Tristate.isTrue', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        node: _branch(),
        isExpanded: true,
      );
      final flags = tester
          .getSemantics(find.byType(SettingsTreeRow))
          .getSemanticsData()
          .flagsCollection;
      expect(flags.isExpanded, Tristate.isTrue);
    });

    testWidgets('collapsed branches expose Tristate.isFalse for isExpanded', (
      tester,
    ) async {
      await _pumpRow(tester, node: _branch());
      final flags = tester
          .getSemantics(find.byType(SettingsTreeRow))
          .getSemanticsData()
          .flagsCollection;
      // Branch nodes always report an expanded state (true or false) —
      // Tristate.none would mean "this isn't an expandable thing".
      expect(flags.isExpanded, Tristate.isFalse);
    });

    testWidgets('leaves report Tristate.none for isExpanded', (tester) async {
      await _pumpRow(tester, node: _leaf());
      final flags = tester
          .getSemantics(find.byType(SettingsTreeRow))
          .getSemanticsData()
          .flagsCollection;
      expect(flags.isExpanded, Tristate.none);
    });
  });
}
