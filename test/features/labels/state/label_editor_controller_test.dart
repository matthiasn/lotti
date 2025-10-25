// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/label_editor_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

import '../../../test_data/test_data.dart';

class _MockLabelsRepository extends Mock implements LabelsRepository {}

void main() {
  late ProviderContainer container;
  late _MockLabelsRepository repository;

  setUpAll(() {
    registerFallbackValue(testLabelDefinition1);
  });

  setUp(() {
    repository = _MockLabelsRepository();
    container = ProviderContainer(
      overrides: [
        labelsRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('initial state defaults when creating new label', () {
    final provider = labelEditorControllerProvider(const LabelEditorArgs());
    final state = container.read(provider);

    expect(state.name, isEmpty);
    expect(state.colorHex, isNotEmpty);
    expect(state.isPrivate, isFalse);
    expect(state.hasChanges, isFalse);
    expect(state.isSaving, isFalse);
  });

  test('initial state uses provided initial name when creating new label', () {
    final provider = labelEditorControllerProvider(
      const LabelEditorArgs(initialName: 'Blocker'),
    );

    final state = container.read(provider);

    expect(state.name, 'Blocker');
    expect(state.hasChanges, isFalse);
  });

  test('initial state uses existing label when editing', () {
    final provider = labelEditorControllerProvider(
      LabelEditorArgs(label: testLabelDefinition1),
    );
    final state = container.read(provider);

    expect(state.name, testLabelDefinition1.name);
    expect(state.colorHex, testLabelDefinition1.color);
    expect(state.isPrivate, testLabelDefinition1.private ?? false);
  });

  test('setName updates state and marks changes', () {
    final provider = labelEditorControllerProvider(
      LabelEditorArgs(label: testLabelDefinition1),
    );
    final notifier = container.read(provider.notifier);

    notifier.setName('Updated');

    final state = container.read(provider);
    expect(state.name, 'Updated');
    expect(state.hasChanges, isTrue);
  });

  test('save creates label when no duplicate exists', () async {
    when(() => repository.getAllLabels()).thenAnswer((_) async => []);
    when(
      () => repository.createLabel(
        name: any(named: 'name'),
        color: any(named: 'color'),
        description: any(named: 'description'),
        private: any(named: 'private'),
      ),
    ).thenAnswer((_) async => testLabelDefinition1);

    final provider = labelEditorControllerProvider(const LabelEditorArgs());
    final notifier = container.read(provider.notifier);

    notifier.setName('Release blocker');
    final result = await notifier.save();

    expect(result, testLabelDefinition1);
    verify(
      () => repository.createLabel(
        name: any(named: 'name'),
        color: any(named: 'color'),
        description: any(named: 'description'),
        private: any(named: 'private'),
      ),
    ).called(1);
  });

  test('save returns error when duplicate label exists', () async {
    when(() => repository.getAllLabels())
        .thenAnswer((_) async => [testLabelDefinition1]);

    final provider = labelEditorControllerProvider(const LabelEditorArgs());
    final notifier = container.read(provider.notifier);

    notifier.setName(testLabelDefinition1.name);
    final result = await notifier.save();

    expect(result, isNull);
    final state = container.read(provider);
    expect(
      state.errorMessage,
      contains('already exists'),
    );
    verifyNever(() => repository.createLabel(
          name: any(named: 'name'),
          color: any(named: 'color'),
          description: any(named: 'description'),
          private: any(named: 'private'),
        ));
  });

  test('save updates existing label', () async {
    when(() => repository.getAllLabels()).thenAnswer((_) async => []);
    when(
      () => repository.updateLabel(
        testLabelDefinition1,
        name: any(named: 'name'),
        color: any(named: 'color'),
        description: any(named: 'description'),
        private: any(named: 'private'),
      ),
    ).thenAnswer((_) async => testLabelDefinition1);

    final provider = labelEditorControllerProvider(
      LabelEditorArgs(label: testLabelDefinition1),
    );
    final notifier = container.read(provider.notifier);

    notifier.setName('Updated');
    final result = await notifier.save();

    expect(result, testLabelDefinition1);
    verify(
      () => repository.updateLabel(
        testLabelDefinition1,
        name: 'Updated',
        color: any(named: 'color'),
        description: any(named: 'description'),
        private: any(named: 'private'),
      ),
    ).called(1);
  });
}
