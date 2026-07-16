import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_task_metadata.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';

const _snapshotCategory = DayAgentCategory(
  id: 'cat-snapshot',
  name: 'Snapshot',
  colorHex: '5ED4B7',
);

void main() {
  group('LiveTaskMetadata.categoryOr', () {
    test('keeps the persisted category when no live assignment exists', () {
      const metadata = LiveTaskMetadata();

      expect(metadata.categoryOr(_snapshotCategory), _snapshotCategory);
    });

    test('merges live identity and normalized color over the snapshot', () {
      const metadata = LiveTaskMetadata(
        categoryId: 'cat-live',
        categoryName: 'Penguin Logistics',
        categoryColorHex: '#A855F7CC',
      );

      expect(
        metadata.categoryOr(_snapshotCategory),
        const DayAgentCategory(
          id: 'cat-live',
          name: 'Penguin Logistics',
          colorHex: 'A855F7',
        ),
      );
    });

    test('uses safe snapshot fallbacks for incomplete live definitions', () {
      const changedAssignment = LiveTaskMetadata(
        categoryId: 'cat-new',
        categoryName: ' ',
        categoryColorHex: '#BAD',
      );
      const sameAssignment = LiveTaskMetadata(
        categoryId: 'cat-snapshot',
        categoryName: '',
      );

      expect(
        changedAssignment.categoryOr(_snapshotCategory),
        const DayAgentCategory(
          id: 'cat-new',
          name: 'cat-new',
          colorHex: '5ED4B7',
        ),
      );
      expect(
        sameAssignment.categoryOr(_snapshotCategory),
        _snapshotCategory,
      );

      expect(
        const LiveTaskMetadata(
          categoryId: 'cat-invalid',
          categoryName: 'Legacy category',
          categoryColorHex: '#NOPE!!',
        ).categoryOr(_snapshotCategory),
        const DayAgentCategory(
          id: 'cat-invalid',
          name: 'Legacy category',
          colorHex: '5ED4B7',
        ),
      );
    });
  });

  group('liveTaskMetadataProvider', () {
    late StreamController<Set<String>> updates;
    late TestGetItMocks mocks;
    late ProviderContainer container;

    setUp(() async {
      updates = StreamController<Set<String>>.broadcast();
      mocks = await setUpTestGetIt();
      when(
        () => mocks.updateNotifications.updateStream,
      ).thenAnswer((_) => updates.stream);
      container = ProviderContainer();
    });

    tearDown(() async {
      container.dispose();
      await updates.close();
      await tearDownTestGetIt();
    });

    test('resolves task title, cover art, crop, and category', () async {
      final baseTask = TestTaskFactory.create(
        id: 'task-1',
        title: 'Feed the penguins',
        categoryId: 'cat-work',
      );
      final task = baseTask.copyWith(
        data: baseTask.data.copyWith(
          coverArtId: 'penguin-portrait',
          coverArtCropX: 0.25,
        ),
      );
      final category = CategoryTestUtils.createTestCategory(
        id: 'cat-work',
        name: 'Aquarium Operations',
        color: '#4F9DDE',
      );
      when(() => mocks.journalDb.journalEntityById('task-1')).thenAnswer(
        (_) async => task,
      );
      when(() => mocks.journalDb.getCategoryById('cat-work')).thenAnswer(
        (_) async => category,
      );

      final metadata = await container.read(
        liveTaskMetadataProvider('task-1').future,
      );

      expect(metadata.title, 'Feed the penguins');
      expect(metadata.coverArtId, 'penguin-portrait');
      expect(metadata.coverArtCropX, 0.25);
      expect(metadata.categoryId, 'cat-work');
      expect(metadata.categoryName, 'Aquarium Operations');
      expect(metadata.categoryColorHex, '#4F9DDE');
      expect(metadata.missing, isFalse);
    });

    test('reports a missing linked task without querying a category', () async {
      final metadata = await container.read(
        liveTaskMetadataProvider('missing-task').future,
      );

      expect(metadata.missing, isTrue);
      expect(metadata.title, isNull);
      verifyNever(() => mocks.journalDb.getCategoryById(any()));
    });

    test(
      'normalizes blank task metadata without querying a category',
      () async {
        final baseTask = TestTaskFactory.create(
          id: 'task-blank',
          title: '   ',
        );
        final task = baseTask.copyWith(
          data: baseTask.data.copyWith(coverArtId: '  '),
        );
        when(() => mocks.journalDb.journalEntityById('task-blank')).thenAnswer(
          (_) async => task,
        );

        final metadata = await container.read(
          liveTaskMetadataProvider('task-blank').future,
        );

        expect(metadata.title, isNull);
        expect(metadata.coverArtId, isNull);
        expect(metadata.categoryId, isNull);
        expect(metadata.coverArtCropX, task.data.coverArtCropX);
        verifyNever(() => mocks.journalDb.getCategoryById(any()));
      },
    );

    test('refreshes for task and category notifications only', () async {
      var task = TestTaskFactory.create(
        id: 'task-1',
        title: 'Old task title',
        categoryId: 'cat-work',
      );
      var category = CategoryTestUtils.createTestCategory(
        id: 'cat-work',
        name: 'Work',
      );
      when(() => mocks.journalDb.journalEntityById('task-1')).thenAnswer(
        (_) async => task,
      );
      when(() => mocks.journalDb.getCategoryById(any())).thenAnswer(
        (_) async => category,
      );

      final provider = liveTaskMetadataProvider('task-1');
      expect((await container.read(provider.future)).title, 'Old task title');

      updates.add({'unrelated'});
      await Future<void>.value();
      verify(() => mocks.journalDb.journalEntityById('task-1')).called(1);

      task = TestTaskFactory.create(
        id: 'task-1',
        title: 'Renamed task title',
        categoryId: 'cat-personal',
      );
      category = CategoryTestUtils.createTestCategory(
        id: 'cat-personal',
        name: 'Personal',
      );
      updates.add({'task-1'});
      await Future<void>.value();
      final reassigned = await container.read(provider.future);
      expect(reassigned.title, 'Renamed task title');
      expect(reassigned.categoryId, 'cat-personal');

      category = category.copyWith(name: 'Penguin Logistics');
      updates.add({categoriesNotification});
      await Future<void>.value();
      final renamedCategory = await container.read(provider.future);
      expect(renamedCategory.categoryName, 'Penguin Logistics');
    });
  });

  test(
    'live resolution is available only with its two core services',
    () async {
      expect(canResolveLiveTaskMetadata(), isFalse);

      await setUpTestGetIt();
      addTearDown(tearDownTestGetIt);

      expect(canResolveLiveTaskMetadata(), isTrue);
    },
  );
}
