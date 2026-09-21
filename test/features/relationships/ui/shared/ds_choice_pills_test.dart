import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/relationships/ui/shared/ds_choice_pills.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

enum _Flavor { apple, banana, cherry }

void main() {
  group('DsChoicePills', () {
    Widget build<T>({
      required T? value,
      required List<T> values,
      required String Function(T) labelFor,
      required void Function(T) onSelected,
    }) {
      return MaterialApp(
        builder: LegacyMaterialBridge.builder,
        theme: resolveTestTheme(),
        home: Scaffold(
          body: DsChoicePills<T>(
            value: value,
            values: values,
            labelFor: labelFor,
            onSelected: onSelected,
          ),
        ),
      );
    }

    testWidgets('renders one pill per value with the label', (tester) async {
      await tester.pumpWidget(
        build<_Flavor>(
          value: _Flavor.banana,
          values: _Flavor.values,
          labelFor: (_Flavor f) => f.name,
          onSelected: (_) {},
        ),
      );
      expect(find.text('apple'), findsOneWidget);
      expect(find.text('banana'), findsOneWidget);
      expect(find.text('cherry'), findsOneWidget);
    });

    testWidgets('marks only the selected value as selected', (tester) async {
      await tester.pumpWidget(
        build<_Flavor>(
          value: _Flavor.cherry,
          values: _Flavor.values,
          labelFor: (_Flavor f) => f.name,
          onSelected: (_) {},
        ),
      );
      // The selected pill's text is bold (w700) per DsPill.
      final banana = tester.widget<Text>(find.text('banana'));
      final cherry = tester.widget<Text>(find.text('cherry'));
      expect(banana.style?.fontWeight, isNot(FontWeight.w700));
      expect(cherry.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('taps call onSelected with the tapped value', (tester) async {
      _Flavor? picked;
      await tester.pumpWidget(
        build<_Flavor>(
          value: _Flavor.apple,
          values: _Flavor.values,
          labelFor: (_Flavor f) => f.name,
          onSelected: (_Flavor f) => picked = f,
        ),
      );

      await tester.tap(find.text('cherry'));
      expect(picked, _Flavor.cherry);
    });

    testWidgets('each choice is a full-height target: a tap in the margin '
        'above the 28px pill still selects it, once', (tester) async {
      final picked = <_Flavor>[];
      await tester.pumpWidget(
        build<_Flavor>(
          value: _Flavor.apple,
          values: _Flavor.values,
          labelFor: (_Flavor f) => f.name,
          onSelected: picked.add,
        ),
      );

      final pill = tester.getRect(find.widgetWithText(DsPill, 'cherry'));
      final row = tester.getRect(find.byType(DsChoicePills<_Flavor>));
      expect(row.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      // Above the pill's own ink, inside the row.
      await tester.tapAt(Offset(pill.center.dx, row.top + 2));
      expect(picked, [_Flavor.cherry]);

      // On the pill itself: still exactly one selection per tap.
      await tester.tap(find.text('banana'));
      expect(picked, [_Flavor.cherry, _Flavor.banana]);
    });

    testWidgets('announces each choice as one of an exclusive group, with '
        'its selected state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        build<_Flavor>(
          value: _Flavor.banana,
          values: _Flavor.values,
          labelFor: (_Flavor f) => f.name,
          onSelected: (_) {},
        ),
      );

      SemanticsData data(String label) =>
          tester.getSemantics(find.text(label)).getSemanticsData();
      for (final flavor in _Flavor.values) {
        final semantics = data(flavor.name);
        expect(semantics.flagsCollection.isButton, isTrue);
        expect(semantics.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
        expect(
          semantics.flagsCollection.isSelected,
          flavor == _Flavor.banana ? Tristate.isTrue : Tristate.isFalse,
        );
      }
      handle.dispose();
    });

    testWidgets('renders nothing when values is empty', (tester) async {
      await tester.pumpWidget(
        build<_Flavor>(
          value: null,
          values: const [],
          labelFor: (_Flavor f) => f.name,
          onSelected: (_) {},
        ),
      );
      expect(find.byType(DsChoicePills<_Flavor>), findsOneWidget);
      expect(find.text('apple'), findsNothing);
    });

    testWidgets('scrolls horizontally (never wraps to a second row)', (
      tester,
    ) async {
      // Many long labels would wrap a Row; the row is inside a horizontal
      // SingleChildScrollView, so it never wraps.
      await tester.pumpWidget(
        build<String>(
          value: null,
          values: List.generate(20, (i) => 'option-$i-very-long-label'),
          labelFor: (String s) => s,
          onSelected: (_) {},
        ),
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(
        tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
            .scrollDirection,
        Axis.horizontal,
      );
    });
  });
}
