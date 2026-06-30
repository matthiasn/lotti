import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_mru_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  SavedTaskFilterMruController controller() =>
      container.read(savedTaskFilterMruProvider.notifier);

  test('starts empty', () {
    expect(container.read(savedTaskFilterMruProvider), isEmpty);
  });

  test('touch promotes an id to the front', () {
    controller()
      ..touch('a')
      ..touch('b')
      ..touch('c');

    // Most-recent first.
    expect(container.read(savedTaskFilterMruProvider), ['c', 'b', 'a']);
  });

  test('touching an existing id moves it to the front without duplicating', () {
    controller()
      ..touch('a')
      ..touch('b')
      ..touch('c')
      ..touch('a');

    expect(container.read(savedTaskFilterMruProvider), ['a', 'c', 'b']);
  });

  test('re-touching the current front is a no-op order', () {
    controller()
      ..touch('a')
      ..touch('a');

    expect(container.read(savedTaskFilterMruProvider), ['a']);
  });
}
