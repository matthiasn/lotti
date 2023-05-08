import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/journal/editor/editor_tools.dart';

class EntryCubit extends Cubit<EntryState> {
  EntryCubit({
    required this.entryId,
    required this.entry,
  }) : super(
          EntryState.saved(
            entryId: entryId,
            entry: entry,
            showMap: false,
            isFocused: false,
          ),
        ) {
    final lastSaved = entry.meta.updatedAt;

    _editorStateService
        .getUnsavedStream(entryId, lastSaved)
        .listen((bool dirtyFromEditorDrafts) {
      _dirty = dirtyFromEditorDrafts;
      emitState();
    });

    if (entry is Task) {
      formKey = GlobalKey<FormBuilderState>();
    }

    focusNode.addListener(() {
      _isFocused = true;
      emitState();
    });

    try {
      final serializedQuill =
          _editorStateService.getDelta(entryId) ?? entry.entryText?.quill;
      final markdown =
          entry.entryText?.markdown ?? entry.entryText?.plainText ?? '';
      final quill = serializedQuill ?? markdownToDelta(markdown);

      controller = makeController(
        serializedQuill: quill,
        selection: _editorStateService.getSelection(entryId),
      );

      controller.changes.listen((DocChange event) {
        final delta = deltaFromController(controller);
        _editorStateService.saveTempState(
          id: entryId,
          json: quillJsonFromDelta(delta),
          lastSaved: entry.meta.updatedAt,
        );
        _dirty = true;
        emitState();
      });

      _entryStream = _journalDb.watchEntityById(entryId);
      _entryStreamSubscription = _entryStream.listen((updated) {
        if (updated != null) {
          entry = updated;
          emitState();
        }
      });
    } catch (error, stackTrace) {
      getIt<LoggingDb>().captureException(
        error,
        stackTrace: stackTrace,
        subDomain: 'makeController',
        domain: 'ENTRY_CUBIT',
      );
    }
  }

  String entryId;
  JournalEntity entry;
  bool showMap = false;

  bool _dirty = false;
  bool _isFocused = false;

  late final QuillController controller;
  late final GlobalKey<FormBuilderState>? formKey;
  late final Stream<JournalEntity?> _entryStream;
  late final StreamSubscription<JournalEntity?> _entryStreamSubscription;
  final FocusNode focusNode = FocusNode();
  final EditorStateService _editorStateService = getIt<EditorStateService>();
  final JournalDb _journalDb = getIt<JournalDb>();
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();

  Future<void> save({Duration? estimate}) async {
    if (entry is Task) {
      final task = entry as Task;
      formKey?.currentState?.save();
      final formData = formKey?.currentState?.value ?? {};
      final title = formData['title'] as String?;
      final status = formData['status'] as String?;

      await _persistenceLogic.updateTask(
        entryText: entryTextFromController(controller),
        journalEntityId: entryId,
        taskData: task.data.copyWith(
          title: title ?? task.data.title,
          estimate: estimate ?? task.data.estimate,
          status:
              status != null ? taskStatusFromString(status) : task.data.status,
        ),
      );
    } else {
      final running = getIt<TimeService>().getCurrent();

      await _persistenceLogic.updateJournalEntityText(
        entryId,
        entryTextFromController(controller),
        running?.meta.id == entryId ? DateTime.now() : entry.meta.dateTo,
      );
    }

    await _editorStateService.entryWasSaved(
      id: entryId,
      lastSaved: entry.meta.updatedAt,
      controller: controller,
    );
    _dirty = false;
    emitState();
    await HapticFeedback.heavyImpact();
  }

  void focus() {
    focusNode.requestFocus();
  }

  void emitState() {
    if (_dirty) {
      emit(
        EntryState.dirty(
          entryId: entryId,
          entry: entry,
          showMap: showMap,
          isFocused: _isFocused,
        ),
      );
    } else {
      emit(
        EntryState.saved(
          entryId: entryId,
          entry: entry,
          showMap: showMap,
          isFocused: _isFocused,
        ),
      );
    }
  }

  void setDirty(dynamic _) {
    _dirty = true;
    emitState();
  }

  Future<void> toggleStarred() async {
    final item = await _journalDb.journalEntityById(entryId);
    if (item != null) {
      final prev = item.meta.starred ?? false;
      await _persistenceLogic.updateJournalEntity(
        item,
        item.meta.copyWith(
          starred: !prev,
        ),
      );
    }
  }

  void toggleMapVisible() {
    if (state.entry?.geolocation != null) {
      showMap = !showMap;
      emitState();
    }
  }

  Future<void> togglePrivate() async {
    final item = await _journalDb.journalEntityById(entryId);
    if (item != null) {
      final prev = item.meta.private ?? false;
      await _persistenceLogic.updateJournalEntity(
        item,
        item.meta.copyWith(
          private: !prev,
        ),
      );
    }
  }

  Future<void> toggleFlagged() async {
    final item = await _journalDb.journalEntityById(entryId);
    if (item != null) {
      await _persistenceLogic.updateJournalEntity(
        item,
        item.meta.copyWith(
          flag: item.meta.flag == EntryFlag.import
              ? EntryFlag.none
              : EntryFlag.import,
        ),
      );
    }
  }

  Future<bool> delete({
    required bool beamBack,
  }) async {
    final res = await _persistenceLogic.deleteJournalEntity(entryId);
    if (beamBack) {
      journalBeamerDelegate.beamBack();
    }
    return res;
  }

  Future<bool> updateFromTo({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    return _persistenceLogic.updateJournalEntityDate(
      entryId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }

  Future<String> addTagDefinition(String tag) async {
    return _persistenceLogic.addTagDefinition(tag);
  }

  Future<void> addTagIds(List<String> addedTagIds) async {
    await _persistenceLogic.addTagsWithLinked(
      journalEntityId: entryId,
      addedTagIds: addedTagIds,
    );
  }

  Future<void> removeTagId(String tagId) async {
    await _persistenceLogic.removeTag(
      journalEntityId: entryId,
      tagId: tagId,
    );
  }

  @override
  Future<void> close() async {
    if (state is EntryStateDirty && !isTestEnv) {
      await save();
    }

    await _entryStreamSubscription.cancel();
    await super.close();
  }
}
