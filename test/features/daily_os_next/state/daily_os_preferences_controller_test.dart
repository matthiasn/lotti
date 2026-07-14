import 'dart:async';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
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

    // The two predicates must agree for the same id, and both must mirror
    // membership in the excluded set, regardless of how the set was built.
    glados.Glados2(
      // Candidate category id drawn from a pool that overlaps the excluded
      // pool below, so both the allowed and excluded branches are exercised.
      glados.AnyUtils(
        glados.any,
      ).choose(const ['cat_work', 'cat_health', 'cat_meals', 'cat_other']),
      // Excluded set built from arbitrary subsets of a shared id pool.
      glados.ListAnys(glados.any).listWithLengthInRange(
        0,
        4,
        glados.AnyUtils(
          glados.any,
        ).choose(const ['cat_work', 'cat_health', 'cat_meals']),
      ),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'allowsCategory(c) == allowsCategoryId(c.id) and both track exclusion',
      (categoryId, excludedList) {
        final excluded = excludedList.toSet();
        final prefs = DailyOsPreferences(excludedCategoryIds: excluded);
        final category = DayAgentCategory(
          id: categoryId,
          name: 'name',
          colorHex: 'FF0000',
        );
        final reason = 'id=$categoryId excluded=$excluded';

        // The two predicates are different surfaces of the same rule.
        expect(
          prefs.allowsCategory(category),
          prefs.allowsCategoryId(categoryId),
          reason: reason,
        );
        // And the rule is exactly "not in the excluded set".
        expect(
          prefs.allowsCategoryId(categoryId),
          !excluded.contains(categoryId),
          reason: reason,
        );
      },
      tags: 'glados',
    );
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

  group('DailyOsPreferencesController name sync', () {
    late MockOutboxService outboxService;
    late MockDomainLogger domainLogger;
    late StreamController<Set<String>> notifications;
    late TestGetItMocks mocks;
    late ProviderContainer container;

    setUpAll(() {
      registerFallbackValue(
        const SyncMessage.dailyOsUserName(
          userName: '',
          updatedAt: 0,
          status: SyncEntryStatus.update,
        ),
      );
      registerFallbackValue(StackTrace.empty);
    });

    setUp(() async {
      outboxService = MockOutboxService();
      domainLogger = MockDomainLogger();
      notifications = StreamController<Set<String>>.broadcast();
      mocks = await setUpTestGetIt(
        additionalSetup: () {
          GetIt.I.allowReassignment = true;
          GetIt.I
            ..registerSingleton<OutboxService>(outboxService)
            ..registerSingleton<DomainLogger>(domainLogger);
        },
      );
      when(
        () => mocks.updateNotifications.updateStream,
      ).thenAnswer((_) => notifications.stream);
      when(
        () => outboxService.enqueueMessage(any<SyncMessage>()),
      ).thenAnswer((_) async {});
      when(
        () => domainLogger.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenReturn(null);
      container = ProviderContainer();
    });

    tearDown(() async {
      EasyDebounce.cancelAll();
      container.dispose();
      await notifications.close();
      await tearDownTestGetIt();
    });

    test('setUserName enqueues a debounced dailyOsUserName message', () {
      fakeAsync((async) {
        container
            .read(dailyOsPreferencesControllerProvider.notifier)
            .setUserName('Sam');
        async
          ..elapse(const Duration(milliseconds: 400))
          ..flushMicrotasks();

        final captured = verify(
          () => outboxService.enqueueMessage(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        final message = captured.single as SyncDailyOsUserName;
        expect(message.userName, 'Sam');
        expect(message.status, SyncEntryStatus.update);
        expect(message.updatedAt, greaterThan(0));

        verify(
          () => mocks.settingsDb.saveSettingsItem(
            dailyOsUserNameUpdatedAtSettingsKey,
            message.updatedAt.toString(),
          ),
        ).called(1);
      });
    });

    test('rapid edits coalesce into a single message with the last name', () {
      fakeAsync((async) {
        final notifier =
            container.read(
                dailyOsPreferencesControllerProvider.notifier,
              )
              ..setUserName('S')
              ..setUserName('Sa')
              ..setUserName('Sam');
        async
          ..elapse(const Duration(milliseconds: 400))
          ..flushMicrotasks();

        final captured = verify(
          () => outboxService.enqueueMessage(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        expect((captured.single as SyncDailyOsUserName).userName, 'Sam');
        // The controller state also reflects the final edit.
        expect(
          container.read(dailyOsPreferencesControllerProvider).userName,
          'Sam',
        );
        expect(notifier, isNotNull);
      });
    });

    test('a synced settings notification reloads the name without echo', () {
      when(
        () => mocks.settingsDb.itemByKey(dailyOsUserNameSettingsKey),
      ).thenAnswer((_) async => 'Remote Sam');

      fakeAsync((async) {
        // Build the controller and let its listener subscribe.
        container.read(dailyOsPreferencesControllerProvider);
        async
          ..elapse(const Duration(milliseconds: 100))
          ..flushMicrotasks();
        clearInteractions(outboxService);

        notifications.add({settingsNotification});
        async
          ..elapse(const Duration(milliseconds: 100))
          ..flushMicrotasks();

        expect(
          container.read(dailyOsPreferencesControllerProvider).userName,
          'Remote Sam',
        );
        // Applying a synced name must not re-enqueue an outbound message.
        verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));
      });
    });

    test('no message is enqueued before sync is configured', () {
      fakeAsync((async) {
        GetIt.I.unregister<OutboxService>();
        container
            .read(dailyOsPreferencesControllerProvider.notifier)
            .setUserName('Sam');
        async
          ..elapse(const Duration(milliseconds: 400))
          ..flushMicrotasks();

        verifyNever(() => outboxService.enqueueMessage(any<SyncMessage>()));
      });
    });

    test('an enqueue failure is caught and logged', () {
      when(
        () => outboxService.enqueueMessage(any<SyncMessage>()),
      ).thenThrow(StateError('outbox down'));

      fakeAsync((async) {
        container
            .read(dailyOsPreferencesControllerProvider.notifier)
            .setUserName('Sam');
        async
          ..elapse(const Duration(milliseconds: 400))
          ..flushMicrotasks();

        verify(
          () => domainLogger.error(
            LogDomain.dailyOs,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'enqueue',
          ),
        ).called(1);
      });
    });
  });
}
