import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class CreateTextEntryListTile extends StatelessWidget {
  const CreateTextEntryListTile(
    this.linkedFromId, {
    this.categoryId,
    super.key,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(MdiIcons.textLong),
      title: Text(context.messages.addActionAddText),
      onTap: () {
        Navigator.of(context).pop();
        createTextEntry(linkedId: linkedFromId, categoryId: categoryId);
      },
    );
  }
}

class CreateScreenshotListTile extends StatelessWidget {
  const CreateScreenshotListTile(
    this.linkedFromId, {
    this.categoryId,
    super.key,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(MdiIcons.monitorScreenshot),
      title: Text(context.messages.addActionAddScreenshot),
      onTap: () {
        createScreenshot(linkedId: linkedFromId, categoryId: categoryId);
        Navigator.of(context).pop();
      },
    );
  }
}

class CreateTimerListTile extends ConsumerWidget {
  const CreateTimerListTile(
    this.linkedFromId, {
    super.key,
  });

  final String linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked =
        ref.watch(entryControllerProvider(id: linkedFromId)).value?.entry;

    return ListTile(
      leading: Icon(MdiIcons.timerOutline),
      title: Text(context.messages.addActionAddTimeRecording),
      onTap: () {
        createTimerEntry(linked: linked);
        Navigator.of(context).pop();
      },
    );
  }
}

class CreateAudioRecordingListTile extends StatelessWidget {
  const CreateAudioRecordingListTile(
    this.linkedFromId, {
    this.categoryId,
    super.key,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.mic_rounded),
      title: Text(context.messages.addActionAddAudioRecording),
      onTap: () {
        Navigator.of(context).pop();
        if (getIt<NavService>().isTasksTabActive()) {
          beamToNamed(
            '/tasks/$linkedFromId/record_audio/$linkedFromId?categoryId=$categoryId',
            data: {'categoryId': categoryId},
          );
        } else {
          beamToNamed(
            '/journal/$linkedFromId/record_audio/$linkedFromId?categoryId=$categoryId',
            data: {'categoryId': categoryId},
          );
        }
      },
    );
  }
}

class CreateTaskListTile extends StatelessWidget {
  const CreateTaskListTile(
    this.linkedFromId, {
    this.categoryId,
    super.key,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.task_outlined),
      title: Text(context.messages.addActionAddTask),
      onTap: () async {
        Navigator.of(context).pop();

        final task = await createTask(
          linkedId: linkedFromId,
          categoryId: categoryId,
        );

        if (task != null) {
          beamToNamed('/tasks/${task.meta.id}');
        }
      },
    );
  }
}

class CreateEventListTile extends StatelessWidget {
  const CreateEventListTile(
    this.linkedFromId, {
    this.categoryId,
    super.key,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.event_outlined),
      title: Text(context.messages.addActionAddEvent),
      onTap: () async {
        Navigator.of(context).pop();

        final event = await createEvent(
          linkedId: linkedFromId,
          categoryId: categoryId,
        );

        if (event != null) {
          beamToNamed('/journal/${event.meta.id}');
        }
      },
    );
  }
}

class ImportImageAssetsListTile extends StatelessWidget {
  const ImportImageAssetsListTile(
    this.linkedFromId, {
    this.categoryId,
    super.key,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.add_a_photo_outlined),
      title: Text(context.messages.addActionAddPhotos),
      onTap: () {
        Navigator.of(context).pop();

        importImageAssets(
          context,
          linkedId: linkedFromId,
        );
      },
    );
  }
}
