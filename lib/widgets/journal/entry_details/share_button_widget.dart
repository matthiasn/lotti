import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ShareButtonWidget extends StatelessWidget {
  const ShareButtonWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocBuilder<EntryCubit, EntryState>(
      builder: (context, EntryState state) {
        final item = state.entry;
        if (item is! JournalImage && item is! JournalAudio) {
          return const SizedBox.shrink();
        }

        var tooltip = '';

        if (item is JournalImage) {
          tooltip = localizations.journalSharePhotoHint;
        }
        if (item is JournalAudio) {
          tooltip = localizations.journalShareAudioHint;
        }

        Future<void> onPressed() async {
          if (isLinux || isWindows) {
            return;
          }

          if (item is JournalImage) {
            final filePath = await getFullImagePath(item);
            await Share.shareFiles([filePath]);
          }
          if (item is JournalAudio) {
            final filePath = await AudioUtils.getFullAudioPath(item);
            await Share.shareFiles([filePath]);
          }
        }

        return IconButton(
          icon: const Icon(MdiIcons.shareOutline),
          iconSize: 24,
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          color: colorConfig().entryTextColor,
          onPressed: onPressed,
        );
      },
    );
  }
}
