import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/state/task_scroll_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class MockScrollController extends Mock implements ScrollController {
  @override
  bool hasClients = false;
}

class MockListController extends Mock implements ListController {}

class FakeScrollController extends Fake implements ScrollController {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeScrollController());
  });
  group('TaskScrollController', () {
    late TaskScrollController controller;
    late ScrollController scrollController;
    late ListController listController;

    setUp(() {
      scrollController = ScrollController();
      listController = ListController();
      controller = TaskScrollController(
        taskId: 'test-task-id',
        scrollController: scrollController,
        listController: listController,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('initializes with correct taskId and controllers', () {
      expect(controller.taskId, 'test-task-id');
      expect(controller.scrollController, scrollController);
      expect(controller.listController, listController);
      expect(controller.linkedEntryIndices, isEmpty);
    });

    test('updateIndices updates the linked entry indices', () {
      final indices = {
        'entry1': 0,
        'entry2': 1,
        'entry3': 2,
      };

      controller.updateIndices(indices);

      expect(controller.linkedEntryIndices, equals(indices));
    });

    test('updateIndices clears previous indices before adding new ones', () {
      controller.updateIndices({'old': 0});
      expect(controller.linkedEntryIndices, {'old': 0});

      controller.updateIndices({'new': 1});
      expect(controller.linkedEntryIndices, {'new': 1});
      expect(controller.linkedEntryIndices.containsKey('old'), isFalse);
    });

    test('scrollToEntry does nothing when entry not found', () {
      final mockListController = MockListController();
      final mockScrollController = MockScrollController()..hasClients = true;

      TaskScrollController(
        taskId: 'test',
        scrollController: mockScrollController,
        listController: mockListController,
      ).scrollToEntry('non-existent-entry');

      verifyNever(() => mockListController.animateToItem(
            index: any(named: 'index'),
            scrollController: any(named: 'scrollController'),
            alignment: any(named: 'alignment'),
            duration: any(named: 'duration'),
            curve: any(named: 'curve'),
          ));
    });

    test('scrollToEntry does nothing when scrollController has no clients', () {
      final mockListController = MockListController();
      final mockScrollController = MockScrollController()..hasClients = false;

      TaskScrollController(
        taskId: 'test',
        scrollController: mockScrollController,
        listController: mockListController,
      )
        ..updateIndices({'entry1': 5})
        ..scrollToEntry('entry1');

      verifyNever(() => mockListController.animateToItem(
            index: any(named: 'index'),
            scrollController: any(named: 'scrollController'),
            alignment: any(named: 'alignment'),
            duration: any(named: 'duration'),
            curve: any(named: 'curve'),
          ));
    });

    test('scrollToEntry animates to correct index when entry exists', () {
      final mockListController = MockListController();
      final mockScrollController = MockScrollController()..hasClients = true;

      TaskScrollController(
        taskId: 'test',
        scrollController: mockScrollController,
        listController: mockListController,
      )
        ..updateIndices({'entry1': 5})
        ..scrollToEntry('entry1');

      verify(() => mockListController.animateToItem(
            index: 5,
            scrollController: mockScrollController,
            alignment: 0.1,
            duration: any(named: 'duration'),
            curve: any(named: 'curve'),
          )).called(1);
    });

    test('scrollToSection animates to section index', () {
      final mockListController = MockListController();
      final mockScrollController = MockScrollController()..hasClients = true;

      TaskScrollController(
        taskId: 'test',
        scrollController: mockScrollController,
        listController: mockListController,
      ).scrollToSection(2);

      verify(() => mockListController.animateToItem(
            index: 2,
            scrollController: mockScrollController,
            alignment: -0.15,
            duration: any(named: 'duration'),
            curve: any(named: 'curve'),
          )).called(1);
    });

    test('scrollToSection does nothing when scrollController has no clients', () {
      final mockListController = MockListController();
      final mockScrollController = MockScrollController()..hasClients = false;

      TaskScrollController(
        taskId: 'test',
        scrollController: mockScrollController,
        listController: mockListController,
      ).scrollToSection(2);

      verifyNever(() => mockListController.animateToItem(
            index: any(named: 'index'),
            scrollController: any(named: 'scrollController'),
            alignment: any(named: 'alignment'),
            duration: any(named: 'duration'),
            curve: any(named: 'curve'),
          ));
    });
  });

  group('TaskScrollControllerNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initializes with TaskScrollController state', () {
      final notifier = container.read(
        taskScrollControllerProvider('test-task-id').notifier,
      );
      final state = container.read(
        taskScrollControllerProvider('test-task-id'),
      );

      expect(notifier.taskId, 'test-task-id');
      expect(state, isNotNull);
      expect(state!.taskId, 'test-task-id');
      expect(state.scrollController, isA<ScrollController>());
      expect(state.listController, isA<ListController>());
    });

    test('updateIndices delegates to state controller', () {
      final notifier = container.read(
        taskScrollControllerProvider('test-task-id').notifier,
      );

      final indices = {'entry1': 0, 'entry2': 1};
      notifier.updateIndices(indices);

      final state = container.read(
        taskScrollControllerProvider('test-task-id'),
      );
      expect(state!.linkedEntryIndices, equals(indices));
    });

    test('scrollToEntry delegates to state controller', () {
      final notifier = container.read(
        taskScrollControllerProvider('test-task-id').notifier,
      )

        // Add indices first
        ..updateIndices({'entry1': 5});

      // This would normally trigger animation, but without a real widget tree
      // we can only verify it doesn't throw
      expect(() => notifier.scrollToEntry('entry1'), returnsNormally);
    });

    test('scrollToSection delegates to state controller', () {
      final notifier = container.read(
        taskScrollControllerProvider('test-task-id').notifier,
      );

      // This would normally trigger animation, but without a real widget tree
      // we can only verify it doesn't throw
      expect(() => notifier.scrollToSection(2), returnsNormally);
    });

    test('different task IDs have separate controllers', () {
      final state1 = container.read(
        taskScrollControllerProvider('task1'),
      );
      final state2 = container.read(
        taskScrollControllerProvider('task2'),
      );

      expect(state1!.taskId, 'task1');
      expect(state2!.taskId, 'task2');
      expect(state1, isNot(equals(state2)));
      expect(state1.scrollController, isNot(equals(state2.scrollController)));
    });

    test('dispose cleans up the state controller', () {
      final state = container.read(
        taskScrollControllerProvider('test-task-id'),
      );

      expect(state, isNotNull);
      expect(state!.taskId, 'test-task-id');

      // Dispose the container which will dispose the notifier
      container.dispose();

      // Create a new container to verify the provider creates a new instance
      final newContainer = ProviderContainer();
      final newState = newContainer.read(
        taskScrollControllerProvider('test-task-id'),
      );

      expect(newState, isNotNull);
      expect(newState!.taskId, 'test-task-id');
      expect(newState, isNot(same(state)));

      newContainer.dispose();
    });
  });

  group('Integration tests', () {
    testWidgets('TaskScrollController works with real widgets', (tester) async {
      const taskId = 'test-task';
      late TaskScrollController controller;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                final scrollController = ref.watch(
                  taskScrollControllerProvider(taskId),
                );
                controller = scrollController!;

                return Scaffold(
                  body: CustomScrollView(
                    controller: controller.scrollController,
                    slivers: [
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => SizedBox(
                            height: 100,
                            child: Text('Item $index'),
                          ),
                          childCount: 20,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify controller is initialized
      expect(controller.taskId, taskId);
      expect(controller.scrollController.hasClients, isTrue);

      // Update indices
      controller.updateIndices({
        'entry5': 5,
        'entry10': 10,
      });

      // Verify scroll position starts at 0
      expect(controller.scrollController.offset, 0.0);

      // Note: We can't test actual scrolling behavior with ListController
      // in unit tests as it requires a full SuperListView setup
    });
  });
}
