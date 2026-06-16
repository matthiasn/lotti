import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/themes/theme.dart';
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

  final titleStyle = const TextStyle(
    fontSize: fontSizeSmall,
    fontWeight: FontWeight.w500,
  );

  final subTitleStyle = const TextStyle(
    fontSize: fontSizeSmall,
    fontWeight: FontWeight.w300,
  );

  @override
  Widget build(BuildContext context) {
    final processingTime = widget.transcript.processingTime;

    return ExpansionTile(
      controller: _controller,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      trailing: SizedBox(
        width: 96,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IgnorePointer(
              ignoring: !show,
              child: Opacity(
                opacity: show ? 1 : 0,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  onPressed: () {
                    SpeechRepository.removeAudioTranscript(
                      journalEntityId: widget.entryId,
                      transcript: widget.transcript,
                    );
                  },
                  icon: const Icon(
                    MdiIcons.trashCanOutline,
                    size: fontSizeMedium,
                  ),
                ),
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: toggleShow,
              icon: Icon(
                show
                    ? Icons.keyboard_double_arrow_up_outlined
                    : Icons.keyboard_double_arrow_down_outlined,
                size: fontSizeMedium,
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
              const SizedBox(width: 8),
              if (processingTime != null)
                Text(
                  '⏳${formatMmSs(processingTime)}',
                  style: titleStyle,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Lang: ${widget.transcript.detectedLanguage.toUpperCase()}',
                style: subTitleStyle,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Model: ${widget.transcript.library}, ${widget.transcript.model}',
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SelectableText(widget.transcript.transcript),
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
