import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/state/front_entity_preview_provider.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';

import '../../../test_data/test_data.dart';

void main() {
  final at = DateTime(2026, 11, 9, 10);

  /// The penguin crew's weather check, with every field its card shows.
  final iceTask = testTask.copyWith(
    meta: testTask.meta.copyWith(id: 'ice-pad', categoryId: 'launch'),
    data: testTask.data.copyWith(
      title: 'Check the ice-pad weather window',
      status: TaskStatus.inProgress(id: 's', createdAt: at, utcOffset: 0),
      due: DateTime(2026, 11, 9, 17),
      estimate: const Duration(minutes: 30),
      coverArtId: 'cover-1',
      coverArtCropX: 0.2,
    ),
  );

  late Map<String, TaskPreview?> previews;
  late List<String> taskReads;
  late ProviderContainer container;

  setUp(() {
    previews = {};
    taskReads = [];
    container = ProviderContainer(
      overrides: [
        taskPreviewProvider.overrideWith((ref, id) async {
          taskReads.add(id);
          return previews[id];
        }),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<FrontEntityPreview?> read(FrontDestinationKind kind, String id) {
    final sub = container.listen(
      frontEntityPreviewProvider((kind, id)),
      (_, _) {},
    );
    addTearDown(sub.close);
    return container.read(frontEntityPreviewProvider((kind, id)).future);
  }

  group('frontTaskPreviewOf', () {
    test('keeps the glance-level fields of the task and its one-liner', () {
      final preview = frontTaskPreviewOf(
        TaskPreview(task: iceTask, oneLiner: 'Crosswind near the limit'),
      );

      expect(
        preview,
        FrontTaskPreview(
          entityId: 'ice-pad',
          title: 'Check the ice-pad weather window',
          status: iceTask.data.status,
          oneLiner: 'Crosswind near the limit',
          due: DateTime(2026, 11, 9, 17),
          estimate: const Duration(minutes: 30),
          categoryId: 'launch',
          coverArtId: 'cover-1',
          coverArtCropX: 0.2,
        ),
      );
    });

    test('leaves out what the task does not have', () {
      final preview = frontTaskPreviewOf(TaskPreview(task: testTask));

      expect(preview.oneLiner, isNull);
      expect(preview.due, isNull);
      expect(preview.categoryId, isNull);
      expect(preview.coverArtId, isNull);
      expect(preview.coverArtCropX, 0.5);
    });
  });

  group('frontEntityPreviewProvider', () {
    test("resolves a task to its card's preview", () async {
      previews['ice-pad'] = TaskPreview(task: iceTask, oneLiner: 'Windy');

      final preview = await read(FrontDestinationKind.task, 'ice-pad');

      expect(
        preview,
        isA<FrontTaskPreview>()
            .having((p) => p.entityId, 'entityId', 'ice-pad')
            .having((p) => p.oneLiner, 'oneLiner', 'Windy'),
      );
    });

    test('is null for a task that is gone', () async {
      expect(await read(FrontDestinationKind.task, 'deleted'), isNull);
      expect(taskReads, ['deleted']);
    });

    test('follows the task as it changes: a status set after the turn shows '
        'on the card', () async {
      previews['ice-pad'] = TaskPreview(task: iceTask);
      final first = await read(FrontDestinationKind.task, 'ice-pad');
      expect((first! as FrontTaskPreview).settled, isFalse);

      previews['ice-pad'] = TaskPreview(
        task: iceTask.copyWith(
          data: iceTask.data.copyWith(
            status: TaskStatus.done(id: 's2', createdAt: at, utcOffset: 0),
          ),
        ),
      );
      container.invalidate(taskPreviewProvider('ice-pad'));
      final again = await container.read(
        frontEntityPreviewProvider((
          FrontDestinationKind.task,
          'ice-pad',
        )).future,
      );

      expect((again! as FrontTaskPreview).settled, isTrue);
    });

    for (final kind in FrontDestinationKind.values.where(
      (kind) => kind != FrontDestinationKind.task,
    )) {
      test(
        'has no preview yet for a ${kind.wireName}, and reads no task',
        () async {
          expect(await read(kind, 'x'), isNull);
          expect(taskReads, isEmpty);
        },
      );
    }
  });
}
