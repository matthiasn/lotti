import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

import '../../../test_data/test_data.dart';

class _MockLabelsRepository extends Mock implements LabelsRepository {}

void main() {
  late StreamController<List<LabelDefinition>> streamController;
  late _MockLabelsRepository repository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(testLabelDefinition1);
  });

  setUp(() {
    repository = _MockLabelsRepository();
    streamController = StreamController<List<LabelDefinition>>.broadcast();

    when(() => repository.watchLabels())
        .thenAnswer((_) => streamController.stream);

    container = ProviderContainer(
      overrides: [
        labelsRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() async {
    await streamController.close();
    container.dispose();
  });

  test('initial state is loading until stream emits', () async {
    final state = container.read(labelsListControllerProvider);
    expect(state, const AsyncValue<List<LabelDefinition>>.loading());

    streamController.add([testLabelDefinition1]);
    await Future.microtask(() {});

    final updated = container.read(labelsListControllerProvider);
    expect(updated.hasValue, isTrue);
    expect(updated.value, [testLabelDefinition1]);
  });

  test('deleteLabel forwards to repository', () async {
    when(() => repository.deleteLabel(any())).thenAnswer((_) async {});

    final notifier = container.read(labelsListControllerProvider.notifier);

    await notifier.deleteLabel(testLabelDefinition1.id);
    verify(() => repository.deleteLabel(testLabelDefinition1.id)).called(1);
  });

  test('deleteLabel surfaces errors', () async {
    when(() => repository.deleteLabel(any())).thenThrow(Exception('fail'));

    final notifier = container.read(labelsListControllerProvider.notifier);

    await notifier.deleteLabel(testLabelDefinition1.id);

    final state = container.read(labelsListControllerProvider);
    expect(state.hasError, isTrue);
  });
}
