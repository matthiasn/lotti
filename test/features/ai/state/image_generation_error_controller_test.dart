import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/image_generation_error_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });
  tearDown(() {
    container.dispose();
  });

  String? read(String id) =>
      container.read(imageGenerationErrorControllerProvider(id: id));

  group('ImageGenerationErrorController', () {
    test('initial reason is null', () {
      expect(read('task-1'), isNull);
    });

    test('setError stores the provider reason verbatim', () {
      container
          .read(imageGenerationErrorControllerProvider(id: 'task-1').notifier)
          .setError('PROHIBITED_CONTENT');

      expect(read('task-1'), 'PROHIBITED_CONTENT');
    });

    test('setError(null) clears a previously set reason', () {
      final provider = imageGenerationErrorControllerProvider(id: 'task-1');
      container.read(provider.notifier).setError('IMAGE_SAFETY');
      expect(read('task-1'), 'IMAGE_SAFETY');

      container.read(provider.notifier).setError(null);
      expect(read('task-1'), isNull);
    });

    test('reasons are isolated per id', () {
      container
          .read(imageGenerationErrorControllerProvider(id: 'task-1').notifier)
          .setError('PROHIBITED_CONTENT');

      expect(read('task-1'), 'PROHIBITED_CONTENT');
      expect(read('task-2'), isNull);
    });
  });
}
