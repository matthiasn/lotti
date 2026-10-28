import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/settings/settings_timestamps_footer.dart';
import 'package:material_ui/material_ui.dart';

import '../../test_helper.dart';

void main() {
  // Local wall-clock instants, so `toLocal()` in the label leaves them as is
  // whatever the machine's zone.
  final created = DateTime(2024, 3, 15, 14, 30);
  final updated = DateTime(2025, 11, 2, 9, 5);

  /// Pumps the footer under an app in [appLocale] (English by default) on a
  /// phone whose clock is set to 24 hours when [use24Hour] is true.
  Future<void> pumpFooter(
    WidgetTester tester, {
    required DateTime? createdAt,
    required DateTime? updatedAt,
    bool use24Hour = false,
    Locale? appLocale,
  }) async {
    await tester.pumpWidget(
      WidgetTestBench(
        locale: appLocale,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(alwaysUse24HourFormat: use24Hour),
            child: SettingsTimestampsFooter(
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          ),
        ),
      ),
    );
  }

  void onDevice(WidgetTester tester, Locale locale) {
    tester.platformDispatcher.localeTestValue = locale;
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  }

  testWidgets('shows both timestamps in the device convention, created first', (
    tester,
  ) async {
    await pumpFooter(tester, createdAt: created, updatedAt: updated);

    final createdLine = find.text('Created 3/15/2024 2:30 PM');
    final updatedLine = find.text('Last modified 11/2/2025 9:05 AM');
    expect(createdLine, findsOneWidget);
    expect(updatedLine, findsOneWidget);
    // One group, read top to bottom: when it began, then its latest change.
    expect(
      tester.getTopLeft(updatedLine).dy,
      greaterThan(tester.getTopLeft(createdLine).dy),
    );
    expect(
      tester.getTopLeft(updatedLine).dx,
      tester.getTopLeft(createdLine).dx,
    );
  });

  testWidgets('a 24-hour phone gets a 24-hour clock in an English app', (
    tester,
  ) async {
    onDevice(tester, const Locale('en', 'US'));
    await pumpFooter(
      tester,
      createdAt: created,
      updatedAt: updated,
      use24Hour: true,
    );

    expect(find.text('Created 3/15/2024 14:30'), findsOneWidget);
    expect(find.text('Last modified 11/2/2025 09:05'), findsOneWidget);
  });

  testWidgets('an English app on a German phone writes German dates', (
    tester,
  ) async {
    await initializeDateFormatting('de_DE');
    onDevice(tester, const Locale('de', 'DE'));
    await pumpFooter(
      tester,
      createdAt: created,
      updatedAt: updated,
      use24Hour: true,
    );

    expect(find.text('Created 15.3.2024 14:30'), findsOneWidget);
    expect(find.text('Last modified 2.11.2025 09:05'), findsOneWidget);
  });

  testWidgets('a German app on a German phone reads German throughout, '
      '24-hour even without the device flag', (tester) async {
    await initializeDateFormatting('de_DE');
    onDevice(tester, const Locale('de', 'DE'));
    await pumpFooter(
      tester,
      createdAt: created,
      updatedAt: updated,
      appLocale: const Locale('de'),
    );

    expect(find.text('Erstellt am 15.3.2024 14:30'), findsOneWidget);
    expect(find.text('Zuletzt geändert am 2.11.2025 09:05'), findsOneWidget);
  });

  testWidgets('styles both lines as low-emphasis captions', (tester) async {
    await pumpFooter(tester, createdAt: created, updatedAt: updated);

    final context = tester.element(find.byType(SettingsTimestampsFooter));
    final tokens = context.designTokens;
    final texts = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(texts, hasLength(2));
    for (final text in texts) {
      expect(text.style?.color, tokens.colors.text.lowEmphasis);
      expect(
        text.style?.fontSize,
        tokens.typography.styles.others.caption.fontSize,
      );
    }
  });

  testWidgets('sets the group off from the form above it', (tester) async {
    await pumpFooter(tester, createdAt: created, updatedAt: updated);

    final context = tester.element(find.byType(SettingsTimestampsFooter));
    final spacing = context.designTokens.spacing;
    final padding = tester.widget<Padding>(
      find
          .descendant(
            of: find.byType(SettingsTimestampsFooter),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(
      padding.padding,
      EdgeInsets.only(top: spacing.step6, bottom: spacing.step3),
    );
  });

  testWidgets('leaves out a missing timestamp line', (tester) async {
    await pumpFooter(tester, createdAt: created, updatedAt: null);

    expect(find.text('Created 3/15/2024 2:30 PM'), findsOneWidget);
    expect(find.textContaining('Last modified'), findsNothing);

    await pumpFooter(tester, createdAt: null, updatedAt: updated);

    expect(find.textContaining('Created'), findsNothing);
    expect(find.text('Last modified 11/2/2025 9:05 AM'), findsOneWidget);
  });

  testWidgets('renders nothing, not even its spacing, with neither', (
    tester,
  ) async {
    await pumpFooter(tester, createdAt: null, updatedAt: null);

    expect(find.byType(Text), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SettingsTimestampsFooter),
        matching: find.byType(Padding),
      ),
      findsNothing,
    );
  });
}
