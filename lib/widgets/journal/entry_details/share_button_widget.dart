import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ShareButtonWidget extends StatelessWidget {
  ShareButtonWidget({
    super.key,
    required this.entityId,
  });

  final JournalDb db = getIt<JournalDb>();
  final String entityId;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<JournalEntity?>(
      stream: db.watchEntityById(entityId),
      builder: (context, snapshot) {
        final journalEntity = snapshot.data;
        if (journalEntity is! JournalImage && journalEntity is! JournalAudio) {
          return const SizedBox.shrink();
        }

        var tooltip = '';

        if (journalEntity is JournalImage) {
          tooltip = localizations.journalSharePhotoHint;
        }
        if (journalEntity is JournalAudio) {
          tooltip = localizations.journalShareAudioHint;
        }

        Future<void> onPressed() async {
          if (journalEntity is JournalImage) {
            final filePath = await getFullImagePath(journalEntity);
            await Share.shareFiles([filePath]);
          }
          if (journalEntity is JournalAudio) {
            final filePath = await AudioUtils.getFullAudioPath(journalEntity);
            await Share.shareFiles([filePath]);
          }
        }

        return IconButton(
          icon: const Icon(MdiIcons.shareOutline),
          iconSize: 24,
          tooltip: tooltip,
          padding: const EdgeInsets.only(
            left: 12,
            top: 8,
            bottom: 8,
          ),
          color: AppColors.entryTextColor,
          onPressed: onPressed,
        );
      },
    );
  }
}
