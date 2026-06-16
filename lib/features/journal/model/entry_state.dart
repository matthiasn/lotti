import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/journal_entities.dart';

part 'entry_state.freezed.dart';

/// The two-state machine for an entry in the detail view, owned by
/// `EntryController`: `saved` (the editor matches the persisted entity) and
/// `dirty` (there are unsaved edits). Both carry the resolved entity, map
/// visibility, focus/toolbar flags, and the event form key; the save button and
/// editor chrome key off which variant is active.
@freezed
sealed class EntryState with _$EntryState {
  factory EntryState.saved({
    required String entryId,
    required JournalEntity? entry,
    required bool showMap,
    required bool isFocused,
    required bool shouldShowEditorToolBar,
    GlobalKey<FormBuilderState>? formKey,
  }) = _EntryStateSaved;

  factory EntryState.dirty({
    required String entryId,
    required JournalEntity? entry,
    required bool showMap,
    required bool isFocused,
    required bool shouldShowEditorToolBar,
    GlobalKey<FormBuilderState>? formKey,
  }) = EntryStateDirty;
}
