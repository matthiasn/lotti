import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/image_paste_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
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
    return ModernModalEntryTypeItem(
      icon: Icons.mic_none_rounded,
      title: context.messages.addActionAddAudioRecording,
      onTap: () {
        Navigator.of(context).pop();
        AudioRecordingModal.show(
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

    return ModernModalEntryTypeItem(
      icon: Icons.timer_outlined,
      title: context.messages.addActionAddTimer,
      onTap: () {
        createTimerEntry(linked: linked);
        Navigator.of(context).pop();
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
    return ModernModalEntryTypeItem(
      icon: Icons.notes_rounded,
      title: context.messages.addActionAddText,
      onTap: () async {
        await createTextEntry(
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
