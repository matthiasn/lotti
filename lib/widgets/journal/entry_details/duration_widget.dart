// ignore_for_file: avoid_dynamic_calls

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DurationWidget extends StatelessWidget {
  DurationWidget({
    super.key,
    required this.item,
    this.style,
  });

  final TimeService _timeService = getIt<TimeService>();
  final JournalEntity item;
  final TextStyle? style;

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
        final showRecordIcon = item is JournalEntry;
        var displayed = item;
        var isRecording = false;

        if (recording != null && recording.meta.id == item.meta.id) {
          displayed = recording;
          isRecording = true;
        }

        final labelColor = isRecording ? styleConfig().alarm : style?.color;

        return BlocBuilder<EntryCubit, EntryState>(
          builder: (
            context,
            EntryState snapshot,
          ) {
            final saveFn = context.read<EntryCubit>().save;

            return Visibility(
              visible: entryDuration(displayed).inMilliseconds > 0 ||
                  (isRecent && showRecordIcon),
              child: Row(
                children: [
                  FormattedTime(
                    labelColor: labelColor,
                    displayed: displayed,
                    style: style,
                  ),
                  Visibility(
                    visible: isRecent && showRecordIcon,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Visibility(
                          visible: !isRecording,
                          child: IconButton(
                            padding: const EdgeInsets.only(right: 8),
                            icon: const Icon(Icons.fiber_manual_record_sharp),
                            iconSize: 20,
                            tooltip: 'Record',
                            color: styleConfig().alarm,
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
                              await saveFn();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class DurationViewWidget extends StatelessWidget {
  DurationViewWidget({
    super.key,
    required this.item,
    this.style,
  });

  final TimeService _timeService = getIt<TimeService>();
  final JournalEntity item;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _timeService.getStream(),
      builder: (
        BuildContext context,
        AsyncSnapshot<JournalEntity?> snapshot,
      ) {
        final recording = snapshot.data;
        var displayed = item;
        var isRecording = false;

        if (recording != null && recording.meta.id == item.meta.id) {
          displayed = recording;
          isRecording = true;
        }

        final labelColor = isRecording ? styleConfig().alarm : style?.color;

        return Visibility(
          visible: entryDuration(displayed).inMilliseconds > 0,
          child: FormattedTime(
            labelColor: labelColor,
            displayed: displayed,
            style: style,
          ),
        );
      },
    );
  }
}

class FormattedTime extends StatelessWidget {
  const FormattedTime({
    super.key,
    required this.labelColor,
    required this.displayed,
    required this.style,
  });

  final Color? labelColor;
  final JournalEntity displayed;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            MdiIcons.timerOutline,
            color: styleConfig().primaryTextColor,
            size: 15,
          ),
        ),
        Text(
          formatDuration(entryDuration(displayed)),
          style: monospaceTextStyle(),
        ),
      ],
    );
  }
}
