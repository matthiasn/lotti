import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TimeRecordingIndicator extends StatelessWidget {
  const TimeRecordingIndicator({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final timeService = getIt<TimeService>();

    return StreamBuilder(
      stream: timeService.getStream(),
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
            final linkedFrom = timeService.linkedFrom;
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
