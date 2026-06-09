import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/first_day_of_week_picker.dart';

void main() {
  // Renders the picker builder for [locale] asking for [desiredIndex], and
  // reports the `firstDayOfWeekIndex` the wrapped subtree actually sees.
  Future<int> firstDayInPicker(
    WidgetTester tester, {
    required Locale locale,
    required int desiredIndex,
  }) async {
    late int observed;
    final builder = firstDayOfWeekPickerBuilder(desiredIndex);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', 'US'),
          Locale('en', 'GB'),
          Locale('de'),
        ],
        home: Builder(
          builder: (context) => builder(
            context,
            Builder(
              builder: (inner) {
                observed = MaterialLocalizations.of(inner).firstDayOfWeekIndex;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return observed;
  }

  group('firstDayOfWeekPickerBuilder', () {
    testWidgets('forces Monday for English when the region wants Monday', (
      tester,
    ) async {
      // en_US defaults to Sunday (0); region wants Monday (1) -> en_GB.
      expect(
        await firstDayInPicker(
          tester,
          locale: const Locale('en', 'US'),
          desiredIndex: DateTime.monday % 7,
        ),
        1,
      );
    });

    testWidgets('leaves the picker untouched when it already matches', (
      tester,
    ) async {
      // en_US is already Sunday and Sunday is wanted -> no override.
      expect(
        await firstDayInPicker(
          tester,
          locale: const Locale('en', 'US'),
          desiredIndex: DateTime.sunday % 7,
        ),
        0,
      );
    });

    testWidgets('keeps a non-English locale (already Monday) unchanged', (
      tester,
    ) async {
      // German starts on Monday; we never switch its language to force a
      // different first day, so it stays Monday even if Sunday is requested.
      expect(
        await firstDayInPicker(
          tester,
          locale: const Locale('de'),
          desiredIndex: DateTime.sunday % 7,
        ),
        1,
      );
    });
  });
}
