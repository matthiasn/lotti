import 'package:flutter/material.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/main.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/src/provider.dart';

class DurationWidget extends StatelessWidget {
  final TimeService _timeService = getIt<TimeService>();

  DurationWidget({
    Key? key,
    required this.item,
    this.style,
    this.showControls = false,
  }) : super(key: key);

  final JournalEntity item;
  final TextStyle? style;
  final bool showControls;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _timeService.getStream(),
      builder: (
        BuildContext context,
        AsyncSnapshot<JournalEntity?> snapshot,
      ) {
        bool isRecent =
            DateTime.now().difference(item.meta.dateFrom).inHours < 12;

        JournalEntity? recording = snapshot.data;
        JournalEntity displayed = item;
        bool isRecording = false;

        if (recording != null && recording.meta.id == item.meta.id) {
          displayed = recording;
          isRecording = true;
        }

        Color? labelColor =
            isRecording ? AppColors.timeRecording : style?.color;

        return Visibility(
          visible: entryDuration(displayed).inMilliseconds > 0 || isRecent,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 4, top: 2),
                child: Icon(
                  MdiIcons.timerOutline,
                  color: labelColor,
                  size: (style?.fontSize ?? 14) + 2,
                ),
              ),
              Text(
                formatDuration(entryDuration(displayed)),
                style: style?.copyWith(
                  color: labelColor,
                ),
              ),
              Visibility(
                visible: showControls && isRecent,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      icon: const Icon(Icons.play_arrow_outlined),
                      iconSize: 24,
                      tooltip: 'Record',
                      color: style?.color,
                      onPressed: () {
                        _timeService.start(item);
                      },
                    ),
                    IconButton(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      icon: const Icon(Icons.stop_outlined),
                      iconSize: 24,
                      tooltip: 'Stop',
                      color: style?.color,
                      onPressed: () async {
                        _timeService.stop(item);

                        await context
                            .read<PersistenceCubit>()
                            .updateJournalEntityDate(
                              item,
                              dateFrom: item.meta.dateFrom,
                              dateTo: DateTime.now(),
                            );
                      },
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
