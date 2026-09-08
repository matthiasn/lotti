import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_fire.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  const stride = BillboardGeometry.floatsPerInstance;
  final now = DateTime.utc(2026, 9, 8);

  test('only overdue unfinished tasks and their billboards produce flames', () {
    final tasks = [
      for (final state in PlazaTaskState.values)
        PlazaTask(
          id: state.name,
          createdAt: now,
          title: state.name,
          state: state,
          due: now.subtract(const Duration(days: 1)),
          progress: 0,
          checklistItems: 0,
          linkedTaskIds: const [],
          categoryColor: 0,
        ),
    ];
    final world = PlazaWorld(
      tasks: tasks,
      now: now,
      projectLabel: 'Waddle',
      layout: StreetLayout(projectSeed: 1),
    );
    final sources = fireSourcesFor(world);
    expect(sources.map((s) => s.taskId).toSet(), {
      'open',
      'inProgress',
      'blocked',
    });
    for (final id in ['open', 'inProgress', 'blocked']) {
      expect(sources.where((s) => s.taskId == id).length, greaterThan(1));
    }
    expect(
      fireSourcesFor(
        PlazaWorld(
          tasks: const [],
          now: now,
          projectLabel: '',
          layout: StreetLayout(projectSeed: 1),
        ),
      ),
      isEmpty,
    );
  });

  test(
    'fixed budget follows the nearest source and animates in the same buffer',
    () {
      final data = Float32List(4 * stride);
      final buffer = PlazaFireBuffer(
        sources: [
          for (var i = 0; i < 3; i++)
            PlazaFireSource(
              taskId: '$i',
              x: i * 100,
              y: 10,
              z: 0,
              width: 8,
              facing: 0,
            ),
        ],
        data: data,
        maxSources: 1,
        particlesPerSource: 4,
      );
      expect(buffer.count, 4);
      var committed = 0;
      buffer.reserveBounds((count) {
        committed = count;
        expect(data[0], lessThan(0));
        expect(data[stride], greaterThan(200));
      });
      expect(committed, 4);
      expect(data, everyElement(0));
      buffer.update(0.2, Vector3(0, 10, 0));
      expect(data[0].abs(), lessThan(8));
      final height = data[1];
      buffer.update(0.3, Vector3(0, 10, 0));
      expect(data[1], isNot(height));
      buffer.update(1, Vector3(200, 10, 0));
      expect(data[0], closeTo(200, 8));
      expect(buffer.data, same(data));
      for (var i = 0; i < buffer.count; i++) {
        expect(data[i * stride + 9], inInclusiveRange(0, 1));
        expect(data[i * stride + 3], greaterThan(0));
        expect(data[i * stride + 4], greaterThan(0));
      }
      buffer.update(2, Vector3(1000, 10, 0));
      for (var i = 0; i < buffer.count; i++) {
        expect(data[i * stride + 9], 0);
      }
    },
  );

  test('empty sources draw nothing and insufficient storage is rejected', () {
    final buffer = PlazaFireBuffer(sources: const [], data: Float32List(0));
    var committed = -1;
    buffer
      ..reserveBounds((count) => committed = count)
      ..update(1, Vector3.zero());
    expect(committed, 0);
    expect(buffer.count, 0);
    expect(
      () => PlazaFireBuffer(
        sources: [
          PlazaFireSource(taskId: 'a', x: 0, y: 0, z: 0, width: 1, facing: 0),
        ],
        data: Float32List(0),
      ),
      throwsArgumentError,
    );
  });
}
