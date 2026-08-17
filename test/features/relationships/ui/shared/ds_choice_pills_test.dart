import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/relationships/ui/shared/ds_choice_pills.dart';

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
