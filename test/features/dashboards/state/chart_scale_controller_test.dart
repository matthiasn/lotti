import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/state/chart_scale_controller.dart';

void main() {
  group('BarWidthController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('initial state is 1.0', () {
      final state = container.read(barWidthControllerProvider);
      expect(state, 1.0);
    });

    test('updateScale extracts x-scale from Matrix4', () {
      final notifier = container.read(barWidthControllerProvider.notifier);

      // Create a Matrix4 with x-scale of 2.5
      final matrix = Matrix4.diagonal3Values(2.5, 1, 1);
      notifier.updateScale(matrix);

      final state = container.read(barWidthControllerProvider);
      expect(state, 2.5);
    });

    test('updateScale works with identity matrix', () {
      container
          .read(barWidthControllerProvider.notifier)
          .updateScale(Matrix4.identity());

      expect(container.read(barWidthControllerProvider), 1.0);
    });

    test('updateScale can set different scale values', () {
      final notifier = container.read(barWidthControllerProvider.notifier)
        ..updateScale(Matrix4.diagonal3Values(0.5, 1, 1));
      expect(container.read(barWidthControllerProvider), 0.5);

      notifier.updateScale(Matrix4.diagonal3Values(3, 1, 1));
      expect(container.read(barWidthControllerProvider), 3.0);
    });
  });
}
