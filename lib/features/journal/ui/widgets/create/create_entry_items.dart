import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/image_paste_controller.dart';
import 'package:lotti/features/journal/state/journal_focus_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_menu_list_item.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/logic/create/entry_creation_service.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart';

// Constants for timer auto-scroll polling behavior
const _kTimerScrollPollInterval = Duration(milliseconds: 100);
const _kTimerScrollMaxAttempts = 30;
const _kTimerScrollInitialDelay = Duration(milliseconds: 200);

/// Create-menu item that creates an event linked to `linkedFromId`. The
/// `enableEvents` config-flag gate lives in the menu list, which resolves all
/// visibility before assembling rows. On success, navigates to the new
/// event's detail page.
class CreateEventItem extends ConsumerWidget {
  const CreateEventItem(
    this.linkedFromId, {
    this.categoryId,
    super.key,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CreateMenuListItem(
      icon: Icons.event_rounded,
      title: context.messages.addActionAddEvent,
      subtitle: context.messages.addActionAddEventHint,
      // Chevron for the same reason as the task row: creates, then opens.
      opensSheet: true,
      onTap: () async {
        final event = await createEvent(
          linkedId: linkedFromId,
          categoryId: categoryId,
        );
        if (!context.mounted) {
          return;
        }
        if (event != null) {
          unawaited(autoAssignCategoryEventAgent(ref, event));
          beamToNamed('/events/${event.meta.id}');
        }
        Navigator.of(context).pop();
      },
    );
  }
}

/// Create-menu item that creates a task linked to `linkedFromId`, kicks off
/// auto-assignment of a category agent, and navigates to the new task.
class CreateTaskItem extends ConsumerWidget {
  const CreateTaskItem(
    this.linkedFromId, {
    this.categoryId,
    super.key,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked = linkedFromId != null;
    return CreateMenuListItem(
      // `add_task`, not `task_alt`: the row creates a task, and the ticked
      // circle of `task_alt` painted "done" in the accent that elsewhere
      // means "create" — glyph and colour disagreeing about the verb.
      icon: Icons.add_task_rounded,
      // The relationship rides the TITLE, not just the subtitle — titles are
      // what get scanned, and inside a task page a bare "Add a task" is
      // ambiguous three ways (sibling? subtask? edit this one?). From the
      // journal list the created task stands alone and "linked" would lie,
      // so unlinked hosts keep the plain verb.
      title: linked
          ? context.messages.addActionCreateLinkedTask
          : context.messages.addActionCreateTask,
      subtitle: linked
          ? context.messages.addActionCreateLinkedTaskHint
          : context.messages.addActionCreateTaskHint,
      // Chevron, not plus: this row navigates to the task it creates, and by
      // the page's own glyph rule an action that takes you somewhere else is
      // chevron-class — the "+" claimed create-in-place for a teleport.
      opensSheet: true,
      onTap: () async {
        final task = await createTask(
          linkedId: linkedFromId,
          categoryId: categoryId,
        );
        if (!context.mounted) {
          return;
        }
        if (task != null) {
          unawaited(autoAssignCategoryAgent(ref, task));
          beamToNamed('/tasks/${task.meta.id}');
        }
        Navigator.of(context).pop();
      },
    );
  }
}

/// Adds a checklist to the host task. Only renders when the FAB sits on a
/// task detail page — i.e. when the entry resolved from `linkedFromId` is a
/// `Task`. On other surfaces (journal list, non-task entry details) it
/// disappears so the menu doesn't offer an action that would have nowhere
/// to attach.
class CreateChecklistItem extends ConsumerWidget {
  const CreateChecklistItem(this.linkedFromId, {super.key});

  final String? linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = linkedFromId;
    if (id == null) return const SizedBox.shrink();
    final entry = ref.watch(entryControllerProvider(id)).value?.entry;
    if (entry is! Task) return const SizedBox.shrink();

    return CreateMenuListItem(
      icon: Icons.checklist_rounded,
      // The same strings the first-run card uses for the same action — one
      // action, one name AND one explanation, on every surface that offers
      // it.
      title: context.messages.taskFirstRunAddChecklist,
      subtitle: context.messages.taskFirstRunAddChecklistHint,
      onTap: () async {
        await createChecklist(task: entry, ref: ref);
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
    );
  }
}

/// Create-menu item that opens the audio recording modal for a new audio
/// entry linked to `linkedFromId`.
class CreateAudioItem extends ConsumerWidget {
  const CreateAudioItem(
    this.linkedFromId, {
    this.categoryId,
    super.key,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryCreationService = ref.read(entryCreationServiceProvider);

    return CreateMenuListItem(
      icon: Icons.mic_rounded,
      // The card's string, its chevron AND its subtitle: the
      // does-tapping-start-recording ambiguity belongs to the action, not to
      // the surface it appears on.
      title: context.messages.taskFirstRunRecordAudio,
      subtitle: context.messages.taskFirstRunRecordAudioHint,
      opensSheet: true,
      onTap: () {
        Navigator.of(context).pop();
        entryCreationService.showAudioRecordingModal(
          context,
          linkedId: linkedFromId,
          categoryId: categoryId,
        );
      },
    );
  }
}

/// Create-menu item that starts a new timer entry linked to `linkedFromId`.
///
/// After creation it polls the parent's linked-entries list and, once the new
/// timer appears, publishes a focus intent to auto-scroll to it — fire-and-
/// forget so navigation is never blocked (see `_waitForTimerAndScroll`).
class CreateTimerItem extends ConsumerWidget {
  const CreateTimerItem(
    this.linkedFromId, {
    super.key,
  });

  final String linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked = ref
        .watch(entryControllerProvider(linkedFromId))
        .value
        ?.entry;
    final entryCreationService = ref.read(entryCreationServiceProvider);

    return CreateMenuListItem(
      icon: Icons.timer_outlined,
      // Verb + subtitle, because "Timer" alone never said the clock starts
      // the moment the row is tapped.
      title: context.messages.addActionStartTimer,
      subtitle: context.messages.addActionStartTimerHint,
      onTap: () async {
        final timerEntry = await entryCreationService.createTimerEntry(
          linked: linked,
        );
        if (!context.mounted) return;

        // Capture the container before popping so we can continue to access providers
        // after this widget is disposed
        final container = ProviderScope.containerOf(context, listen: false);

        Navigator.of(context).pop();

        // Auto-scroll to the newly created timer entry
        if (timerEntry != null && linked != null) {
          // Wait for LinkedEntriesController to update with the new timer before scrolling
          // Fire-and-forget: scrolling is a best-effort operation that shouldn't block navigation
          _waitForTimerAndScroll(
            container: container,
            parentId: linked.meta.id,
            timerEntryId: timerEntry.meta.id,
            isTask: linked is Task,
          );
        }
      },
    );
  }
}

/// Create-menu item that creates an empty text entry linked to `linkedFromId`.
class CreateTextItem extends ConsumerWidget {
  const CreateTextItem(
    this.linkedFromId, {
    this.categoryId,
    super.key,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryCreationService = ref.read(entryCreationServiceProvider);
    final id = linkedFromId;
    final host = id == null
        ? null
        : ref.watch(entryControllerProvider(id)).value?.entry;

    return CreateMenuListItem(
      icon: Icons.notes_rounded,
      // The first-run card's string — "Text Entry" and "Write a note" were
      // the same action wearing two names one tap apart.
      title: context.messages.taskFirstRunWriteNote,
      subtitle: context.messages.taskFirstRunWriteNoteHint,
      onTap: () async {
        final entry = await entryCreationService.createTextEntry(
          linkedId: linkedFromId,
          categoryId: categoryId,
        );
        // Same journey as the first-run card's row: on a task host the new
        // note lands in the linked entries below the fold, so without the
        // focus publish this label silently minted an off-screen empty note
        // — the documented dead-button flow the card row exists to avoid
        // (task_first_run_actions.dart). Non-task hosts scroll via their own
        // journal focus elsewhere; publishing is task-scoped.
        final id = linkedFromId;
        if (entry != null && id != null && host is Task) {
          ref
              .read(taskFocusControllerProvider(id).notifier)
              .publishTaskFocus(entryId: entry.meta.id);
        }
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}

/// Create-menu item that imports image(s) from the gallery/file picker as
/// entries linked to `linkedFromId`, passing each through the automatic image
/// analysis trigger. Only listed on macOS and mobile (see the menu list).
class ImportImageItem extends ConsumerWidget {
  const ImportImageItem(
    this.linkedFromId, {
    this.categoryId,
    super.key,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CreateMenuListItem(
      // Outlined, matching the stroke weight of every other leading glyph in
      // the sheet — the filled library icon was the one row shouting in
      // solid teal.
      icon: Icons.photo_library_outlined,
      title: context.messages.addActionImportImage,
      subtitle: context.messages.addActionImportImageHint,
      // Chevron: the tap opens a gallery / file picker, not a direct create.
      opensSheet: true,
      onTap: () async {
        final trigger = ref.read(automaticImageAnalysisTriggerProvider);
        // Desktop Linux/Windows have no gallery picker — use a file dialog.
        if (isLinux || isWindows) {
          await importImagePickerFiles(
            linkedId: linkedFromId,
            categoryId: categoryId,
            analysisTrigger: trigger,
          );
        } else {
          // Native gallery picker (photo_manager) — macOS/mobile only; the
          // headless Linux CI runner always takes the file-dialog branch above.
          // coverage:ignore-start
          await importImageAssets(
            context,
            linkedId: linkedFromId,
            categoryId: categoryId,
            analysisTrigger: trigger,
          );
          // coverage:ignore-end
        }
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}

/// Create-menu item that captures a screenshot as an entry linked to
/// `linkedFromId` and runs the automatic image analysis trigger on it. Only
/// listed on the desktop platforms that support capture (macOS, Linux).
class CreateScreenshotItem extends ConsumerWidget {
  const CreateScreenshotItem(
    this.linkedFromId, {
    this.categoryId,
    super.key,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CreateMenuListItem(
      icon: Icons.screenshot_monitor_rounded,
      title: context.messages.addActionAddScreenshot,
      // Says what is captured (the screen) and where it goes — the row's
      // one-word ancestor scared cautious users off entirely.
      subtitle: context.messages.addActionAddScreenshotHint,
      onTap: () async {
        await createScreenshot(
          linkedId: linkedFromId,
          categoryId: categoryId,
          analysisTrigger: ref.read(automaticImageAnalysisTriggerProvider),
        );
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}

/// Create-menu item that pastes image(s) from the clipboard as entries linked
/// to `linkedFromId`. The clipboard-has-an-image gate lives in the menu list
/// ([ImagePasteController]), which resolves all visibility before assembling
/// rows — this widget only renders when a paste is actually possible.
class PasteImageItem extends ConsumerWidget {
  const PasteImageItem(
    this.linkedFromId, {
    this.categoryId,
    super.key,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = imagePasteControllerProvider((
      linkedFromId: linkedFromId,
      categoryId: categoryId,
    ));

    return CreateMenuListItem(
      icon: Icons.content_paste_rounded,
      title: context.messages.addActionAddImageFromClipboard,
      subtitle: context.messages.addActionAddImageFromClipboardHint,
      onTap: () {
        Navigator.of(context).pop();
        ref.read(provider.notifier).paste();
      },
    );
  }
}

/// Waits for the timer entry to appear in LinkedEntriesController, then publishes focus intent
void _waitForTimerAndScroll({
  required ProviderContainer container,
  required String parentId,
  required String timerEntryId,
  required bool isTask,
}) {
  // Poll the LinkedEntriesController to check if the timer entry has appeared
  var attempts = 0;

  void checkAndScroll() {
    if (attempts >= _kTimerScrollMaxAttempts) {
      DevLogger.warning(
        name: 'CreateEntryItems',
        message:
            'Failed to find timer entry $timerEntryId after $_kTimerScrollMaxAttempts attempts',
      );
      return;
    }

    attempts++;

    // Check if the timer entry is in the linked entries
    final linkedEntries = container
        .read(linkedEntriesControllerProvider(parentId))
        .value;

    if (linkedEntries != null &&
        linkedEntries.any((link) => link.toId == timerEntryId)) {
      // Timer entry found! Publish focus intent
      if (isTask) {
        container
            .read(taskFocusControllerProvider(parentId).notifier)
            .publishTaskFocus(
              entryId: timerEntryId,
              alignment: kDefaultScrollAlignment,
            );
      } else {
        container
            .read(journalFocusControllerProvider(parentId).notifier)
            .publishJournalFocus(
              entryId: timerEntryId,
              alignment: kDefaultScrollAlignment,
            );
      }
    } else {
      // Not found yet, try again
      Future.delayed(_kTimerScrollPollInterval, checkAndScroll);
    }
  }

  // Start polling after a short delay to allow database write to complete
  Future.delayed(_kTimerScrollInitialDelay, checkAndScroll);
}
