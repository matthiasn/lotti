import 'dart:async';

import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/platform.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'entry_controller.g.dart';

@riverpod
class EntryController extends _$EntryController {
  EntryController() {
    listen();

    focusNode.addListener(() {
      _isFocused = focusNode.hasFocus;
      if (_isFocused) {
        _shouldShowEditorToolBar = true;
      }
      emitState();

      if (isDesktop) {
        if (focusNode.hasFocus) {
          hotKeyManager.register(
            saveHotKey,
            keyDownHandler: (hotKey) => save(),
          );
        } else {
          hotKeyManager.unregister(saveHotKey);
        }
      }
    });

    taskTitleFocusNode.addListener(() {
      if (isDesktop) {
        if (taskTitleFocusNode.hasFocus) {
          hotKeyManager.register(
            saveHotKey,
            keyDownHandler: (hotKey) => save(),
          );
        } else {
          hotKeyManager.unregister(saveHotKey);
        }
      }
    });
  }
  late final String entryId;
  QuillController controller = QuillController.basic();
  final _editorStateService = getIt<EditorStateService>();
  final formKey = GlobalKey<FormBuilderState>();

  final FocusNode focusNode = FocusNode();
  final FocusNode taskTitleFocusNode = FocusNode();
  final FocusNode eventTitleFocusNode = FocusNode();

  bool _dirty = false;
  bool _isFocused = false;
  bool _shouldShowEditorToolBar = false;
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();
  StreamSubscription<Set<String>>? _updateSubscription;

  final JournalDb _journalDb = getIt<JournalDb>();
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();

  final saveHotKey = HotKey(
    key: LogicalKeyboardKey.keyS,
    modifiers: [HotKeyModifier.meta],
    scope: HotKeyScope.inapp,
  );

  void listen() {
    _updateSubscription =
        _updateNotifications.updateStream.listen((affectedIds) async {
      if (affectedIds.contains(entryId)) {
        final latest = await _fetch();
        if (latest != state.value?.entry) {
          state = AsyncData(state.value?.copyWith(entry: latest));
        }
      }
    });
  }

  @override
  Future<EntryState?> build({required String id}) async {
    entryId = id;
    ref.onDispose(() => _updateSubscription?.cancel());
    final entry = await _fetch();

    final lastSaved = entry?.meta.updatedAt;

    if (lastSaved != null) {
      _editorStateService
          .getUnsavedStream(entryId, lastSaved)
          .listen((bool dirtyFromEditorDrafts) {
        setDirty(value: dirtyFromEditorDrafts);
      });
    }

    unawaited(Future.microtask(setController));

    return EntryState.saved(
      entryId: id,
      entry: entry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
      formKey: formKey,
    );
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

  Future<bool> updateCategoryId(String? categoryId) async {
    return _persistenceLogic.updateCategoryId(
      entryId,
      categoryId: categoryId,
    );
  }

  Future<JournalEntity?> _fetch() async {
    return _journalDb.journalEntityById(entryId);
  }

  Future<void> save({Duration? estimate}) async {
    final entry = state.value?.entry;
    if (entry == null) {
      return;
    }
    if (entry is Task) {
      final task = entry;
      formKey.currentState?.save();
      final formData = formKey.currentState?.value ?? {};
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
    }
    if (entry is JournalEvent) {
      final event = entry;
      formKey.currentState?.save();
      final formData = formKey.currentState?.value ?? {};
      final title = formData['title'] as String?;
      final status = formData['status'] as EventStatus?;

      await _persistenceLogic.updateEvent(
        entryText: entryTextFromController(controller),
        journalEntityId: entryId,
        data: event.data.copyWith(
          title: title ?? event.data.title,
          status: status ?? event.data.status,
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
    await HapticFeedback.heavyImpact();
  }

  Future<void> updateRating(double stars) async {
    final event = state.value?.entry;
    if (event != null && event is JournalEvent) {
      await _persistenceLogic.updateEvent(
        entryText: entryTextFromController(controller),
        journalEntityId: entryId,
        data: event.data.copyWith(
          stars: stars,
        ),
      );
    }
  }

  Future<bool> delete({
    required bool beamBack,
  }) async {
    final res = await _persistenceLogic.deleteJournalEntity(entryId);
    if (beamBack) {
      getIt<NavService>().beamBack();
    }
    state = const AsyncData(null);
    return res;
  }

  void toggleMapVisible() {
    final current = state.value;
    if (current?.entry?.geolocation != null) {
      state = AsyncData(
        current?.copyWith(
          showMap: !current.showMap,
        ),
      );
    }
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

  void setDirty({required bool value}) {
    _dirty = value;
    emitState();
  }

  void emitState() {
    final entry = state.value?.entry;
    if (entry == null) {
      return;
    }

    if (_dirty) {
      state = AsyncData(
        EntryState.dirty(
          entryId: entryId,
          entry: entry,
          showMap: state.value?.showMap ?? false,
          isFocused: _isFocused,
          shouldShowEditorToolBar: _shouldShowEditorToolBar,
          formKey: formKey,
        ),
      );
    } else {
      state = AsyncData(
        EntryState.saved(
          entryId: entryId,
          entry: entry,
          showMap: state.value?.showMap ?? false,
          isFocused: _isFocused,
          shouldShowEditorToolBar: _shouldShowEditorToolBar,
          formKey: formKey,
        ),
      );
    }
  }

  void focus() {
    focusNode.requestFocus();
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

  void setController() {
    final entry = state.value?.entry;

    if (entry == null) {
      return;
    }

    final serializedQuill =
        _editorStateService.getDelta(entryId) ?? entry.entryText?.quill;
    final markdown =
        entry.entryText?.markdown ?? entry.entryText?.plainText ?? '';
    final quill = serializedQuill ?? markdownToDelta(markdown);
    controller.dispose();

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
}
