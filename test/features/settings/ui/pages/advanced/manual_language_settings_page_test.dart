import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/radio_buttons/design_system_radio_button.dart';
import 'package:lotti/features/settings/state/manual_language_controller.dart';
import 'package:lotti/features/settings/ui/pages/advanced/manual_language_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  late TestGetItMocks mocks;

  setUp(() async {
    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<UserActivityService>(UserActivityService());
      },
    );
    when(
      () => mocks.settingsDb.removeSettingsItem(any()),
    ).thenAnswer((_) async {});
  });

  tearDown(tearDownTestGetIt);

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SingleChildScrollView(child: ManualLanguageSettingsBody()),
      ),
    );
    await tester.pump();
  }

  DesignSystemListItem rowFor(WidgetTester tester, String title) {
    return tester.widget<DesignSystemListItem>(
      find.ancestor(
        of: find.text(title),
        matching: find.byType(DesignSystemListItem),
      ),
    );
  }

  testWidgets('wraps the selector in a titled back-navigation page', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(const ManualLanguageSettingsPage()),
    );
    await tester.pump(const Duration(milliseconds: 600));

    final context = tester.element(find.byType(ManualLanguageSettingsPage));
    final page = tester.widget<SliverBoxAdapterPage>(
      find.byType(SliverBoxAdapterPage),
    );

    expect(page.title, context.messages.settingsManualLanguageTitle);
    expect(page.showBackButton, isTrue);
    expect(find.byType(ManualLanguageSettingsBody), findsOneWidget);
  });

  testWidgets(
    'renders the tokenized grouped choices with Follow system active',
    (
      tester,
    ) async {
      await pumpPage(tester);
      final context = tester.element(find.byType(ManualLanguageSettingsBody));
      final messages = context.messages;

      expect(find.byType(DesignSystemGroupedList), findsOneWidget);
      expect(find.byType(DesignSystemRadioButton), findsNWidgets(6));
      expect(
        find.text(messages.settingsManualLanguageFollowSystemSubtitle),
        findsOneWidget,
      );
      expect(
        rowFor(
          tester,
          messages.settingsManualLanguageFollowSystemTitle,
        ).selected,
        isTrue,
      );
      for (final title in [
        messages.settingsManualLanguageEnglishTitle,
        messages.settingsManualLanguageGermanTitle,
        messages.settingsManualLanguageFrenchTitle,
        messages.settingsManualLanguageCzechTitle,
        messages.settingsManualLanguageRomanianTitle,
      ]) {
        expect(rowFor(tester, title).selected, isFalse);
      }
    },
  );

  testWidgets(
    'selecting a language updates the row and persists the override',
    (
      tester,
    ) async {
      await pumpPage(tester);
      final context = tester.element(find.byType(ManualLanguageSettingsBody));
      final german = context.messages.settingsManualLanguageGermanTitle;

      await tester.tap(find.text(german));
      await tester.pump();

      expect(rowFor(tester, german).selected, isTrue);
      verify(
        () =>
            mocks.settingsDb.saveSettingsItem(manualLanguageSettingsKey, 'de'),
      ).called(1);
    },
  );

  testWidgets('the trailing radio control selects French', (tester) async {
    await pumpPage(tester);
    final context = tester.element(find.byType(ManualLanguageSettingsBody));
    final french = context.messages.settingsManualLanguageFrenchTitle;

    await tester.tap(find.byType(DesignSystemRadioButton).at(3));
    await tester.pump();

    expect(rowFor(tester, french).selected, isTrue);
    verify(
      () => mocks.settingsDb.saveSettingsItem(manualLanguageSettingsKey, 'fr'),
    ).called(1);
  });

  testWidgets('Follow system clears a selected override', (tester) async {
    await pumpPage(tester);
    final context = tester.element(find.byType(ManualLanguageSettingsBody));
    final messages = context.messages;

    await tester.tap(find.text(messages.settingsManualLanguageRomanianTitle));
    await tester.pump();
    await tester.tap(
      find.text(messages.settingsManualLanguageFollowSystemTitle),
    );
    await tester.pump();

    expect(
      rowFor(tester, messages.settingsManualLanguageFollowSystemTitle).selected,
      isTrue,
    );
    verify(
      () => mocks.settingsDb.removeSettingsItem(manualLanguageSettingsKey),
    ).called(1);
  });
}
