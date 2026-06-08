import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/widgets/agent_list_group_section.dart';
import 'package:lotti/features/agents/ui/listing/widgets/agent_list_row.dart';
import 'package:lotti/features/agents/ui/listing/widgets/soul_avatar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';

AgentListRowData _row(String id) => AgentListRowData(
  id: id,
  title: 'Title $id',
  searchKey: 'title $id',
  sortAt: DateTime(2026, 3),
);

AgentListGroup _group({
  String id = 'g1',
  String label = 'Group One',
  AgentListLeading? leading,
  int? activeCount,
  List<AgentListRowData>? items,
}) {
  return AgentListGroup(
    id: id,
    label: label,
    leading: leading,
    activeCount: activeCount,
    items: items ?? [_row('a'), _row('b'), _row('c')],
  );
}

Future<void> _pumpHeader(
  WidgetTester tester, {
  required AgentListGroup group,
  required bool expanded,
  VoidCallback? onToggle,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      AgentListGroupHeader(
        group: group,
        expanded: expanded,
        onToggle: onToggle ?? () {},
      ),
      theme: DesignSystemTheme.dark(),
    ),
  );
  await tester.pump();
}

void main() {
  group('AgentListGroupHeader', () {
    testWidgets('shows the label and the trailing item count', (tester) async {
      await _pumpHeader(
        tester,
        group: _group(),
        expanded: true,
      );

      expect(find.text('Group One'), findsOneWidget);
      // Trailing "· N" reflects items.length (3 rows seeded).
      expect(find.text('· 3'), findsOneWidget);
    });

    testWidgets('expanded shows expand_more, collapsed shows chevron_right', (
      tester,
    ) async {
      await _pumpHeader(tester, group: _group(), expanded: true);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      await _pumpHeader(tester, group: _group(), expanded: false);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('tapping the header invokes onToggle', (tester) async {
      var toggled = 0;
      await _pumpHeader(
        tester,
        group: _group(),
        expanded: true,
        onToggle: () => toggled++,
      );

      await tester.tap(find.byType(AgentListGroupHeader));
      expect(toggled, 1);
    });

    testWidgets('active count cell shows when > 0 and is hidden otherwise', (
      tester,
    ) async {
      await _pumpHeader(
        tester,
        group: _group(activeCount: 2),
        expanded: true,
      );
      final ctx = tester.element(find.byType(AgentListGroupHeader));
      expect(
        find.text(ctx.messages.agentInstancesGroupActiveCount(2)),
        findsOneWidget,
      );

      // activeCount of 0 suppresses the cell entirely.
      await _pumpHeader(
        tester,
        group: _group(),
        expanded: true,
      );
      final ctx0 = tester.element(find.byType(AgentListGroupHeader));
      expect(
        find.text(ctx0.messages.agentInstancesGroupActiveCount(1)),
        findsNothing,
      );
    });

    testWidgets('avatar leading renders a SoulAvatar tinted by the hue', (
      tester,
    ) async {
      await _pumpHeader(
        tester,
        group: _group(
          leading: const AgentListAvatarLeading(label: 'laura', hue: 142),
        ),
        expanded: true,
      );

      final avatar = tester.widget<SoulAvatar>(find.byType(SoulAvatar));
      expect(avatar.hue, 142);
      expect(find.text('L'), findsOneWidget);
    });

    testWidgets('icon leading renders the plain icon, not an avatar', (
      tester,
    ) async {
      await _pumpHeader(
        tester,
        group: _group(
          leading: const AgentListIconLeading(icon: Icons.psychology),
        ),
        expanded: true,
      );

      expect(find.byIcon(Icons.psychology), findsOneWidget);
      expect(find.byType(SoulAvatar), findsNothing);
    });
  });

  group('AgentListGroupBody', () {
    testWidgets('renders one AgentListRow per group item', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          AgentListGroupBody(group: _group()),
          theme: DesignSystemTheme.dark(),
        ),
      );
      await tester.pump();

      expect(find.byType(AgentListRow), findsNWidgets(3));
      expect(find.text('Title a'), findsOneWidget);
      expect(find.text('Title b'), findsOneWidget);
      expect(find.text('Title c'), findsOneWidget);
    });

    testWidgets('an empty group renders no rows', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          AgentListGroupBody(group: _group(items: const [])),
          theme: DesignSystemTheme.dark(),
        ),
      );
      await tester.pump();

      expect(find.byType(AgentListRow), findsNothing);
    });
  });
}
