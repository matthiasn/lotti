import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Expandable row for a single [AudioTranscript].
///
/// The collapsed header shows the created date, optional processing time,
/// detected language, and model; expanding reveals the selectable transcript
/// text. A reveal toggle exposes a delete action that removes this transcript
/// from the entry via [SpeechRepository.removeAudioTranscript].
class TranscriptListItem extends StatefulWidget {
  const TranscriptListItem(
    this.transcript, {
    required this.entryId,
    super.key,
  });

  /// Id of the audio entry this transcript belongs to (used for deletion).
  final String entryId;

  /// The transcript rendered by this row.
  final AudioTranscript transcript;

  @override
  State<TranscriptListItem> createState() => _TranscriptListItemState();
}

class _TranscriptListItemState extends State<TranscriptListItem> {
  final ExpansibleController _controller = ExpansibleController();

  bool show = false;

  void toggleShow() {
    setState(() {
      show = !show;
    });

    if (_controller.isExpanded) {
      _controller.collapse();
    } else {
      _controller.expand();
    }
  }

  @override
  Widget build(BuildContext context) {
    final processingTime = widget.transcript.processingTime;
    final tokens = context.designTokens;
    final titleStyle = tokens.typography.styles.body.bodySmall;
    final subTitleStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

    return ExpansionTile(
      controller: _controller,
      tilePadding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
      trailing: SizedBox(
        width: tokens.spacing.step12,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Visibility(
              visible: show,
              maintainAnimation: true,
              maintainSize: true,
              maintainState: true,
              child: IconButton(
                tooltip: context.messages.aiCardMenuActionDelete,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: tokens.spacing.step8,
                  minHeight: tokens.spacing.step8,
                ),
                onPressed: () {
                  SpeechRepository.removeAudioTranscript(
                    journalEntityId: widget.entryId,
                    transcript: widget.transcript,
                  );
                },
                icon: Icon(
                  MdiIcons.trashCanOutline,
                  size: tokens.spacing.step5,
                ),
              ),
            ),
            IconButton(
              tooltip: show
                  ? context.messages.checklistCollapseTooltip
                  : context.messages.checklistExpandTooltip,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: tokens.spacing.step8,
                minHeight: tokens.spacing.step8,
              ),
              onPressed: toggleShow,
              icon: Icon(
                show
                    ? Icons.keyboard_double_arrow_up_outlined
                    : Icons.keyboard_double_arrow_down_outlined,
                size: tokens.spacing.step5,
              ),
            ),
          ],
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dfShorter.format(widget.transcript.created),
                style: titleStyle,
              ),
              SizedBox(width: tokens.spacing.step3),
              if (processingTime != null)
                Text(
                  '⏳${formatMmSs(processingTime)}',
                  style: titleStyle,
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.step2),
          Row(
            children: [
              Text(
                context.messages.transcriptLanguageLabel(
                  widget.transcript.detectedLanguage.toUpperCase(),
                ),
                style: subTitleStyle,
              ),
              SizedBox(width: tokens.spacing.step3),
              Flexible(
                child: Text(
                  context.messages.transcriptModelLabel(
                    widget.transcript.library,
                    widget.transcript.model,
                  ),
                  style: subTitleStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step5,
            vertical: tokens.spacing.step4,
          ),
          child: SelectableText(
            widget.transcript.transcript,
            style: tokens.typography.styles.body.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// Formats a [Duration] as `<minutes>m<seconds>s` (e.g. `02m07s`), used for the
/// transcript processing-time badge. Both fields are zero-padded to two digits.
String formatMmSs(Duration dur) {
  return '${padLeft(dur.inMinutes)}m${padLeft(dur.inSeconds.remainder(60))}s';
}
