import 'dart:async';
import 'dart:io';

import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_tools.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/features/tags/repository/tags_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:super_clipboard/super_clipboard.dart';

part 'entry_controller.g.dart';

@riverpod
class EntryController extends _$EntryController {
  void focusNodeListener() {
    if (focusNode.hasFocus == _isFocused) {
      return;
    }

    _isFocused = focusNode.hasFocus;
    if (_isFocused) {
      _shouldShowEditorToolBar = true;
    } else {
      if (!_dirty) {
        _shouldShowEditorToolBar = false;
      }
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
  }

  void taskTitleFocusNodeListener() {
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
  }

  QuillController controller = QuillController.basic();
  final _editorStateService = getIt<EditorStateService>();
  final formKey = GlobalKey<FormBuilderState>();

  final FocusNode focusNode = FocusNode();
  final FocusNode taskTitleFocusNode = FocusNode();
  final FocusNode eventTitleFocusNode = FocusNode();
  bool animationCompleted = false;

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
    focusNode.addListener(focusNodeListener);
    taskTitleFocusNode.addListener(taskTitleFocusNodeListener);

    _updateSubscription =
        _updateNotifications.updateStream.listen((affectedIds) async {
      if (affectedIds.contains(id)) {
        final latest = await _fetch();
        if (latest != state.value?.entry) {
          state = AsyncData(state.value?.copyWith(entry: latest));
          if (!_dirty && !_editorStateService.entryIsUnsaved(id)) {
            setController();
          }
        }
      }
    });
  }

  @override
  Future<EntryState?> build({required String id}) async {
    ref
      ..onDispose(() {
        _updateSubscription?.cancel();
      })
      ..onDispose(() {
        focusNode.removeListener(focusNodeListener);
      })
      ..onDispose(() {
        taskTitleFocusNode.removeListener(taskTitleFocusNodeListener);
      })
      ..cacheFor(entryCacheDuration);

    final entry = await _fetch();

    final lastSaved = entry?.meta.updatedAt;

    if (lastSaved != null) {
      _editorStateService
          .getUnsavedStream(id, lastSaved)
          .listen((bool dirtyFromEditorDrafts) {
        setDirty(value: dirtyFromEditorDrafts);
      });
    }
    listen();

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
    return ref.read(journalRepositoryProvider).updateJournalEntityDate(
          id,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );
  }

  Future<bool> updateCategoryId(String? categoryId) async {
    final res = await ref
        .read(journalRepositoryProvider)
        .updateCategoryId(id, categoryId: categoryId);

    final linkedEntries = await ref
        .read(journalRepositoryProvider)
        .getLinkedEntities(linkedTo: id);

    for (final entry in linkedEntries) {
      if (entry.categoryId == null) {
        await ref
            .read(journalRepositoryProvider)
            .updateCategoryId(entry.id, categoryId: categoryId);
      }
    }
    return res;
  }

  Future<JournalEntity?> _fetch() async {
    return _journalDb.journalEntityById(id);
  }

  Future<void> save({
    Duration? estimate,
    String? title,
    bool stopRecording = false,
  }) async {
    final entry = state.value?.entry;
    if (entry == null) {
      return;
    }
    if (entry is Task) {
      final task = entry;
      await _persistenceLogic.updateTask(
        entryText: entryTextFromController(controller),
        journalEntityId: id,
        taskData: task.data.copyWith(
          title: title ?? task.data.title,
          estimate: estimate ?? task.data.estimate,
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
        journalEntityId: id,
        data: event.data.copyWith(
          title: title ?? event.data.title,
          status: status ?? event.data.status,
        ),
      );
    } else {
      final running = getIt<TimeService>().getCurrent();

      await _persistenceLogic.updateJournalEntityText(
        id,
        entryTextFromController(controller),
        running?.id == id ? DateTime.now() : entry.meta.dateTo,
      );

      if (stopRecording) {
        await Future<void>.delayed(const Duration(milliseconds: 100)).then((_) {
          getIt<TimeService>().stop();
        });
      }

      _shouldShowEditorToolBar = false;
      focusNode.unfocus();
      emitState();
    }

    await _editorStateService.entryWasSaved(
      id: id,
      lastSaved: entry.meta.updatedAt,
      controller: controller,
    );
    setDirty(value: false);
    await HapticFeedback.heavyImpact();
  }

  Future<void> updateTaskStatus(String? status) async {
    final task = state.value?.entry;

    if (task is Task &&
        status != null &&
        status != task.data.status.toDbString) {
      await _persistenceLogic.updateTask(
        journalEntityId: id,
        taskData: task.data.copyWith(
          status: taskStatusFromString(status),
        ),
      );

      await HapticFeedback.heavyImpact();
    }
  }

  Future<void> updateRating(double stars) async {
    final event = state.value?.entry;
    if (event != null && event is JournalEvent) {
      await _persistenceLogic.updateEvent(
        entryText: entryTextFromController(controller),
        journalEntityId: id,
        data: event.data.copyWith(
          stars: stars,
        ),
      );
    }
  }

  Future<bool> delete({
    required bool beamBack,
  }) async {
    final res =
        await ref.read(journalRepositoryProvider).deleteJournalEntity(id);
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

  // ignore: avoid_positional_boolean_parameters
  void setMapVisible(bool value) {
    final current = state.value;
    if (current?.entry?.geolocation != null) {
      state = AsyncData(
        current?.copyWith(
          showMap: value,
        ),
      );
    }
  }

  Future<void> toggleStarred() async {
    final item = await _journalDb.journalEntityById(id);
    if (item != null) {
      final prev = item.meta.starred ?? false;
      await _persistenceLogic.updateJournalEntity(
        item,
        item.meta.copyWith(starred: !prev),
      );
    }
  }

  // ignore: avoid_positional_boolean_parameters
  Future<void> setStarred(bool value) async {
    final item = await _journalDb.journalEntityById(id);
    if (item != null) {
      await _persistenceLogic.updateJournalEntity(
        item,
        item.meta.copyWith(starred: value),
      );
    }
  }

  Future<void> togglePrivate() async {
    final item = await _journalDb.journalEntityById(id);
    if (item != null) {
      final prev = item.meta.private ?? false;
      await _persistenceLogic.updateJournalEntity(
        item,
        item.meta.copyWith(private: !prev),
      );
    }
  }

  // ignore: avoid_positional_boolean_parameters
  Future<void> setPrivate(bool value) async {
    final item = await _journalDb.journalEntityById(id);
    if (item != null) {
      await _persistenceLogic.updateJournalEntity(
        item,
        item.meta.copyWith(private: value),
      );
    }
  }

  void setDirty({required bool value, bool requestFocus = true}) {
    if (_dirty == value) {
      return;
    }
    _dirty = value;
    if (value && requestFocus) {
      focusNode.requestFocus();
    }
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
          entryId: id,
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
          entryId: id,
          entry: entry,
          showMap: state.value?.showMap ?? false,
          isFocused: _isFocused,
          shouldShowEditorToolBar: _shouldShowEditorToolBar,
          formKey: formKey,
        ),
      );
    }
  }

  Future<void> toggleFlagged() async {
    final item = await _journalDb.journalEntityById(id);
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

  // ignore: avoid_positional_boolean_parameters
  Future<void> setFlagged(bool value) async {
    final item = await _journalDb.journalEntityById(id);
    if (item != null) {
      await _persistenceLogic.updateJournalEntity(
        item,
        item.meta.copyWith(flag: value ? EntryFlag.import : EntryFlag.none),
      );
    }
  }

  void setController() {
    final entry = state.value?.entry;

    if (entry == null) {
      return;
    }

    final serializedQuill =
        _editorStateService.getDelta(id) ?? entry.entryText?.quill;
    final markdown =
        entry.entryText?.markdown ?? entry.entryText?.plainText ?? '';
    final quill = serializedQuill ?? markdownToDelta(markdown);
    controller.dispose();

    controller = makeController(
      serializedQuill: quill,
      selection: _editorStateService.getSelection(id),
    );

    controller.changes.listen((DocChange event) {
      final delta = deltaFromController(controller);
      _editorStateService.saveTempState(
        id: id,
        json: quillJsonFromDelta(delta),
        lastSaved: entry.meta.updatedAt,
      );
      setDirty(value: true);
    });
  }

  Future<String> addTagDefinition(String tag) async {
    return TagsRepository.addTagDefinition(tag);
  }

  Future<void> setLanguage(String language) async {
    return SpeechRepository.updateLanguage(
      journalEntityId: id,
      language: language,
    );
  }

  Future<void> addTagIds(List<String> addedTagIds) async {
    await TagsRepository.addTagsWithLinked(
      journalEntityId: id,
      addedTagIds: addedTagIds,
    );
  }

  Future<void> removeTagId(String tagId) async {
    await TagsRepository.removeTag(
      journalEntityId: id,
      tagId: tagId,
    );
  }

  Future<void> copyImage() async {
    final entry = state.value?.entry;

    if (entry is JournalImage) {
      final fullPath = getFullImagePath(entry);

      final clipboard = SystemClipboard.instance;

      if (clipboard == null) {
        return;
      }

      final item = DataWriterItem();
      final imageData = await File(fullPath).readAsBytes();
      item.add(Formats.png(imageData));
      await clipboard.write([item]);
    }
  }

  Future<void> addTextToImage(String text) async {
    final journalImage = state.value?.entry;
    if (journalImage is JournalImage) {
      final originalText = journalImage.entryText?.markdown ??
          journalImage.entryText?.markdown ??
          '';
      final amendedText = '$originalText\n\n$text';

      final quill = markdownToDelta(amendedText);
      final controller = makeController(serializedQuill: quill)
        ..readOnly = true;

      final updatedEntryText = EntryText(
        plainText: controller.document.toPlainText(),
        markdown: amendedText,
        quill: quill,
      );

      await _persistenceLogic.updateJournalEntityText(
        id,
        updatedEntryText,
        journalImage.meta.dateFrom,
      );
    }
  }

  Future<void> addTextToAudio({required AudioTranscript transcript}) async {
    final journalAudio = state.value?.entry;
    if (journalAudio is JournalAudio) {
      await SpeechRepository.addAudioTranscript(
        journalEntityId: id,
        transcript: transcript,
      );
    }
  }

  Future<void> updateChecklistOrder(List<String> checklistIds) async {
    final task = state.value?.entry;

    if (task != null && task is Task) {
      final checklists =
          await _journalDb.getJournalEntitiesForIds({...checklistIds});

      final existingIds = checklists
          .where((item) => !item.isDeleted)
          .map((item) => item.meta.id)
          .toSet();

      final filtered = checklistIds.where(existingIds.contains).toList();

      await _persistenceLogic.updateTask(
        entryText: entryTextFromController(controller),
        journalEntityId: id,
        taskData: task.data.copyWith(
          checklistIds: filtered,
        ),
      );
    }
  }
}
