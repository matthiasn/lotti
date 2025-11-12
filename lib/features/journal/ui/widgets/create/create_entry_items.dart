import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/calendar/ui/pages/day_view_page.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/image_paste_controller.dart';
import 'package:lotti/features/journal/state/journal_focus_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/logic/create/entry_creation_service.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/modal/modern_modal_entry_type_item.dart';

/// Modern version of create event item
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
    final enableEventsAsync = ref.watch(configFlagProvider(enableEventsFlag));

    // Use unwrapPrevious to keep previous value during loading/error states
    final enableEvents = enableEventsAsync
            .unwrapPrevious()
            .whenData((value) => value)
            .valueOrNull ??
        false;

    if (!enableEvents) {
      return const SizedBox.shrink();
    }

    return _buildEventItem(context);
  }

  Widget _buildEventItem(BuildContext context) {
    return ModernModalEntryTypeItem(
      icon: Icons.event_rounded,
      title: context.messages.addActionAddEvent,
      onTap: () async {
        final event = await createEvent(
          linkedId: linkedFromId,
          categoryId: categoryId,
        );
        if (!context.mounted) {
          return;
        }
        if (event != null) {
          beamToNamed('/journal/${event.meta.id}');
        }
        Navigator.of(context).pop();
      },
    );
  }
}

/// Modern version of create task item
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
    return ModernModalEntryTypeItem(
      icon: Icons.task_alt_rounded,
      title: context.messages.addActionAddTask,
      onTap: () async {
        final task = await createTask(
          linkedId: linkedFromId,
          categoryId: categoryId,
        );
        if (!context.mounted) {
          return;
        }
        if (task != null) {
          beamToNamed('/tasks/${task.meta.id}');
        }
        Navigator.of(context).pop();
      },
    );
  }
}

/// Modern version of create audio item
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

    return ModernModalEntryTypeItem(
      icon: Icons.mic_none_rounded,
      title: context.messages.addActionAddAudioRecording,
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

/// Modern version of create timer item
class CreateTimerItem extends ConsumerWidget {
  const CreateTimerItem(
    this.linkedFromId, {
    super.key,
  });

  final String linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked =
        ref.watch(entryControllerProvider(id: linkedFromId)).value?.entry;
    final entryCreationService = ref.read(entryCreationServiceProvider);

    return ModernModalEntryTypeItem(
      icon: Icons.timer_outlined,
      title: context.messages.addActionAddTimer,
      onTap: () async {
        final timerEntry =
            await entryCreationService.createTimerEntry(linked: linked);
        if (!context.mounted) return;

        Navigator.of(context).pop();

        // Auto-scroll to the newly created timer entry
        if (timerEntry != null && linked != null) {
          // Wait for LinkedEntriesController to update with the new timer before scrolling
          _waitForTimerAndScroll(
            ref: ref,
            parentId: linked.meta.id,
            timerEntryId: timerEntry.meta.id,
            isTask: linked is Task,
          );
        }
      },
    );
  }
}

/// Modern version of create text item
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

    return ModernModalEntryTypeItem(
      icon: Icons.notes_rounded,
      title: context.messages.addActionAddText,
      onTap: () async {
        await entryCreationService.createTextEntry(
          linkedId: linkedFromId,
          categoryId: categoryId,
        );
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}

/// Modern version of import image item
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
    return ModernModalEntryTypeItem(
      icon: Icons.photo_library_rounded,
      title: context.messages.addActionImportImage,
      onTap: () async {
        await importImageAssets(
          context,
          linkedId: linkedFromId,
          categoryId: categoryId,
        );
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}

/// Modern version of create screenshot item
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
    return ModernModalEntryTypeItem(
      icon: Icons.screenshot_monitor_rounded,
      title: context.messages.addActionAddScreenshot,
      onTap: () async {
        await createScreenshot(
          linkedId: linkedFromId,
          categoryId: categoryId,
        );
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}

/// Modern version of paste image item
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
    final provider = imagePasteControllerProvider(
      linkedFromId: linkedFromId,
      categoryId: categoryId,
    );
    final canPasteImage = ref.watch(provider).valueOrNull ?? false;

    if (!canPasteImage) {
      return const SizedBox.shrink();
    }

    return ModernModalEntryTypeItem(
      icon: Icons.content_paste_rounded,
      title: context.messages.addActionAddImageFromClipboard,
      onTap: () {
        Navigator.of(context).pop();
        ref.read(provider.notifier).paste();
      },
    );
  }
}

/// Waits for the timer entry to appear in LinkedEntriesController, then publishes focus intent
void _waitForTimerAndScroll({
  required WidgetRef ref,
  required String parentId,
  required String timerEntryId,
  required bool isTask,
}) {
  // Poll the LinkedEntriesController to check if the timer entry has appeared
  var attempts = 0;
  const maxAttempts = 30; // 3 seconds total (100ms * 30)
  const pollInterval = Duration(milliseconds: 100);

  void checkAndScroll() {
    if (attempts >= maxAttempts) {
      debugPrint(
        'Failed to find timer entry $timerEntryId after $maxAttempts attempts',
      );
      return;
    }

    attempts++;

    // Check if the timer entry is in the linked entries
    final linkedEntries =
        ref.read(linkedEntriesControllerProvider(id: parentId)).valueOrNull;

    if (linkedEntries != null &&
        linkedEntries.any((link) => link.toId == timerEntryId)) {
      // Timer entry found! Publish focus intent
      if (isTask) {
        publishTaskFocus(
          taskId: parentId,
          entryId: timerEntryId,
          ref: ref,
          alignment: kDefaultScrollAlignment,
        );
      } else {
        ref
            .read(journalFocusControllerProvider(id: parentId).notifier)
            .publishJournalFocus(
              entryId: timerEntryId,
              alignment: kDefaultScrollAlignment,
            );
      }
    } else {
      // Not found yet, try again
      Future.delayed(pollInterval, checkAndScroll);
    }
  }

  // Start polling after a short delay to allow database write to complete
  Future.delayed(const Duration(milliseconds: 200), checkAndScroll);
}
