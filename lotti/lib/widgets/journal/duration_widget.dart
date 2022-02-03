import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    this.saveFn,
  }) : super(key: key);

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 4),
                child: Icon(
                  MdiIcons.timerOutline,
                  color: labelColor,
                  size: 14,
                ),
              ),
              Text(
                formatDuration(entryDuration(displayed)),
                style: GoogleFonts.ptMono(
                  color: labelColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
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
                        padding: const EdgeInsets.only(right: 16),
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
                        padding: const EdgeInsets.only(right: 16),
                        icon: const Icon(Icons.stop),
                        iconSize: 20,
                        tooltip: 'Stop',
                        color: labelColor,
                        onPressed: () async {
                          _timeService.stop(item);

                          await context
                              .read<PersistenceCubit>()
                              .updateJournalEntityDate(
                                item,
                                dateFrom: item.meta.dateFrom,
                                dateTo: DateTime.now(),
                              );

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
