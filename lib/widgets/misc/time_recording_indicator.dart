import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TimeRecordingIndicatorWidget extends StatelessWidget {
  final TimeService _timeService = getIt<TimeService>();

  TimeRecordingIndicatorWidget({
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

        return GestureDetector(
          onTap: () {
            String itemId = current.meta.id;
            pushNamedRoute('/journal/$itemId');
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
              ),
              child: Container(
                color: AppColors.timeRecordingBg,
                width: 110,
                height: 32,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      MdiIcons.timerOutline,
                      color: AppColors.editorTextColor,
                      size: 16,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        durationString,
                        style: TextStyle(
                          fontFamily: 'ShareTechMono',
                          fontSize: 18.0,
                          color: AppColors.editorTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class TimeRecordingIndicator extends StatelessWidget {
  const TimeRecordingIndicator({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      bottom: 0,
      child: TimeRecordingIndicatorWidget(),
    );
  }
}
