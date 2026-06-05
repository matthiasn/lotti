import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/form/lotti_switch_field.dart';

import '../../widget_test_utils.dart';

Future<void> _pump(WidgetTester tester, LottiSwitchField field) =>
    tester.pumpWidget(makeTestableWidgetWithScaffold(field));

void main() {
  group('LottiSwitchField', () {
    testWidgets('renders title and toggles via onChanged', (tester) async {
      final changes = <bool>[];
      await _pump(
        tester,
        LottiSwitchField(
          title: 'Private',
          value: false,
          onChanged: changes.add,
        ),
      );

      expect(find.text('Private'), findsOneWidget);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      expect(changes, [true]);
    });

    testWidgets('enabled: false disables the switch and dims the title', (
      tester,
    ) async {
      final changes = <bool>[];
      await _pump(
        tester,
        LottiSwitchField(
          title: 'Locked',
          value: true,
          enabled: false,
          onChanged: changes.add,
        ),
      );

      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.onChanged, isNull);

      // Tapping a disabled switch must not invoke the callback.
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(changes, isEmpty);

      final context = tester.element(find.byType(SwitchListTile));
      final title = tester.widget<Text>(find.text('Locked'));
      expect(
        title.style?.color,
        Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.5),
      );
    });

    testWidgets('renders subtitle only when provided', (tester) async {
      await _pump(
        tester,
        LottiSwitchField(
          title: 'With subtitle',
          subtitle: 'More detail',
          value: false,
          onChanged: (_) {},
        ),
      );
      expect(find.text('More detail'), findsOneWidget);

      await _pump(
        tester,
        LottiSwitchField(
          title: 'No subtitle',
          value: false,
          onChanged: (_) {},
        ),
      );
      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.subtitle, isNull);
    });

    testWidgets('renders leading icon when provided', (tester) async {
      await _pump(
        tester,
        LottiSwitchField(
          title: 'With icon',
          icon: Icons.lock,
          value: false,
          onChanged: (_) {},
        ),
      );

      expect(find.byIcon(Icons.lock), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.lock));
      expect(icon.size, 20);
    });

    testWidgets('dense and contentPadding pass through to the tile', (
      tester,
    ) async {
      const customPadding = EdgeInsets.all(2);
      await _pump(
        tester,
        LottiSwitchField(
          title: 'Dense',
          value: false,
          dense: true,
          contentPadding: customPadding,
          onChanged: (_) {},
        ),
      );

      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.dense, isTrue);
      expect(tile.contentPadding, customPadding);
    });
  });
}
