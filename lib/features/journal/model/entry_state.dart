import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/journal_entities.dart';

part 'entry_state.freezed.dart';

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
