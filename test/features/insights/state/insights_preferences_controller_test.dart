import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/insights/state/insights_preferences_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  late MockSettingsDb settingsDb;

  setUp(() async {
    // Shared harness registers the SettingsDb mock (among others); stub
    // against the instance it provides.
    final mocks = await setUpTestGetIt();
    settingsDb = mocks.settingsDb;
    when(
      () => settingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);
  });

  tearDown(tearDownTestGetIt);

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  void stubStored(String? value) {
    when(
      () => settingsDb.itemByKey(insightsFocusCategoryIdsSettingsKey),
    ).thenAnswer((_) async => value);
  }

  test('loads persisted focus categories from SettingsDb', () async {
    stubStored('["cat-a","cat-b"]');
    final container = makeContainer();

    expect(
      container.read(insightsPreferencesControllerProvider).isConfigured,
      isFalse,
    );
    await Future<void>.delayed(Duration.zero);

    final prefs = container.read(insightsPreferencesControllerProvider);
    expect(prefs.focusCategoryIds, {'cat-a', 'cat-b'});
    expect(prefs.isConfigured, isTrue);
  });

  test('malformed or empty stored JSON degrades to unconfigured', () async {
    for (final stored in [null, '', 'not json', '{"a":1}']) {
      stubStored(stored);
      final container = makeContainer();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(insightsPreferencesControllerProvider).focusCategoryIds,
        isEmpty,
        reason: 'stored: $stored',
      );
    }
  });

  test('toggleFocusCategory adds, persists sorted JSON, and removes', () async {
    stubStored(null);
    final container = makeContainer();
    await Future<void>.delayed(Duration.zero);
    final notifier =
        container.read(insightsPreferencesControllerProvider.notifier)
          ..toggleFocusCategory('cat-b')
          ..toggleFocusCategory('cat-a');
    expect(
      container.read(insightsPreferencesControllerProvider).focusCategoryIds,
      {'cat-a', 'cat-b'},
    );
    verify(
      () => settingsDb.saveSettingsItem(
        insightsFocusCategoryIdsSettingsKey,
        '["cat-a","cat-b"]',
      ),
    ).called(1);

    notifier.toggleFocusCategory('cat-b');
    expect(
      container.read(insightsPreferencesControllerProvider).focusCategoryIds,
      {'cat-a'},
    );
    verify(
      () => settingsDb.saveSettingsItem(
        insightsFocusCategoryIdsSettingsKey,
        '["cat-a"]',
      ),
    ).called(1);
  });

  test('a slow load never clobbers an explicit user edit', () async {
    // Simulate a load that resolves after the user already toggled.
    stubStored('["stale-category"]');
    final container = makeContainer();
    container
        .read(insightsPreferencesControllerProvider.notifier)
        .toggleFocusCategory('fresh-category');

    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(insightsPreferencesControllerProvider).focusCategoryIds,
      {'fresh-category'},
    );
  });

  test('InsightsPreferences equality is set-based', () {
    expect(
      InsightsPreferences(focusCategoryIds: const {'a', 'b'}),
      InsightsPreferences(focusCategoryIds: const {'b', 'a'}),
    );
    expect(
      InsightsPreferences(focusCategoryIds: const {'a'}),
      isNot(InsightsPreferences(focusCategoryIds: const {'b'})),
    );
  });
}
