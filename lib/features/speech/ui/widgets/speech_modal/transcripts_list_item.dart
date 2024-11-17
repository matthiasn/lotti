import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TranscriptListItem extends StatefulWidget {
  const TranscriptListItem(
    this.transcript, {
    required this.entryId,
    super.key,
  });

  final String entryId;
  final AudioTranscript transcript;

  @override
  State<TranscriptListItem> createState() => _TranscriptListItemState();
}

class _TranscriptListItemState extends State<TranscriptListItem> {
  final ExpansionTileController _controller = ExpansionTileController();

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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: show ? 1 : 0,
            child: IconButton(
              onPressed: () {
                getIt<PersistenceLogic>().removeAudioTranscript(
                  journalEntityId: widget.entryId,
                  transcript: widget.transcript,
                );
              },
              icon: Icon(
                MdiIcons.trashCanOutline,
                size: fontSizeMedium,
              ),
            ),
          ),
          IconButton(
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
      title: Row(
        children: [
          Text(
            dfShorter.format(widget.transcript.created),
            style: titleStyle,
          ),
          const SizedBox(width: 10),
          if (processingTime != null)
            Text(
              '⏳${formatMmSs(processingTime)}',
              style: titleStyle,
            ),
          const SizedBox(width: 10),
        ],
      ),
      subtitle: Row(
        children: [
          Text(
            'Lang: ${widget.transcript.detectedLanguage.toUpperCase()}',
            style: subTitleStyle,
          ),
          const SizedBox(width: 10),
          Text(
            'Model: ${widget.transcript.library}, '
            ' ${widget.transcript.model}',
            style: subTitleStyle,
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SelectableText(widget.transcript.transcript),
        ),
      ],
    );
  }
}

String formatMmSs(Duration dur) {
  return '${padLeft(dur.inMinutes)}m${padLeft(dur.inSeconds.remainder(60))}s';
}
