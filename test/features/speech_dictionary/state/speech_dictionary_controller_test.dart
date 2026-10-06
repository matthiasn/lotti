import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/speech_dictionary/domain/speech_dictionary_terms.dart';
import 'package:lotti/features/speech_dictionary/repository/speech_dictionary_repository.dart';
import 'package:lotti/features/speech_dictionary/state/speech_dictionary_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';

SpeechDictionaryEntry _entry(
  String term, {
  List<String>? categoryIds,
  List<String>? misheardAs,
}) => SpeechDictionaryEntry(
  id: speechDictionaryEntryId(term),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  term: term,
  vectorClock: null,
  categoryIds: categoryIds,
  misheardAs: misheardAs,
);

void main() {
  late MockSpeechDictionaryRepository repository;
  late StreamController<List<SpeechDictionaryEntry>> entries;
  late ProviderContainer container;

  final kubernetes = _entry(
    'Kubernetes',
    categoryIds: ['work'],
    misheardAs: ['Cuban Eddies'],
  );

  setUp(() {
    repository = MockSpeechDictionaryRepository();
    entries = StreamController<List<SpeechDictionaryEntry>>.broadcast();
    when(repository.watchEntries).thenAnswer((_) => entries.stream);
    when(() => repository.entryForTerm(any())).thenAnswer((_) async => null);
    when(
      () => repository.save(
        term: any(named: 'term'),
        categoryIds: any(named: 'categoryIds'),
        misheardAs: any(named: 'misheardAs'),
        previous: any(named: 'previous'),
      ),
    ).thenAnswer(
      (invocation) async => _entry(
        invocation.namedArguments[#term] as String,
        categoryIds: invocation.namedArguments[#categoryIds] as List<String>?,
        misheardAs: invocation.namedArguments[#misheardAs] as List<String>?,
      ),
    );
    container = ProviderContainer(
      overrides: withServiceOverrides([
        speechDictionaryRepositoryProvider.overrideWithValue(repository),
      ]),
    );
  });

  tearDown(() async {
    container.dispose();
    await entries.close();
  });

  /// The editor for [args], kept alive for the test.
  SpeechDictionaryEditorController editor(SpeechDictionaryEditorArgs args) {
    final provider = speechDictionaryEditorControllerProvider(args);
    container.listen(provider, (_, _) {});
    return container.read(provider.notifier);
  }

  SpeechDictionaryEditorState stateOf(SpeechDictionaryEditorArgs args) =>
      container.read(speechDictionaryEditorControllerProvider(args));

  group('speechDictionaryEntryProvider', () {
    test('finds the entry by id, and null once it is gone', () async {
      final provider = speechDictionaryEntryProvider(kubernetes.id);
      container.listen(provider, (_, _) {});

      entries.add([kubernetes]);
      await pumpEventQueue();
      expect(container.read(provider).value, kubernetes);

      entries.add([]);
      await pumpEventQueue();
      expect(container.read(provider).value, isNull);
    });
  });

  group('SpeechDictionaryEditorController', () {
    final editArgs = SpeechDictionaryEditorArgs(entry: kubernetes);
    const createArgs = SpeechDictionaryEditorArgs(initialTerm: ' Lotti ');

    test('opens on the entry, or on the prefilled term', () {
      editor(editArgs);
      editor(createArgs);

      final editing = stateOf(editArgs);
      expect(editing.term, 'Kubernetes');
      expect(editing.categoryIds, {'work'});
      expect(editing.misheardAs, ['Cuban Eddies']);
      expect(editing.hasChanges, isFalse);
      expect(stateOf(createArgs).term, 'Lotti');
    });

    test('tracks changes against what it opened with', () {
      final controller = editor(editArgs)..setTerm('Kubernetes ');
      expect(stateOf(editArgs).hasChanges, isFalse);

      controller.setCategoryIds({'work', 'home'});
      expect(stateOf(editArgs).hasChanges, isTrue);

      controller.removeCategoryId('home');
      expect(stateOf(editArgs).hasChanges, isFalse);

      controller.setMisheardAs(['Cuban Eddies', 'Cooper Netties']);
      expect(stateOf(editArgs).hasChanges, isTrue);
    });

    test('saves the form through the repository and settles', () async {
      final controller = editor(editArgs)
        ..setCategoryIds({})
        ..setMisheardAs(['Cooper Netties']);

      final saved = await controller.save();

      expect(saved?.categoryIds, isEmpty);
      verify(
        () => repository.save(
          term: 'Kubernetes',
          categoryIds: const [],
          misheardAs: const ['Cooper Netties'],
          previous: kubernetes,
        ),
      ).called(1);
      final state = stateOf(editArgs);
      expect(
        (state.hasChanges, state.isSaving, state.error),
        (
          false,
          false,
          null,
        ),
      );
    });

    test('keeps its own term when respelled only in case', () async {
      final controller = editor(editArgs)..setTerm('kubernetes');

      expect(await controller.save(), isNotNull);
      // The term is this entry's own, not a duplicate of another.
      verifyNever(() => repository.entryForTerm(any()));
    });

    for (final (name, term, error) in [
      ('an empty term', '  ', SpeechDictionaryEditorError.emptyTerm),
      (
        'an over-long term',
        'x' * (kMaxTermLength + 1),
        SpeechDictionaryEditorError.termTooLong,
      ),
    ]) {
      test('refuses $name', () async {
        final controller = editor(createArgs)..setTerm(term);

        expect(await controller.save(), isNull);
        expect(stateOf(createArgs).error, error);
        verifyNever(
          () => repository.save(
            term: any(named: 'term'),
            categoryIds: any(named: 'categoryIds'),
            misheardAs: any(named: 'misheardAs'),
            previous: any(named: 'previous'),
          ),
        );
      });
    }

    test('refuses a term another entry already holds', () async {
      when(
        () => repository.entryForTerm('Kubernetes'),
      ).thenAnswer((_) async => kubernetes);
      final controller = editor(createArgs)..setTerm('Kubernetes');

      expect(await controller.save(), isNull);
      expect(stateOf(createArgs).error, SpeechDictionaryEditorError.duplicate);

      // Editing clears the refusal.
      controller.setTerm('Kubernetes2');
      expect(stateOf(createArgs).error, isNull);
    });
  });
}
