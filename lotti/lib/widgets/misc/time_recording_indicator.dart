import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/main.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_detail_route.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class TimeRecordingIndicator extends StatelessWidget {
  final TimeService _timeService = getIt<TimeService>();

  TimeRecordingIndicator({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _timeService.getStream(),
      builder: (
        _,
        AsyncSnapshot<JournalEntity?> snapshot,
      ) {
        JournalEntity? current = snapshot.data;

        if (current == null) {
          return const SizedBox.shrink();
        }

        String durationString = formatDuration(entryDuration(current));

        return Positioned(
          right: MediaQuery.of(context).size.width / 2 - 60,
          bottom: 0,
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (BuildContext context) {
                    return EntryDetailRoute(
                      item: current,
                      index: 0,
                    );
                  },
                ),
              );
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Container(
                  color: AppColors.timeRecording,
                  width: 120,
                  height: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        durationString,
                        style: GoogleFonts.ptMono(
                          fontSize: 20.0,
                          color: Colors.grey[300],
                          fontWeight: FontWeight.w100,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
