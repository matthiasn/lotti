// ignore_for_file: avoid_dynamic_calls

import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/theme/theme.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DurationWidget extends StatelessWidget {
  DurationWidget({
    super.key,
    required this.item,
    this.style,
    this.showControls = false,
    this.saveFn,
  });

  final TimeService _timeService = getIt<TimeService>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final JournalEntity item;
  final TextStyle? style;
  final bool showControls;
  final Function? saveFn;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _timeService.getStream(),
      builder: (
        BuildContext context,
        AsyncSnapshot<JournalEntity?> snapshot,
      ) {
        final isRecent =
            DateTime.now().difference(item.meta.dateFrom).inHours < 12;

        final recording = snapshot.data;
        var displayed = item;
        var isRecording = false;

        if (recording != null && recording.meta.id == item.meta.id) {
          displayed = recording;
          isRecording = true;
        }

        final labelColor = isRecording
            ? getIt<ThemeService>().colors.timeRecording
            : style?.color;

        return Visibility(
          visible: entryDuration(displayed).inMilliseconds > 0 ||
              (isRecent && showControls),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  MdiIcons.timerOutline,
                  color: labelColor,
                  size: 14,
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  formatDuration(entryDuration(displayed)),
                  style: style?.copyWith(
                    color: labelColor,
                  ),
                ),
              ),
              Visibility(
                visible: showControls && isRecent,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Visibility(
                      visible: !isRecording,
                      child: IconButton(
                        padding: const EdgeInsets.only(right: 8),
                        icon: const Icon(Icons.play_arrow),
                        iconSize: 20,
                        tooltip: 'Record',
                        color: style?.color,
                        onPressed: () {
                          _timeService.start(item);
                        },
                      ),
                    ),
                    Visibility(
                      visible: isRecording,
                      child: IconButton(
                        padding: const EdgeInsets.only(right: 8),
                        icon: const Icon(Icons.stop),
                        iconSize: 20,
                        tooltip: 'Stop',
                        color: labelColor,
                        onPressed: () async {
                          await _timeService.stop();

                          if (saveFn != null) {
                            await saveFn!();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
