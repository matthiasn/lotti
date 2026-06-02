import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('DailyOsPreferences', () {
    for (final entry in const <String, bool>{
      'Daily OS User': true,
      'value': true,
      '   padded   ': true,
      '': false,
      '   ': false,
    }.entries) {
      test('hasUserName is ${entry.value} for "${entry.key}"', () {
        expect(
          DailyOsPreferences(userName: entry.key).hasUserName,
          entry.value,
        );
      });
    }

    test('allowsCategory / allowsCategoryId reflect the excluded set', () {
      final prefs = DailyOsPreferences(
        excludedCategoryIds: const {'cat_health'},
      );
      const excluded = DayAgentCategory(
        id: 'cat_health',
        name: 'Health',
        colorHex: 'FF0000',
      );
      const allowed = DayAgentCategory(
        id: 'cat_work',
        name: 'Work',
        colorHex: '00FF00',
      );

      expect(prefs.allowsCategory(excluded), isFalse);
      expect(prefs.allowsCategory(allowed), isTrue);
      expect(prefs.allowsCategoryId('cat_health'), isFalse);
      expect(prefs.allowsCategoryId('cat_work'), isTrue);
    });
  });

  group('DailyOsPreferencesController', () {
    late ProviderContainer container;
    late TestGetItMocks mocks;

    setUp(() async {
      mocks = await setUpTestGetIt();
      when(
        () => mocks.settingsDb.itemsByKeys(any()),
      ).thenAnswer((_) async => const <String, String>{});
      container = ProviderContainer();
    });

    tearDown(() async {
      container.dispose();
      await tearDownTestGetIt();
    });

    test('loads persisted name and excluded categories', () async {
      when(() => mocks.settingsDb.itemsByKeys(any())).thenAnswer(
        (_) async => const {
          dailyOsUserNameSettingsKey: 'Daily OS User',
          dailyOsExcludedCategoryIdsSettingsKey: '["cat_health"]',
        },
      );

      container.read(dailyOsPreferencesControllerProvider);
      await pumpEventQueue();

      final state = container.read(dailyOsPreferencesControllerProvider);
      expect(state.userName, 'Daily OS User');
      expect(state.excludedCategoryIds, {'cat_health'});
    });

    test('setUserName trims and persists the display name', () {
      container
          .read(dailyOsPreferencesControllerProvider.notifier)
          .setUserName('  Daily OS User  ');

      final state = container.read(dailyOsPreferencesControllerProvider);
      expect(state.userName, 'Daily OS User');
      verify(
        () => mocks.settingsDb.saveSettingsItem(
          dailyOsUserNameSettingsKey,
          'Daily OS User',
        ),
      ).called(1);
    });

    test('setCategoryEnabled persists the excluded category list', () {
      final notifier = container.read(
        dailyOsPreferencesControllerProvider.notifier,
      );
      void setHealthCategory({required bool enabled}) {
        notifier.setCategoryEnabled('cat_health', enabled: enabled);
      }

      setHealthCategory(enabled: false);
      expect(
        container
            .read(dailyOsPreferencesControllerProvider)
            .excludedCategoryIds,
        {'cat_health'},
      );
      verify(
        () => mocks.settingsDb.saveSettingsItem(
          dailyOsExcludedCategoryIdsSettingsKey,
          '["cat_health"]',
        ),
      ).called(1);

      setHealthCategory(enabled: true);
      expect(
        container
            .read(dailyOsPreferencesControllerProvider)
            .excludedCategoryIds,
        isEmpty,
      );
      verify(
        () => mocks.settingsDb.saveSettingsItem(
          dailyOsExcludedCategoryIdsSettingsKey,
          '[]',
        ),
      ).called(1);
    });

    test('setIncludedCategoryIds persists omitted actual categories', () {
      container
          .read(dailyOsPreferencesControllerProvider.notifier)
          .setIncludedCategoryIds(
            includedCategoryIds: {'cat_work', 'cat_health'},
            allCategoryIds: {'cat_work', 'cat_health', 'cat_meals'},
          );

      expect(
        container
            .read(dailyOsPreferencesControllerProvider)
            .excludedCategoryIds,
        {'cat_meals'},
      );
      verify(
        () => mocks.settingsDb.saveSettingsItem(
          dailyOsExcludedCategoryIdsSettingsKey,
          '["cat_meals"]',
        ),
      ).called(1);
    });

    test('includeAllCategories clears exclusions and persists empty list', () {
      final notifier = container.read(
        dailyOsPreferencesControllerProvider.notifier,
      )..setCategoryEnabled('cat_health', enabled: false);
      expect(
        container
            .read(dailyOsPreferencesControllerProvider)
            .excludedCategoryIds,
        {'cat_health'},
      );

      notifier.includeAllCategories();

      expect(
        container
            .read(dailyOsPreferencesControllerProvider)
            .excludedCategoryIds,
        isEmpty,
      );
      verify(
        () => mocks.settingsDb.saveSettingsItem(
          dailyOsExcludedCategoryIdsSettingsKey,
          '[]',
        ),
      ).called(1);
    });
  });
}
