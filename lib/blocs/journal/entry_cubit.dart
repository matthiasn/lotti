import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/journal/editor/editor_tools.dart';
import 'package:tuple/tuple.dart';

class EntryCubit extends Cubit<EntryState> {
  EntryCubit({
    required this.entryId,
    required this.entry,
  }) : super(
          EntryState.saved(
            entryId: entryId,
            entry: entry,
          ),
        ) {
    final lastSaved = entry.meta.updatedAt;

    _editorStateService
        .getUnsavedStream(entryId, lastSaved)
        .listen((bool dirtyFromEditorDrafts) {
      dirty = dirtyFromEditorDrafts;
      emitState();
    });

    if (entry is Task) {
      formKey = GlobalKey<FormBuilderState>();
    }

    controller = makeController(
      serializedQuill:
          _editorStateService.getDelta(entryId) ?? entry.entryText?.quill,
      selection: _editorStateService.getSelection(entryId),
    );

    controller.changes.listen((Tuple3<Delta, Delta, ChangeSource> event) {
      final delta = deltaFromController(controller);
      _editorStateService.saveTempState(
        id: entryId,
        json: quillJsonFromDelta(delta),
        lastSaved: entry.meta.updatedAt,
      );
      dirty = true;
      emitState();
    });

    _entryStream = _journalDb.watchEntityById(entryId);
    _entryStreamSubscription = _entryStream.listen((updated) {
      if (updated != null) {
        entry = updated;
        emitState();
      }
    });
  }

  String entryId;
  JournalEntity entry;
  bool dirty = false;

  late final QuillController controller;
  late final GlobalKey<FormBuilderState>? formKey;
  late final Stream<JournalEntity?> _entryStream;
  late final StreamSubscription<JournalEntity?> _entryStreamSubscription;
  final FocusNode focusNode = FocusNode();
  final EditorStateService _editorStateService = getIt<EditorStateService>();
  final JournalDb _journalDb = getIt<JournalDb>();
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();

  Future<void> save() async {
    if (entry is Task) {
      final task = entry as Task;
      formKey?.currentState?.save();
      final formData = formKey?.currentState?.value ?? {};
      final title = formData['title'] as String?;
      final dt = formData['estimate'] as DateTime?;
      final status = formData['status'] as String?;

      await _persistenceLogic.updateTask(
        entryText: entryTextFromController(controller),
        journalEntityId: entryId,
        taskData: task.data.copyWith(
          title: title ?? '',
          estimate: Duration(hours: dt?.hour ?? 0, minutes: dt?.minute ?? 0),
          status: taskStatusFromString(status ?? ''),
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
    dirty = false;
    emitState();
    await HapticFeedback.heavyImpact();
  }

  void emitState() {
    if (dirty) {
      emit(EntryState.dirty(entryId: entryId, entry: entry));
    } else {
      emit(EntryState.saved(entryId: entryId, entry: entry));
    }
  }

  void setDirty(dynamic _) {
    dirty = true;
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

  Future<bool> delete() async {
    return _persistenceLogic.deleteJournalEntity(entryId);
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
    await _persistenceLogic.addTags(
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
