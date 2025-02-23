// ignore_for_file: avoid_dynamic_calls

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DurationWidget extends ConsumerWidget {
  DurationWidget({
    required this.item,
    required this.linkedFrom,
    super.key,
    this.style,
  });

  final TimeService _timeService = getIt<TimeService>();
  final JournalEntity item;
  final JournalEntity? linkedFrom;

  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: item.meta.id);

    return StreamBuilder(
      stream: _timeService.getStream(),
      builder: (
        BuildContext context,
        AsyncSnapshot<JournalEntity?> snapshot,
      ) {
        final isRecent =
            DateTime.now().difference(item.meta.dateFrom).inHours < 12;

        final recording = snapshot.data;

        final latestLinkedId = ref
            .watch(newestLinkedIdControllerProvider(id: linkedFrom?.id))
            .valueOrNull;

        final showRecordIcon = item is JournalEntry &&
            (latestLinkedId == item.id || linkedFrom == null);

        var displayed = item;
        var isRecording = false;

        if (recording != null && recording.meta.id == item.meta.id) {
          displayed = recording;
          isRecording = true;
        }

        final labelColor =
            isRecording ? context.colorScheme.error : style?.color;

        final saveFn = ref.read(provider.notifier).save;

        return Visibility(
          visible: entryDuration(displayed).inMilliseconds > 0 || isRecent,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  MdiIcons.timerOutline,
                  color: labelColor,
                  size: 15,
                ),
              ),
              FormattedTime(
                labelColor: labelColor,
                displayed: displayed,
              ),
              Visibility(
                visible: isRecent && showRecordIcon && !isRecording,
                child: IconButton(
                  icon: const Icon(Icons.fiber_manual_record_sharp),
                  iconSize: 20,
                  tooltip: 'Record',
                  color: context.colorScheme.error,
                  onPressed: () {
                    _timeService.start(item, linkedFrom);
                  },
                ),
              ),
              Visibility(
                visible: isRecording,
                child: IconButton(
                  icon: const Icon(Icons.stop),
                  iconSize: 20,
                  tooltip: 'Stop',
                  color: labelColor,
                  onPressed: () async {
                    await saveFn(stopRecording: true);
                  },
                ),
              ),
              const SizedBox(width: 15),
            ],
          ),
        );
      },
    );
  }
}

class FormattedTime extends StatelessWidget {
  const FormattedTime({
    required this.labelColor,
    required this.displayed,
    super.key,
  });

  final Color? labelColor;
  final JournalEntity displayed;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatDuration(entryDuration(displayed)),
      style: TextStyle(
        fontFeatures: const [FontFeature.tabularFigures()],
        color: labelColor,
      ),
    );
  }
}
