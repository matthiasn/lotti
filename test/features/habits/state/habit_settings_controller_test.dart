// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/state/habit_settings_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

class FakeHabitDefinitionLocal extends Fake implements HabitDefinition {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeHabitDefinitionLocal());
  });

  group('HabitSettingsController', () {
    late MockJournalDb mockJournalDb;
    late MockTagsService mockTagsService;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockNotificationService mockNotificationService;
    late MockUpdateNotifications mockUpdateNotifications;
    late StreamController<List<TagEntity>> tagsStreamController;
    late StreamController<Set<String>> updateStreamController;

    setUp(() {
      mockJournalDb = MockJournalDb();
      mockTagsService = MockTagsService();
      mockPersistenceLogic = MockPersistenceLogic();
      mockNotificationService = MockNotificationService();
      mockUpdateNotifications = MockUpdateNotifications();
      tagsStreamController = StreamController<List<TagEntity>>.broadcast();
      updateStreamController = StreamController<Set<String>>.broadcast();

      when(() => mockJournalDb.getHabitById(any()))
          .thenAnswer((_) async => null);
      when(mockTagsService.watchTags).thenAnswer(
        (_) => tagsStreamController.stream,
      );
      when(() => mockPersistenceLogic.upsertEntityDefinition(any()))
          .thenAnswer((_) async => 1);
      when(() => mockNotificationService.scheduleHabitNotification(any()))
          .thenAnswer((_) async {});
      when(() => mockUpdateNotifications.updateStream)
          .thenAnswer((_) => updateStreamController.stream);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<NotificationService>(mockNotificationService)
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
    });

    tearDown(() async {
      await tagsStreamController.close();
      await updateStreamController.close();
      await getIt.reset();
    });

    test('initializes with empty habit definition for new habit', () {
      const testHabitId = 'new-habit-id';

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(
        habitSettingsControllerProvider(testHabitId),
      );

      expect(state.habitDefinition.id, equals(testHabitId));
      expect(state.habitDefinition.name, isEmpty);
      expect(state.dirty, isFalse);
      expect(state.storyTags, isEmpty);
    });

    test('loads existing habit from database', () async {
      when(() => mockJournalDb.getHabitById(habitFlossing.id))
          .thenAnswer((_) async => habitFlossing);

      final completer = Completer<void>();

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final subscription = container.listen(
        habitSettingsControllerProvider(habitFlossing.id),
        (_, next) {
          if (next.habitDefinition.name == habitFlossing.name &&
              !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      container.read(
        habitSettingsControllerProvider(habitFlossing.id).notifier,
      );

      await completer.future.timeout(const Duration(milliseconds: 100));

      final state = container.read(
        habitSettingsControllerProvider(habitFlossing.id),
      );

      expect(state.habitDefinition.name, equals(habitFlossing.name));
      expect(
          state.habitDefinition.description, equals(habitFlossing.description));
      expect(state.dirty, isFalse);

      subscription.close();
    });

    test('setDirty marks form as dirty', () {
      const testHabitId = 'test-habit-id';

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(
        habitSettingsControllerProvider(testHabitId).notifier,
      );

      controller.setDirty();

      final state = container.read(
        habitSettingsControllerProvider(testHabitId),
      );

      expect(state.dirty, isTrue);
    });

    test('setCategory updates categoryId and marks dirty', () {
      const testHabitId = 'test-habit-id';
      const categoryId = 'new-category-id';

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(
        habitSettingsControllerProvider(testHabitId).notifier,
      );

      controller.setCategory(categoryId);

      final state = container.read(
        habitSettingsControllerProvider(testHabitId),
      );

      expect(state.habitDefinition.categoryId, equals(categoryId));
      expect(state.dirty, isTrue);
    });

    test('setDashboard updates dashboardId and marks dirty', () {
      const testHabitId = 'test-habit-id';
      const dashboardId = 'new-dashboard-id';

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(
        habitSettingsControllerProvider(testHabitId).notifier,
      );

      controller.setDashboard(dashboardId);

      final state = container.read(
        habitSettingsControllerProvider(testHabitId),
      );

      expect(state.habitDefinition.dashboardId, equals(dashboardId));
      expect(state.dirty, isTrue);
    });

    test('setActiveFrom updates activeFrom and marks dirty', () {
      const testHabitId = 'test-habit-id';
      final activeFrom = DateTime(2025, 1, 15);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(
        habitSettingsControllerProvider(testHabitId).notifier,
      );

      controller.setActiveFrom(activeFrom);

      final state = container.read(
        habitSettingsControllerProvider(testHabitId),
      );

      expect(state.habitDefinition.activeFrom, equals(activeFrom));
      expect(state.dirty, isTrue);
    });

    test('setShowFrom updates daily schedule showFrom and marks dirty', () {
      const testHabitId = 'test-habit-id';
      final showFrom = DateTime(2025, 1, 1, 8);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(
        habitSettingsControllerProvider(testHabitId).notifier,
      );

      controller.setShowFrom(showFrom);

      final state = container.read(
        habitSettingsControllerProvider(testHabitId),
      );

      final schedule = state.habitDefinition.habitSchedule;
      expect(schedule, isA<DailyHabitSchedule>());
      expect((schedule as DailyHabitSchedule).showFrom, equals(showFrom));
      expect(state.dirty, isTrue);
    });

    test('setAlertAtTime updates daily schedule alertAtTime and marks dirty',
        () {
      const testHabitId = 'test-habit-id';
      final alertAtTime = DateTime(2025, 1, 1, 9, 30);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(
        habitSettingsControllerProvider(testHabitId).notifier,
      );

      controller.setAlertAtTime(alertAtTime);

      final state = container.read(
        habitSettingsControllerProvider(testHabitId),
      );

      final schedule = state.habitDefinition.habitSchedule;
      expect(schedule, isA<DailyHabitSchedule>());
      expect((schedule as DailyHabitSchedule).alertAtTime, equals(alertAtTime));
      expect(state.dirty, isTrue);
    });

    test('clearAlertAtTime removes alertAtTime from schedule and marks dirty',
        () {
      const testHabitId = 'test-habit-id';
      final alertAtTime = DateTime(2025, 1, 1, 9, 30);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(
        habitSettingsControllerProvider(testHabitId).notifier,
      );

      // First set alert time
      controller.setAlertAtTime(alertAtTime);

      // Then clear it
      controller.clearAlertAtTime();

      final state = container.read(
        habitSettingsControllerProvider(testHabitId),
      );

      final schedule = state.habitDefinition.habitSchedule;
      expect(schedule, isA<DailyHabitSchedule>());
      expect((schedule as DailyHabitSchedule).alertAtTime, isNull);
      expect(state.dirty, isTrue);
    });

    test('delete calls upsertEntityDefinition with deletedAt timestamp',
        () async {
      const testHabitId = 'test-habit-id';

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(
        habitSettingsControllerProvider(testHabitId).notifier,
      );

      await controller.delete();

      final captured = verify(
              () => mockPersistenceLogic.upsertEntityDefinition(captureAny()))
          .captured
          .single as HabitDefinition;

      expect(captured.deletedAt, isNotNull);
    });

    test('watches story tags and updates state', () async {
      const testHabitId = 'test-habit-id';
      final completer = Completer<void>();

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final subscription = container.listen(
        habitSettingsControllerProvider(testHabitId),
        (_, next) {
          if (next.storyTags.isNotEmpty && !completer.isCompleted) {
            completer.complete();
          }
        },
      );

      container.read(habitSettingsControllerProvider(testHabitId).notifier);

      // Emit tags
      tagsStreamController.add([testStoryTag1]);

      await completer.future.timeout(const Duration(milliseconds: 100));

      final state = container.read(
        habitSettingsControllerProvider(testHabitId),
      );

      expect(state.storyTags, hasLength(1));
      expect(state.storyTags.first.id, equals(testStoryTag1.id));

      subscription.close();
    });

    test('does not update from DB when form is dirty', () {
      fakeAsync((async) {
        // Initially return null, then return habit on refetch
        when(() => mockJournalDb.getHabitById(habitFlossing.id))
            .thenAnswer((_) async => null);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final subscription = container.listen(
          habitSettingsControllerProvider(habitFlossing.id),
          (_, __) {},
        );

        final controller = container.read(
          habitSettingsControllerProvider(habitFlossing.id).notifier,
        );

        async.flushMicrotasks();

        // Mark form as dirty
        controller.setDirty();

        // Update stub and trigger notification to simulate DB change
        when(() => mockJournalDb.getHabitById(habitFlossing.id))
            .thenAnswer((_) async => habitFlossing);
        updateStreamController.add({habitsNotification});

        // Give time for stream to process
        async.elapse(const Duration(milliseconds: 50));
        async.flushMicrotasks();

        final state = container.read(
          habitSettingsControllerProvider(habitFlossing.id),
        );

        // Should still have empty name (initial state) because form is dirty
        expect(state.habitDefinition.name, isEmpty);
        expect(state.dirty, isTrue);

        subscription.close();
      });
    });

    test('updates default story when matching tag exists', () {
      fakeAsync((async) {
        final habitWithDefaultStory = habitFlossing.copyWith(
          defaultStoryId: testStoryTag1.id,
        );

        when(() => mockJournalDb.getHabitById(habitWithDefaultStory.id))
            .thenAnswer((_) async => habitWithDefaultStory);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.listen(
          habitSettingsControllerProvider(habitWithDefaultStory.id),
          (_, __) {},
        );

        container.read(
          habitSettingsControllerProvider(habitWithDefaultStory.id).notifier,
        );

        // Let habit load from initial fetch
        async.elapse(const Duration(milliseconds: 20));
        async.flushMicrotasks();

        // Then emit tags
        tagsStreamController.add([testStoryTag1]);
        async.flushMicrotasks();

        final state = container.read(
          habitSettingsControllerProvider(habitWithDefaultStory.id),
        );

        expect(state.defaultStory, isNotNull);
        expect(state.defaultStory?.id, equals(testStoryTag1.id));
      });
    });

    test('preserves showFrom when setting alertAtTime', () {
      const testHabitId = 'test-habit-id';
      final showFrom = DateTime(2025, 1, 1, 8);
      final alertAtTime = DateTime(2025, 1, 1, 9, 30);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(
        habitSettingsControllerProvider(testHabitId).notifier,
      );

      // Set showFrom first
      controller.setShowFrom(showFrom);
      // Then set alertAtTime
      controller.setAlertAtTime(alertAtTime);

      final state = container.read(
        habitSettingsControllerProvider(testHabitId),
      );

      final schedule =
          state.habitDefinition.habitSchedule as DailyHabitSchedule;
      expect(schedule.showFrom, equals(showFrom));
      expect(schedule.alertAtTime, equals(alertAtTime));
    });

    test('preserves alertAtTime when setting showFrom', () {
      const testHabitId = 'test-habit-id';
      final showFrom = DateTime(2025, 1, 1, 8);
      final alertAtTime = DateTime(2025, 1, 1, 9, 30);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(
        habitSettingsControllerProvider(testHabitId).notifier,
      );

      // Set alertAtTime first
      controller.setAlertAtTime(alertAtTime);
      // Then set showFrom
      controller.setShowFrom(showFrom);

      final state = container.read(
        habitSettingsControllerProvider(testHabitId),
      );

      final schedule =
          state.habitDefinition.habitSchedule as DailyHabitSchedule;
      expect(schedule.showFrom, equals(showFrom));
      expect(schedule.alertAtTime, equals(alertAtTime));
    });

    test('disposes stream subscriptions on dispose', () {
      fakeAsync((async) {
        const testHabitId = 'test-habit-id';

        final container = ProviderContainer();

        container.read(habitSettingsControllerProvider(testHabitId).notifier);

        // Emit values to ensure subscriptions are active
        tagsStreamController.add([]);
        async.flushMicrotasks();

        // Dispose the container
        container.dispose();

        // Should not throw - streams should be properly cleaned up
        tagsStreamController.add([]);
      });
    });

    test('clears defaultStory when defaultStoryId is removed', () {
      fakeAsync((async) {
        // Start with a habit that has a defaultStoryId
        final habitWithStory = habitFlossing.copyWith(
          defaultStoryId: testStoryTag1.id,
        );

        when(() => mockJournalDb.getHabitById(habitWithStory.id))
            .thenAnswer((_) async => habitWithStory);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.listen(
          habitSettingsControllerProvider(habitWithStory.id),
          (_, __) {},
        );

        container.read(
          habitSettingsControllerProvider(habitWithStory.id).notifier,
        );

        // Let habit load from initial fetch
        async.elapse(const Duration(milliseconds: 20));
        async.flushMicrotasks();

        // Emit tags so defaultStory can resolve
        tagsStreamController.add([testStoryTag1]);
        async.flushMicrotasks();

        // Verify defaultStory is set
        var state = container.read(
          habitSettingsControllerProvider(habitWithStory.id),
        );
        expect(state.defaultStory, isNotNull);

        // Now change stub to return habit without defaultStoryId and fire notification
        final habitWithoutStory = habitFlossing.copyWith(defaultStoryId: null);
        when(() => mockJournalDb.getHabitById(habitWithStory.id))
            .thenAnswer((_) async => habitWithoutStory);
        updateStreamController.add({habitsNotification});

        async.elapse(const Duration(milliseconds: 50));
        async.flushMicrotasks();

        // Verify defaultStory is cleared
        state = container.read(
          habitSettingsControllerProvider(habitWithStory.id),
        );
        expect(state.defaultStory, isNull);
      });
    });

    test('removeAutoCompleteRuleAt handles null rule gracefully', () {
      const testHabitId = 'test-habit-id';

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(
        habitSettingsControllerProvider(testHabitId).notifier,
      );

      // Initial state has autoCompleteRule set to null
      var state = container.read(habitSettingsControllerProvider(testHabitId));
      expect(state.autoCompleteRule, isNull);

      // Remove at path [0] - calling on null should be safe (no-op)
      controller.removeAutoCompleteRuleAt([0]);

      state = container.read(habitSettingsControllerProvider(testHabitId));
      // Should still be null
      expect(state.autoCompleteRule, isNull);
    });
  });
}
