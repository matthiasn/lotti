import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/widgets/agent_list_row.dart';
import 'package:lotti/features/agents/ui/listing/widgets/soul_avatar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';

import '../../../../../widget_test_utils.dart';

AgentListRowData _row({
  String? subtitle,
  AgentListLeading? leading,
  List<AgentListPill> pills = const [],
  String? metaRight,
  WidgetBuilder? trailing,
  VoidCallback? onTap,
}) {
  return AgentListRowData(
    id: 'row-1',
    title: 'Row Title',
    searchKey: 'row title',
    sortAt: DateTime(2026, 3),
    subtitle: subtitle,
    leading: leading,
    pills: pills,
    metaRight: metaRight,
    trailing: trailing,
    onTap: onTap,
  );
}

Future<void> _pumpRow(
  WidgetTester tester,
  AgentListRowData data, {
  double width = 800,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      SizedBox(
        width: width,
        child: AgentListRow(data: data),
      ),
      theme: DesignSystemTheme.dark(),
    ),
  );
  await tester.pump();
}

void main() {
  group('AgentListRow', () {
    testWidgets('renders pills, subtitle, and meta in the wide layout', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        _row(
          subtitle: 'a subtitle',
          pills: const [
            AgentListPill(label: 'active'),
            AgentListPill(label: 'task', tone: AgentListPillTone.info),
          ],
          metaRight: '3m ago',
        ),
      );

      // The wide layout renders title + subtitle as one rich text run.
      expect(
        find.textContaining('Row Title', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('a subtitle', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('active'), findsOneWidget);
      expect(find.text('task'), findsOneWidget);
      expect(find.text('3m ago'), findsOneWidget);
    });

    testWidgets('omits the subtitle line when none is provided', (
      tester,
    ) async {
      await _pumpRow(tester, _row());

      expect(
        find.textContaining('Row Title', findRichText: true),
        findsOneWidget,
      );
      // Only the title text renders inside the row body (no subtitle).
      expect(
        find.textContaining('a subtitle', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('avatar leading renders a SoulAvatar with the row hue', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        _row(
          leading: const AgentListAvatarLeading(label: 'laura', hue: 142),
        ),
      );

      final avatar = tester.widget<SoulAvatar>(find.byType(SoulAvatar));
      expect(avatar.hue, 142);
      expect(find.text('L'), findsOneWidget);
    });

    testWidgets('icon leading renders the plain icon variant', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        _row(leading: const AgentListIconLeading(icon: Icons.alarm)),
      );

      expect(find.byIcon(Icons.alarm), findsOneWidget);
      expect(find.byType(SoulAvatar), findsNothing);
    });

    testWidgets('tappable rows show the chevron and invoke onTap', (
      tester,
    ) async {
      var tapped = 0;
      await _pumpRow(tester, _row(onTap: () => tapped++));

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      await tester.tap(find.byType(AgentListRow));
      expect(tapped, 1);
    });

    testWidgets('a custom trailing builder replaces the chevron', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        _row(
          onTap: () {},
          trailing: (context) => const Icon(Icons.star),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('non-tappable rows render no chevron', (tester) async {
      await _pumpRow(tester, _row());
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('narrow constraints switch to the compact stacked layout', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        _row(
          subtitle: 'stacked subtitle',
          pills: const [AgentListPill(label: 'pill')],
        ),
        width: 420,
      );

      // Compact layout stacks: title and subtitle render as separate Text
      // widgets (the wide layout merges them into one rich run), with the
      // subtitle below the title.
      final titleDy = tester.getTopLeft(find.text('Row Title')).dy;
      final subtitleDy = tester.getTopLeft(find.text('stacked subtitle')).dy;
      expect(subtitleDy, greaterThan(titleDy));
      expect(find.text('pill'), findsOneWidget);
    });
  });
}
