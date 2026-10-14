import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_menu_items.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

enum _Action { edit, internals, delete }

void main() {
  Future<List<_Action>> openMenu(WidgetTester tester) async {
    final selected = <_Action>[];
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Center(
          child: PopupMenuButton<_Action>(
            icon: const Icon(LottiIcons.moreVertical),
            onSelected: selected.add,
            itemBuilder: (context) => [
              agentMenuItem(
                context: context,
                value: _Action.edit,
                icon: LottiIcons.edit,
                label: 'Edit goal',
              ),
              agentInternalsMenuItem(
                context: context,
                value: _Action.internals,
              ),
              agentMenuItem(
                context: context,
                value: _Action.delete,
                icon: LottiIcons.delete,
                label: 'Delete',
                destructive: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(LottiIcons.moreVertical));
    await tester.pumpAndSettle();
    return selected;
  }

  testWidgets('the internals entry reads the same everywhere: tune glyph, '
      "the panel's own title", (tester) async {
    await openMenu(tester);

    expect(find.text('Agent internals'), findsOneWidget);
    expect(find.byIcon(LottiIcons.tune), findsOneWidget);
  });

  testWidgets('rows share one ink; a destructive row wears the error ink', (
    tester,
  ) async {
    await openMenu(tester);
    final tokens = tester.element(find.text('Delete')).designTokens;

    Color? inkOf(String label) =>
        tester.widget<Text>(find.text(label)).style?.color;
    expect(inkOf('Edit goal'), tokens.colors.text.highEmphasis);
    expect(inkOf('Agent internals'), tokens.colors.text.highEmphasis);
    expect(inkOf('Delete'), tokens.colors.alert.error.ink);
    expect(
      tester.widget<Icon>(find.byIcon(LottiIcons.delete)).color,
      tokens.colors.alert.error.ink,
    );
  });

  testWidgets('choosing a row selects its value', (tester) async {
    final selected = await openMenu(tester);

    await tester.tap(find.text('Agent internals'));
    await tester.pumpAndSettle();

    expect(selected, [_Action.internals]);
  });

  group('agentToggleMenuItem', () {
    Future<void> openToggle(
      WidgetTester tester, {
      required bool checked,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Center(
            child: PopupMenuButton<_Action>(
              icon: const Icon(LottiIcons.moreVertical),
              itemBuilder: (context) => [
                agentToggleMenuItem(
                  context: context,
                  value: _Action.edit,
                  label: 'Automatic updates',
                  checked: checked,
                ),
                agentInternalsMenuItem(
                  context: context,
                  value: _Action.internals,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(LottiIcons.moreVertical));
      await tester.pumpAndSettle();
    }

    testWidgets('shows its state in the icon slot the other rows use', (
      tester,
    ) async {
      await openToggle(tester, checked: true);
      expect(find.byIcon(LottiIcons.checkboxChecked), findsOneWidget);
      // Same text treatment as its neighbours, not the bolder checked tile.
      final tokens = tester
          .element(find.text('Automatic updates'))
          .designTokens;
      expect(
        tester.widget<Text>(find.text('Automatic updates')).style,
        tester.widget<Text>(find.text('Agent internals')).style,
      );
      expect(
        tester.widget<Text>(find.text('Automatic updates')).style?.color,
        tokens.colors.text.highEmphasis,
      );
    });

    testWidgets('off reads off, and the state is announced', (tester) async {
      final semantics = tester.ensureSemantics();
      await openToggle(tester, checked: false);
      expect(find.byIcon(LottiIcons.checkboxUnchecked), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Automatic updates')),
        isSemantics(hasCheckedState: true, isChecked: false),
      );
      semantics.dispose();
    });
  });
}
