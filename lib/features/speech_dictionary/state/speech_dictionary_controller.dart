import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/speech_dictionary/domain/speech_dictionary_terms.dart';
import 'package:lotti/features/speech_dictionary/repository/speech_dictionary_repository.dart';

/// Every live dictionary entry, ordered by term, kept current with edits
/// here and on other devices. While private entries are hidden, an entry
/// limited only to private categories is hidden with them.
final speechDictionaryEntriesProvider =
    StreamProvider<List<SpeechDictionaryEntry>>(
      (ref) => ref
          .watch(speechDictionaryRepositoryProvider)
          .watchEntries(
            includePrivate:
                ref.watch(showPrivateEntriesProvider).value ?? false,
          ),
    );

/// The live entry with the given id, or null once it is gone.
final ProviderFamily<AsyncValue<SpeechDictionaryEntry?>, String>
speechDictionaryEntryProvider =
    Provider.family<AsyncValue<SpeechDictionaryEntry?>, String>(
      (ref, id) => ref
          .watch(speechDictionaryEntriesProvider)
          .whenData(
            (entries) => entries.firstWhereOrNull((entry) => entry.id == id),
          ),
    );

/// Why the editor refused to save.
enum SpeechDictionaryEditorError { emptyTerm, termTooLong, duplicate }

/// The form state of the dictionary entry editor.
class SpeechDictionaryEditorState {
  const SpeechDictionaryEditorState({
    required this.term,
    required this.categoryIds,
    required this.misheardAs,
    this.isSaving = false,
    this.hasChanges = false,
    this.error,
  });

  factory SpeechDictionaryEditorState.initial(SpeechDictionaryEditorArgs args) {
    final entry = args.entry;
    return SpeechDictionaryEditorState(
      term: entry?.term ?? args.initialTerm?.trim() ?? '',
      categoryIds: {...?entry?.categoryIds},
      misheardAs: [...?entry?.misheardAs],
    );
  }

  final String term;

  /// The categories the term is limited to; empty for every category.
  final Set<String> categoryIds;
  final List<String> misheardAs;
  final bool isSaving;
  final bool hasChanges;
  final SpeechDictionaryEditorError? error;

  SpeechDictionaryEditorState copyWith({
    String? term,
    Set<String>? categoryIds,
    List<String>? misheardAs,
    bool? isSaving,
    bool? hasChanges,
    SpeechDictionaryEditorError? error,
    bool clearError = false,
  }) {
    return SpeechDictionaryEditorState(
      term: term ?? this.term,
      categoryIds: categoryIds ?? this.categoryIds,
      misheardAs: misheardAs ?? this.misheardAs,
      isSaving: isSaving ?? this.isSaving,
      hasChanges: hasChanges ?? this.hasChanges,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// The family key of [speechDictionaryEditorControllerProvider]: the entry
/// being edited, or none to add one (optionally prefilled with
/// [initialTerm]).
@immutable
class SpeechDictionaryEditorArgs {
  const SpeechDictionaryEditorArgs({this.entry, this.initialTerm});

  final SpeechDictionaryEntry? entry;
  final String? initialTerm;

  @override
  bool operator ==(Object other) =>
      other is SpeechDictionaryEditorArgs &&
      other.entry == entry &&
      other.initialTerm == initialTerm;

  @override
  int get hashCode => Object.hash(entry, initialTerm);
}

final NotifierProviderFamily<
  SpeechDictionaryEditorController,
  SpeechDictionaryEditorState,
  SpeechDictionaryEditorArgs
>
speechDictionaryEditorControllerProvider = NotifierProvider.autoDispose
    .family<
      SpeechDictionaryEditorController,
      SpeechDictionaryEditorState,
      SpeechDictionaryEditorArgs
    >(SpeechDictionaryEditorController.new);

/// Drives the add/edit form of one dictionary entry: the term, the
/// categories it is limited to and its misheard spellings, with dirty
/// tracking against what the form opened with.
class SpeechDictionaryEditorController
    extends Notifier<SpeechDictionaryEditorState> {
  SpeechDictionaryEditorController(this.args);

  final SpeechDictionaryEditorArgs args;
  late SpeechDictionaryEditorState _baseline;

  @override
  SpeechDictionaryEditorState build() =>
      _baseline = SpeechDictionaryEditorState.initial(args);

  void setTerm(String value) => _update(state.copyWith(term: value));

  /// Replaces the category scope; an empty set means every category.
  void setCategoryIds(Set<String> ids) =>
      _update(state.copyWith(categoryIds: {...ids}));

  void removeCategoryId(String id) =>
      _update(state.copyWith(categoryIds: {...state.categoryIds}..remove(id)));

  void setMisheardAs(List<String> forms) =>
      _update(state.copyWith(misheardAs: [...forms]));

  /// Validates and saves the entry. Returns the saved entry, or null when
  /// the form was refused (see [SpeechDictionaryEditorState.error]).
  Future<SpeechDictionaryEntry?> save() async {
    final term = state.term.trim();
    final error = term.isEmpty
        ? SpeechDictionaryEditorError.emptyTerm
        : term.length > kMaxTermLength
        ? SpeechDictionaryEditorError.termTooLong
        : await _isDuplicate(term)
        ? SpeechDictionaryEditorError.duplicate
        : null;
    if (error != null) {
      state = state.copyWith(error: error);
      return null;
    }

    state = state.copyWith(isSaving: true, clearError: true);
    final saved = await ref
        .read(speechDictionaryRepositoryProvider)
        .save(
          term: term,
          categoryIds: state.categoryIds.toList(),
          misheardAs: state.misheardAs,
          previous: args.entry,
        );
    if (!ref.mounted) return saved;
    _baseline = SpeechDictionaryEditorState.initial(
      SpeechDictionaryEditorArgs(entry: saved),
    );
    state = _baseline;
    return saved;
  }

  /// Whether [term] is another live entry's term: saving would overwrite
  /// it, since the id is the term.
  Future<bool> _isDuplicate(String term) async {
    if (speechDictionaryEntryId(term) == args.entry?.id) return false;
    final stored = await ref
        .read(speechDictionaryRepositoryProvider)
        .entryForTerm(term);
    return stored != null;
  }

  void _update(SpeechDictionaryEditorState next) {
    const listEquality = ListEquality<String>();
    const setEquality = SetEquality<String>();
    state = next.copyWith(
      clearError: true,
      hasChanges:
          next.term.trim() != _baseline.term ||
          !setEquality.equals(next.categoryIds, _baseline.categoryIds) ||
          !listEquality.equals(next.misheardAs, _baseline.misheardAs),
    );
  }
}
