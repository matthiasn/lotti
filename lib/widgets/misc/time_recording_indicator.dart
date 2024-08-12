import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TimeRecordingIndicatorWidget extends StatelessWidget {
  TimeRecordingIndicatorWidget({
    super.key,
  });

  final TimeService _timeService = getIt<TimeService>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _timeService.getStream(),
      builder: (
        _,
        AsyncSnapshot<JournalEntity?> snapshot,
      ) {
        final current = snapshot.data;

        if (current == null) {
          return const SizedBox.shrink();
        }

        final durationString = formatDuration(entryDuration(current));

        return GestureDetector(
          onTap: () {
            final linkedFrom = _timeService.linkedFrom;
            linkedFrom != null
                ? linkedFrom is Task
                    ? beamToNamed('/tasks/${linkedFrom.meta.id}')
                    : beamToNamed('/journal/${linkedFrom.meta.id}')
                : beamToNamed('/journal/${current.meta.id}');
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
              ),
              child: Container(
                color: context.colorScheme.error,
                width: 90,
                height: 25,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      MdiIcons.timerOutline,
                      color: Colors.black,
                      size: 16,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        durationString,
                        style: monospaceTextStyle.copyWith(
                          color: Colors.black,
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
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      bottom: 0,
      child: TimeRecordingIndicatorWidget(),
    );
  }
}
