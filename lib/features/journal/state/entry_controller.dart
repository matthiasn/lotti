import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart' hide ChangeSource;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/change_source.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/membership_list.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/agents/agent_database.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/state/ai_config_initialization.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/repository/app_clipboard_service.dart';
import 'package:lotti/features/journal/repository/clipboard_images.dart';
import 'package:lotti/features/journal/repository/clipboard_repository.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/checklist_repository.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/logic/repositories/speech_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// Delay before stopping the time service after save.
/// Overridable in tests to avoid real delays.
@visibleForTesting
Duration stopRecordingDelay = const Duration(milliseconds: 100);

/// The detail-side controller for a single journal entry, keyed by entry id.
///
/// Owns the entry's load/draft/save lifecycle (the two-state `EntryState`
/// machine), editor focus/toolbar state, and the entity mutations exposed to
/// the detail UI — status/priority, cover art, language, and text copy. Saves
/// follow the dual-write path (persist the entity, then propagate metadata such
/// as category to linked entries). See the feature README for the full
/// save/refresh flow.
final AsyncNotifierProviderFamily<EntryController, EntryState?, String>
entryControllerProvider = AsyncNotifierProvider.autoDispose
    .family<EntryController, EntryState?, String>(
      EntryController.new,
      name: 'entryControllerProvider',
    );

class EntryController extends AsyncNotifier<EntryState?> {
  EntryController([this.id = '']);

  final String id;

  void focusNodeListener() {
    if (focusNode.hasFocus == _isFocused) {
      return;
    }

    _isFocused = focusNode.hasFocus;
    if (_isFocused) {
      _shouldShowEditorToolBar = true;
    }
    emitState();
  }

  QuillController controller = QuillController.basic();
  final EditorStateService _editorStateService = getIt<EditorStateService>();
  final formKey = GlobalKey<FormBuilderState>();

  final FocusNode focusNode = FocusNode();
  bool animationCompleted = false;

  bool _dirty = false;

  /// The entry version (`updatedAt`) the editor's content is based on, and so
  /// the key its drafts are written under. Set when [controller] is built,
  /// and advanced by a write that leaves the stored text alone.
  DateTime? _draftBase;
  bool _isFocused = false;
  bool _shouldShowEditorToolBar = false;
  PersistenceLogic get _persistenceLogic => ref.read(persistenceLogicProvider);
  StreamSubscription<Set<String>>? _updateSubscription;

  JournalDb get _journalDb => ref.read(journalDbProvider);
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();

  void listen() {
    focusNode.addListener(focusNodeListener);

    _updateSubscription = _updateNotifications.updateStream.listen((
      affectedIds,
    ) async {
      if (affectedIds.contains(id)) {
        final latest = await _fetch();
        final previous = state.value?.entry;
        if (latest != previous) {
          state = AsyncData(state.value?.copyWith(entry: latest));
          if (latest?.entryText != previous?.entryText &&
              !_editorShows(latest)) {
            if (!_dirty && !_editorStateService.entryIsUnsaved(id)) {
              setController();
            }
          } else if (latest != null) {
            await _rebaseEditorOnto(
              from: previous?.meta.updatedAt,
              to: latest.meta.updatedAt,
            );
          }
        }
      }
    });
  }

  /// The entry version drafts of this editor are keyed to: the version its
  /// held draft is on — which an autosave that stored an earlier draft moves
  /// on without the editor — or else the later of [_draftBase] and the
  /// version the autosave last stored the draft as. The latter covers what is
  /// typed after that write but before its update notification advanced
  /// [_draftBase]; [_draftBase] wins once the entry has moved on since.
  DateTime? get _draftKey {
    final held = _editorStateService.draftVersion(id);
    if (held != null) {
      return held;
    }
    final storedAs = _editorStateService.storedDraftVersion(id);
    final base = _draftBase;
    if (storedAs == null) return base;
    if (base == null) return storedAs;
    return storedAs.isAfter(base) ? storedAs : base;
  }

  /// Whether the editor already shows the text of [entry] — as it does after
  /// the running timer's autosave stored the draft typed in it.
  bool _editorShows(JournalEntity? entry) =>
      entry?.entryText?.quill ==
      quillJsonFromDelta(deltaFromController(controller));

  /// Follows a write that left the editor's text as it is — such as the
  /// running timer's periodic autosave of its end time and of the draft
  /// typed in the editor. The editor keeps its
  /// controller, so an open editor's cursor does not jump, and an unsaved
  /// draft moves onto the new version so it is still restored after a
  /// restart.
  ///
  /// The draft follows only a write that replaced the version the editor is
  /// based on ([from]). A draft typed against text that sync has replaced
  /// since stays on the version it was typed against — moved onto a later
  /// version, the running timer's autosave would write it over the synced
  /// text.
  ///
  /// The draft is moved whether or not [EditorStateService] holds it in
  /// memory yet: a draft restored from `EditorDb` is loaded asynchronously,
  /// and the move is a no-op when there is no draft on [_draftBase].
  Future<void> _rebaseEditorOnto({
    required DateTime? from,
    required DateTime to,
  }) async {
    final base = _draftBase;
    if (base == null || base == to || base != from) {
      return;
    }
    _draftBase = to;
    await _editorStateService.rebaseDraft(
      id: id,
      from: base,
      to: to,
    );
  }

  @override
  Future<EntryState?> build() async {
    // Eagerly initialize the agent infrastructure when any entry is viewed.
    // The provider itself checks the config flag and is a no-op when disabled.
    // Use listen (not watch) to avoid rebuilding this controller when the
    // initialization provider resolves.
    ref
      ..listen(agentInitializationProvider, (_, _) {})
      ..listen(aiConfigInitializationProvider, (_, _) {})
      ..onDispose(() {
        _updateSubscription?.cancel();
      })
      ..onDispose(() {
        focusNode.removeListener(focusNodeListener);
      })
      ..cacheFor(entryCacheDuration);

    final entry = await _fetch();

    final lastSaved = entry?.meta.updatedAt;

    if (lastSaved != null) {
      _editorStateService.getUnsavedStream(id, lastSaved).listen((
        bool dirtyFromEditorDrafts,
      ) {
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
    return ref
        .read(journalRepositoryProvider)
        .updateJournalEntityDate(
          id,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );
  }

  /// Sets this entry's category and propagates it to every entry linked from
  /// this one, so a task and its linked timer/audio/image entries stay in the
  /// same category. Pass null to clear the category.
  ///
  /// A task's project membership is scoped to its category
  /// (`ProjectRepository.linkTaskToProject` refuses a cross-category link), so
  /// every task this call moves — this entry and any linked task it propagated
  /// to — also gives up a project that is no longer in its category. See
  /// [_dropCrossCategoryProjectLinks].
  Future<bool> updateCategoryId(String? categoryId) async {
    final res = await ref
        .read(journalRepositoryProvider)
        .updateCategoryId(id, categoryId: categoryId);

    final linkedEntries = await ref
        .read(journalRepositoryProvider)
        .getLinkedEntities(linkedTo: id);

    // Only entries whose category write actually landed are swept below. A
    // failed write means the entity was not found — deleted since
    // `getLinkedEntities` read it, or never there — and such an entry keeps
    // the category it had, so its project is still the right one for it.
    final moved = <JournalEntity>[];
    for (final entry in linkedEntries) {
      final updated = await ref
          .read(journalRepositoryProvider)
          .updateCategoryId(entry.id, categoryId: categoryId);
      if (updated) moved.add(entry);
    }

    await _dropCrossCategoryProjectLinks(
      categoryId,
      propagatedTo: moved,
      includeThisEntry: res,
    );
    return res;
  }

  /// Unlinks every task this call just moved from a project that is no longer
  /// in [categoryId].
  ///
  /// The same-category rule is enforced when the link is *created* but nothing
  /// re-checked it afterwards, so moving a task from the category holding its
  /// project into another one left the stale membership in place — the task
  /// then read as belonging to a project from a category it is not in, and the
  /// header kept rendering that project.
  ///
  /// **[propagatedTo] is covered as well as this entry.** The loop above
  /// rewrites the category of everything linked *from* here, and
  /// [JournalRepository.getLinkedEntities] is not filtered by link type — a
  /// linked task is re-categorized right along with the timers and images the
  /// propagation is aimed at, and would otherwise keep a project from the
  /// category it just left. A `ProjectLink` runs project → task, so a task's
  /// own project is never in that list and cannot be re-categorized by it.
  ///
  /// Comparing against the project's category rather than the task's previous
  /// one makes a no-op re-pick of the same category keep the project: the
  /// categories still match, so there is nothing to drop. That is a comparison,
  /// not a null check — clearing the category drops a project that *has* one,
  /// and keeps an uncategorized project, which is exactly the pairing
  /// `linkTaskToProject` would still accept.
  ///
  /// The lookup goes through [ProjectRepository.getLinkedProjectForTask] rather
  /// than the privacy-filtered `getProjectForTask`: a private project resolves
  /// to null there while private entries are hidden, and reading that as "no
  /// link" would skip the stale row and let it reappear once they are shown.
  ///
  /// Failure is logged and swallowed, like every other step of
  /// [updateCategoryId] — the category write has already committed by now, and
  /// an unhandled error from a fire-and-forget picker callback would not undo
  /// it. One guard covers the whole sweep: what makes these reads fail is the
  /// database being unavailable, which the next task in the list would hit too.
  Future<void> _dropCrossCategoryProjectLinks(
    String? categoryId, {
    required List<JournalEntity> propagatedTo,
    required bool includeThisEntry,
  }) async {
    try {
      final self = includeThisEntry
          ? state.value?.entry ?? await _fetch()
          : null;
      final moved = <JournalEntity>[?self, ...propagatedTo].whereType<Task>();
      if (moved.isEmpty) return;

      final repository = ref.read(projectRepositoryProvider);
      for (final task in moved) {
        final project = await repository.getLinkedProjectForTask(task.id);
        if (project == null || project.meta.categoryId == categoryId) continue;
        await repository.unlinkTaskFromProject(task.id);
      }
    } catch (e, stackTrace) {
      developer.log(
        'Failed to drop cross-category project links for entry $id: $e',
        name: 'EntryController',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<JournalEntity?> _fetch() async {
    return _journalDb.journalEntityById(id);
  }

  /// Persists the current draft for this entry, branching on entity type:
  /// tasks save through `updateTask` (title/estimate/due plus editor text),
  /// events read their title/status from the form-builder state, and all other
  /// types save the editor text — stamping `dateTo` to now when this entry is
  /// the running timer. Regardless of type it then drops focus, hides the
  /// toolbar, clears the dirty flag, and notifies the editor-state service.
  ///
  /// When `stopRecording` is true the running time service is stopped after
  /// [stopRecordingDelay] (used by the timer stop button).
  Future<void> save({
    Duration? estimate,
    String? title,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool stopRecording = false,
  }) async {
    final entry = state.value?.entry;
    if (entry == null) {
      return;
    }
    if (entry is Task) {
      final task = entry;
      final titleChanged =
          title != null && title.trim() != task.data.title.trim();

      // Only what this save sets is written, on the task as stored: a field
      // the screen's copy predates — set by sync or the agent since — is
      // kept (specs/tla/TaskFieldWrites.tla). The body is written only when
      // the editor holds unsaved edits; otherwise the editor shows the
      // stored text, or is about to.
      await _persistenceLogic.updateTask(
        entryText: _dirty || _editorStateService.entryIsUnsaved(id)
            ? entryTextFromController(controller)
            : null,
        journalEntityId: id,
        change: (stored) => stored.copyWith(
          title: titleChanged ? title : stored.title,
          estimate: estimate ?? stored.estimate,
          due: clearDueDate ? null : (dueDate ?? stored.due),
        ),
      );
      if (titleChanged) {
        await _syncDailyOsTaskTitle(task.id, title);
      }
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
      final timeService = ref.read(timeServiceProvider);
      final running = timeService.getCurrent();
      // Captured before the stop clears it: the task this timer ran for.
      final timedTask = stopRecording && running?.id == id
          ? timeService.linkedFrom
          : null;

      final entryText = entryTextFromController(controller);
      await _persistenceLogic.updateJournalEntityText(
        id,
        entryText,
        running?.id == id ? DateTime.now() : entry.meta.dateTo,
      );

      // A finished stretch of work: the task's agent takes its pending
      // changes now rather than at its next scheduled update.
      if (timedTask is Task) {
        _updateNotifications.notify({wakeFlushNotification(timedTask.id)});
      }

      if (stopRecording) {
        await Future<void>.delayed(stopRecordingDelay).then((_) {
          timeService.stop();
        });
      }
    }

    // Finalize for every entry type (events included): drop focus, hide the
    // editor toolbar, and clear the dirty flag so the UI reflects the save.
    focusNode.unfocus();

    _shouldShowEditorToolBar = false;
    _dirty = false;

    emitState();

    await _editorStateService.entryWasSaved(
      id: id,
      lastSaved: _draftKey ?? entry.meta.updatedAt,
      controller: controller,
    );
    await HapticFeedback.heavyImpact();
  }

  Future<void> _syncDailyOsTaskTitle(String taskId, String title) async {
    if (!getIt.isRegistered<AgentDatabase>()) {
      return;
    }
    try {
      await ref
          .read(dayAgentPlanServiceProvider)
          .syncTaskTitle(taskId: taskId, title: title);
    } catch (e, stackTrace) {
      developer.log(
        'Failed to sync Daily OS planned block title for task $taskId: $e',
        name: 'EntryController',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Discards unsaved edits: the inverse of [save] without persisting anything.
  ///
  /// Drops the in-memory and persisted draft, rebuilds the editor [controller]
  /// from the last saved entry text, drops focus, hides the toolbar and clears
  /// the dirty flag — so the editor returns to exactly the saved state.
  Future<void> discard() async {
    final entry = state.value?.entry;
    if (entry == null) {
      return;
    }

    await _editorStateService.dropDraft(
      id: id,
      lastSaved: _draftKey ?? entry.meta.updatedAt,
    );
    // Rebuild from the saved text: with the draft gone, setController falls back
    // to entry.entryText, reverting any unsaved edits.
    setController();

    focusNode.unfocus();
    _shouldShowEditorToolBar = false;
    _dirty = false;
    emitState();
  }

  /// Sets the task's status and, independently, optionally links a blocking
  /// task (ADR 0042 §4 status-enrichment: the manual `blocked` status stays
  /// user-owned; naming a blocker is offered, never required, and never
  /// gates or rolls back the status write).
  ///
  /// The two writes are deliberately decoupled: [blockerTaskId] is applied
  /// (or attempted) even when the status write is a no-op (e.g. the task is
  /// already Blocked and the user just wants to add another blocker), and a
  /// rejected blocker link (the cycle guard firing) never prevents the
  /// status from being set.
  Future<void> updateTaskStatus(
    String? status, {
    String? blockerTaskId,
    String? blockerTaskTitle,
  }) async {
    final task = state.value?.entry;
    if (task is Task &&
        status != null &&
        status != task.data.status.toDbString) {
      final newStatus =
          status == 'BLOCKED' &&
              blockerTaskTitle != null &&
              blockerTaskTitle.isNotEmpty
          ? TaskStatus.blocked(
              id: uuid.v1(),
              createdAt: DateTime.now(),
              utcOffset: DateTime.now().timeZoneOffset.inMinutes,
              // No BuildContext here — resolve the platform locale directly,
              // same pattern as change_set_builder.dart's notification copy.
              reason: lookupAppLocalizations(
                ui.PlatformDispatcher.instance.locale,
              ).taskBlockedReason(blockerTaskTitle),
            )
          : taskStatusFromString(status);

      await _persistenceLogic.updateTask(
        journalEntityId: id,
        change: (stored) => stored.withStatus(newStatus),
      );

      await HapticFeedback.heavyImpact();
    }

    if (task is Task && blockerTaskId != null && blockerTaskId != id) {
      await _persistenceLogic.createLink(
        fromId: blockerTaskId,
        toId: id,
        linkType: EntryLinkType.blocks,
      );
    }
  }

  Future<void> updateTaskPriority(String code) async {
    final entry = state.value?.entry;
    if (entry is! Task) return;

    final next = taskPriorityFromString(code);
    if (entry.data.priority == next) return;

    // Optimistically update local state for immediate UI feedback
    final optimistic = entry.copyWith(
      data: entry.data.copyWith(priority: next),
    );
    state = AsyncData(state.value?.copyWith(entry: optimistic));

    // Persist change
    final _ = await _persistenceLogic.updateTask(
      journalEntityId: id,
      change: (stored) => stored.copyWith(priority: next),
    );

    // Haptic feedback
    await HapticFeedback.heavyImpact();
  }

  /// Sets the task's transcription language to `languageCode` and marks the
  /// source as `ChangeSource.user`, so the explicit choice overrides any
  /// category/default-derived language. No-ops only when the same code is
  /// already set *and* already user-sourced.
  Future<void> updateTaskLanguage(String? languageCode) async {
    final entry = state.value?.entry;
    if (entry is! Task) return;

    // Only no-op when both the code and the source are already user-set.
    // Re-selecting the same code that currently comes from a category/default
    // source must still be persisted so the user choice overrides the default.
    if (entry.data.languageCode == languageCode &&
        entry.data.languageSource == ChangeSource.user) {
      return;
    }

    final optimistic = entry.copyWith(
      data: entry.data.copyWith(
        languageCode: languageCode,
        languageSource: ChangeSource.user,
      ),
    );
    state = AsyncData(state.value?.copyWith(entry: optimistic));

    final _ = await _persistenceLogic.updateTask(
      journalEntityId: id,
      change: (stored) => stored.copyWith(
        languageCode: languageCode,
        languageSource: ChangeSource.user,
      ),
    );
  }

  /// Applies a single-field edit to an event's [EventData] with optimistic local
  /// state, persistence, and haptic feedback. No-ops (reporting true) for
  /// non-events or no change.
  ///
  /// Returns what the persistence layer reports: `false` when it rejects the
  /// write (the entity is gone), in which case the optimistic state is rolled
  /// back so the page does not keep showing an edit that was not stored, and
  /// no haptic plays. A storage exception inside `updateEvent` is logged there
  /// and — by that layer's documented contract — reported as `true`, so it is
  /// not something this method can roll back.
  Future<bool> _updateEventData(
    EventData Function(EventData data) mutate, {
    Future<void> Function() haptic = HapticFeedback.selectionClick,
  }) async {
    final previous = state.value;
    final event = previous?.entry;
    if (event is! JournalEvent) return true;
    final next = mutate(event.data);
    if (next == event.data) return true;
    state = AsyncData(previous?.copyWith(entry: event.copyWith(data: next)));
    final stored = await _persistenceLogic.updateEvent(
      entryText: entryTextFromController(controller),
      journalEntityId: id,
      data: next,
    );
    if (!stored) {
      state = AsyncData(previous);
      return false;
    }
    await haptic();
    return true;
  }

  /// Sets an event's star rating.
  Future<bool> updateRating(double stars) =>
      _updateEventData((data) => data.copyWith(stars: stars));

  /// Renames an event inline.
  Future<bool> updateEventTitle(String title) =>
      _updateEventData((data) => data.copyWith(title: title.trim()));

  /// Sets an event's [EventStatus] inline.
  Future<bool> updateEventStatus(EventStatus status) => _updateEventData(
    (data) => data.copyWith(status: status),
    haptic: HapticFeedback.heavyImpact,
  );

  /// Sets the event's cover photo to [imageId] (a linked [JournalImage]),
  /// optionally repositioning the horizontal crop. Passing null clears the
  /// explicit cover so it falls back to the newest linked photo.
  /// Sets (or clears) the event's cover photo and its horizontal crop. The
  /// result is the persistence layer's, see [_updateEventData]; the gallery
  /// viewer takes its optimistic "Cover" state back on `false`.
  Future<bool> updateEventCover(String? imageId, {double? cropX}) =>
      _updateEventData(
        (data) => data.copyWith(
          coverArtId: imageId,
          // coverArtCropX is a normalized 0..1 horizontal offset; clamp so a
          // malformed value can't persist an out-of-range crop.
          coverArtCropX: cropX?.clamp(0.0, 1.0) ?? data.coverArtCropX,
        ),
      );

  Future<bool> delete({
    required bool beamBack,
  }) async {
    // Read before the delete: removing the entry can dispose this controller.
    final navService = ref.read(navServiceProvider);
    final res = await ref
        .read(journalRepositoryProvider)
        .deleteJournalEntity(id);
    // Not deleted: the entry is still there, and so is its page.
    if (!res) return false;
    if (beamBack) {
      navService.beamBack();
    }
    state = const AsyncData(null);
    return true;
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

  /// The toggles change only their own flag, on the entry as stored
  /// (`PersistenceLogic.updateEntity`): a field set since — a task's status
  /// by its agent, a checklist listed on it — is kept, not written back from
  /// a copy (`specs/tla/TaskFieldWrites.tla`, MetaOnStored).
  Future<void> toggleStarred() async {
    await _persistenceLogic.updateEntity(
      id,
      (stored) => stored.copyWith(
        meta: stored.meta.copyWith(starred: !(stored.meta.starred ?? false)),
      ),
    );
  }

  Future<void> togglePrivate() async {
    var isTask = false;
    final updated = await _persistenceLogic.updateEntity(id, (stored) {
      isTask = stored is Task;
      return stored.copyWith(
        meta: stored.meta.copyWith(private: !(stored.meta.private ?? false)),
      );
    });
    if (updated && isTask) {
      await _dropPrivacyMismatchedProjectLink(id);
    }
  }

  /// Removes an incompatible membership after a successful privacy toggle.
  /// The repository rechecks the current task, project, and link atomically.
  Future<void> _dropPrivacyMismatchedProjectLink(String taskId) async {
    try {
      await ref
          .read(projectRepositoryProvider)
          .unlinkTaskFromProject(
            taskId,
            onlyIfPrivacyMismatched: true,
          );
    } catch (e, stackTrace) {
      developer.log(
        'Failed to drop privacy-incompatible project link for entry $id: $e',
        name: 'EntryController',
        error: e,
        stackTrace: stackTrace,
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
    await _persistenceLogic.updateEntity(
      id,
      (stored) => stored.copyWith(
        meta: stored.meta.copyWith(
          // Cleared by writing `none`, never by writing null — see
          // [MetadataFlag.isFlagged], which is what every reader asks.
          flag: stored.meta.isFlagged ? EntryFlag.none : EntryFlag.import,
        ),
      ),
    );
  }

  /// (Re)builds the Quill editor [controller] from the best available source:
  /// an unsaved draft from the editor-state service, else the saved
  /// `entryText.quill`, else markdown converted to a Quill delta. Disposes the
  /// previous controller and wires a change listener that saves temp drafts —
  /// keyed to the entry version the editor is based on — and marks the entry
  /// dirty on every edit.
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
      markdownPasteEnabled: true,
    );
    _draftBase = entry.meta.updatedAt;

    controller.changes.listen((DocChange event) {
      final delta = deltaFromController(controller);
      _editorStateService.saveTempState(
        id: id,
        json: quillJsonFromDelta(delta),
        lastSaved: _draftKey ?? entry.meta.updatedAt,
      );
      setDirty(value: true);
    });
  }

  Future<void> setLanguage(String language) async {
    return SpeechRepository.updateLanguage(
      journalEntityId: id,
      language: language,
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

  Future<void> copyEntryTextPlain() async {
    final plain = controller.document.toPlainText();
    if (plain.trim().isEmpty) return;
    await ref.read(appClipboardProvider).writePlainText(plain);
  }

  Future<void> copyEntryTextMarkdown() async {
    final entryText = entryTextFromController(controller);
    final md = (entryText.markdown ?? entryText.plainText).trim();
    if (md.isEmpty) return;
    await ref.read(appClipboardProvider).writePlainText(md);
  }

  /// Persists the order [visibleOrder] shows a task's checklists in, applied
  /// to the task's stored list ([inVisibleOrder]) so a checklist added since
  /// the page last read the task keeps its place. Ids of the shown order that
  /// no longer resolve to a non-deleted entry are pruned on save.
  Future<void> updateChecklistOrder(List<String> visibleOrder) async {
    final task = state.value?.entry;

    if (task != null && task is Task) {
      final checklists = await _journalDb.getJournalEntitiesForIdsUnordered({
        ...visibleOrder,
      });

      final existingIds = checklists
          .where((item) => !item.isDeleted)
          .map((item) => item.meta.id)
          .toSet();
      final gone = visibleOrder.where((id) => !existingIds.contains(id));

      await ref
          .read(checklistRepositoryProvider)
          .updateTaskChecklistIds(
            taskId: id,
            change: (stored) => gone.fold(
              inVisibleOrder(stored, visibleOrder),
              withoutMember,
            ),
          );
    }
  }

  /// Makes the clipboard's image this task's cover art. The picture is
  /// imported as an image entry linked to the task — collapsed, since the
  /// cover already shows it — in the task's category.
  ///
  /// Returns whether a cover was set: false when this is not a task, the
  /// clipboard holds no image, the import or the read fails, or the task
  /// could not be written. A picture this paste created is taken back out
  /// when the cover could not be set, so a failed paste leaves nothing behind.
  Future<bool> pasteCoverArt() async {
    final entry = state.value?.entry;
    if (entry is! Task) return false;
    ImportedImage? imported;
    try {
      imported = await importFirstClipboardImage(
        ref.read(clipboardRepositoryProvider),
        linkedId: id,
        categoryId: entry.meta.categoryId,
        linkCollapsed: true,
      );
      if (imported == null) return false;
      if (await setCoverArt(imported.id)) return true;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to paste cover art',
        name: 'EntryController',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (imported != null && imported.created) {
      await ref
          .read(journalRepositoryProvider)
          .deleteJournalEntity(
            imported.id,
          );
    }
    return false;
  }

  /// Sets or removes the cover art for a task.
  /// Pass null to remove the cover art.
  ///
  /// Returns whether the task was written. A refused write — the task gone
  /// by the time it is saved — puts the previous cover back on screen.
  Future<bool> setCoverArt(String? imageId) async {
    final entry = state.value?.entry;
    if (entry is! Task) return false;

    // Optimistically update local state for immediate UI feedback
    final optimistic = entry.copyWith(
      data: entry.data.copyWith(coverArtId: imageId),
    );
    state = AsyncData(state.value?.copyWith(entry: optimistic));

    // Persist change
    final written = await _persistenceLogic.updateTask(
      journalEntityId: id,
      change: (stored) => stored.copyWith(coverArtId: imageId),
    );
    if (written == null) {
      state = AsyncData(state.value?.copyWith(entry: entry));
      return false;
    }

    await HapticFeedback.selectionClick();
    return true;
  }
}
