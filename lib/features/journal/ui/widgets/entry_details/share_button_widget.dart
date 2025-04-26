import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ShareButtonWidget extends ConsumerWidget {
  const ShareButtonWidget({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;
    final entry = entryState?.entry;

    if (entryState == null ||
        entry is! JournalImage && entry is! JournalAudio) {
      return const SizedBox.shrink();
    }

    var tooltip = '';

    if (entry is JournalImage) {
      tooltip = context.messages.journalSharePhotoHint;
    }
    if (entry is JournalAudio) {
      tooltip = context.messages.journalShareAudioHint;
    }

    Future<void> onPressed() async {
      if (isLinux || isWindows) {
        return;
      }

      if (entry is JournalImage) {
        final filePath = getFullImagePath(entry);
        await SharePlus.instance.share(ShareParams(files: [XFile(filePath)]));
      }
      if (entry is JournalAudio) {
        final filePath = await AudioUtils.getFullAudioPath(entry);
        await SharePlus.instance.share(ShareParams(files: [XFile(filePath)]));
      }
    }

    return SizedBox(
      width: 40,
      child: IconButton(
        icon: Icon(MdiIcons.shareOutline),
        splashColor: Colors.transparent,
        iconSize: 24,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }
}

class ShareButtonListTile extends ConsumerWidget {
  const ShareButtonListTile({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;
    final entry = entryState?.entry;

    if (entryState == null ||
        entry is! JournalImage && entry is! JournalAudio) {
      return const SizedBox.shrink();
    }

    var tooltip = '';

    if (entry is JournalImage) {
      tooltip = context.messages.journalSharePhotoHint;
    }
    if (entry is JournalAudio) {
      tooltip = context.messages.journalShareAudioHint;
    }

    Future<void> onTap() async {
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (isLinux || isWindows) {
        return;
      }

      if (entry is JournalImage) {
        final filePath = getFullImagePath(entry);
        await SharePlus.instance.share(ShareParams(files: [XFile(filePath)]));
      }
      if (entry is JournalAudio) {
        final filePath = await AudioUtils.getFullAudioPath(entry);
        await SharePlus.instance.share(ShareParams(files: [XFile(filePath)]));
      }
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }

    return ListTile(
      leading: Icon(MdiIcons.shareOutline),
      title: Text(tooltip),
      onTap: onTap,
    );
  }
}
