import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/ui/detail/default_panel.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

SettingsNode _flagsLeaf() => const SettingsNode(
  id: 'flags',
  icon: LottiIcons.flag,
  title: 'Flags',
  desc: 'Feature flags',
  panel: 'flags',
);

Future<void> _pump(WidgetTester tester, SettingsNode node) async {
  await setUpTestGetIt();
  addTearDown(tearDownTestGetIt);
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Material(
        child: SizedBox(
          width: 600,
          height: 600,
          child: DefaultPanel(node: node),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('DefaultPanel — content', () {
    testWidgets('renders the construction-glyph empty-state icon', (
      tester,
    ) async {
      await _pump(tester, _flagsLeaf());
      expect(find.byIcon(LottiIcons.build), findsOneWidget);
    });

    testWidgets('renders the "Panel not yet implemented" headline', (
      tester,
    ) async {
      await _pump(tester, _flagsLeaf());
      expect(find.text('Panel not yet implemented'), findsOneWidget);
    });

    testWidgets("renders the leaf's title below the headline", (tester) async {
      await _pump(tester, _flagsLeaf());
      expect(find.text('Flags'), findsOneWidget);
    });

    testWidgets(
      'shows the registered panel id as a developer hint when present',
      (tester) async {
        await _pump(tester, _flagsLeaf());
        expect(find.text('flags'), findsOneWidget);
      },
    );

    testWidgets(
      'falls back to showing the node id when panel is null',
      (tester) async {
        await _pump(
          tester,
          const SettingsNode(
            id: 'orphan-id',
            icon: LottiIcons.help,
            title: 'Orphan',
            desc: '',
          ),
        );
        expect(find.text('orphan-id'), findsOneWidget);
      },
    );
  });
}
