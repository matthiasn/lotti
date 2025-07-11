import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/image_paste_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/modal/modern_modal_entry_type_item.dart';

/// Modern version of create event item
class ModernCreateEventItem extends ConsumerWidget {
  const ModernCreateEventItem(
    this.linkedFromId, {
    this.categoryId,
    super.key,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ModernModalEntryTypeItem(
      icon: Icons.event_rounded,
      title: 'Event',
      onTap: () async {
        await createEvent(
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

/// Modern version of create task item
class ModernCreateTaskItem extends ConsumerWidget {
  const ModernCreateTaskItem(
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
      title: 'Task',
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
class ModernCreateAudioItem extends ConsumerWidget {
  const ModernCreateAudioItem(
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
      title: 'Audio',
      onTap: () {
        Navigator.of(context).pop();
        AudioRecordingModal.show(
          context,
          linkedId: linkedFromId,
        );
      },
    );
  }
}

/// Modern version of create timer item
class ModernCreateTimerItem extends ConsumerWidget {
  const ModernCreateTimerItem(
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
      title: 'Timer',
      onTap: () {
        createTimerEntry(linked: linked);
        Navigator.of(context).pop();
      },
    );
  }
}

/// Modern version of create text item
class ModernCreateTextItem extends ConsumerWidget {
  const ModernCreateTextItem(
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
      title: 'Text',
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
class ModernImportImageItem extends ConsumerWidget {
  const ModernImportImageItem(
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
      title: 'Import Image',
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
class ModernCreateScreenshotItem extends ConsumerWidget {
  const ModernCreateScreenshotItem(
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
      title: 'Screenshot',
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
class ModernPasteImageItem extends ConsumerWidget {
  const ModernPasteImageItem(
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
      title: 'Paste Image',
      onTap: () {
        Navigator.of(context).pop();
        ref.read(provider.notifier).paste();
      },
    );
  }
}
