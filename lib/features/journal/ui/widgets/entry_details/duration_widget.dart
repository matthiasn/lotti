import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_multipage_modal.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/ratings/state/session_ended_controller.dart';
import 'package:lotti/features/ratings/ui/pulsating_rate_button.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DurationWidget extends ConsumerStatefulWidget {
  const DurationWidget({
    required this.item,
    required this.linkedFrom,
    super.key,
  });

  final JournalEntity item;
  final JournalEntity? linkedFrom;

  @override
  ConsumerState<DurationWidget> createState() => _DurationWidgetState();
}

class _DurationWidgetState extends ConsumerState<DurationWidget> {
  final TimeService _timeService = getIt<TimeService>();
  StreamSubscription<JournalEntity?>? _subscription;

  /// Tracks whether this entry was actively recording in the previous
  /// stream emission so we can detect the recording→stopped transition.
  bool _wasRecording = false;

  /// The latest snapshot from the time service stream, used for rendering.
  JournalEntity? _currentRecording;

  @override
  void initState() {
    super.initState();
    _subscription = _timeService.getStream().listen(_onTimeServiceEvent);
  }

  void _onTimeServiceEvent(JournalEntity? recording) {
    final entryId = widget.item.meta.id;
    final isRecording = recording != null && recording.meta.id == entryId;

    // Detect recording→stopped transition and persist in provider
    if (_wasRecording && !isRecording) {
      final duration = DateTime.now().difference(widget.item.meta.dateFrom);
      if (duration >= const Duration(minutes: 1)) {
        ref
            .read(sessionEndedControllerProvider.notifier)
            .markSessionEnded(entryId);
      }
    }
    // Clear when a new recording starts on this entry
    if (isRecording && !_wasRecording) {
      ref
          .read(sessionEndedControllerProvider.notifier)
          .clearSessionEnded(entryId);
    }
    _wasRecording = isRecording;

    setState(() {
      _currentRecording = recording;
    });
  }

  @override
  void didUpdateWidget(DurationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset tracking when the entry changes to avoid false transitions
    if (widget.item.meta.id != oldWidget.item.meta.id) {
      _wasRecording = false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final entryId = item.meta.id;
    final linkedFrom = widget.linkedFrom;
    final provider = entryControllerProvider(id: entryId);
    final entry = ref.watch(provider).value?.entry;

    final sessionJustEnded = ref.watch(
      sessionEndedControllerProvider.select(
        (ids) => ids.contains(entryId),
      ),
    );

    final isRecent = DateTime.now().difference(item.meta.dateFrom).inHours < 12;

    final recording = _currentRecording;

    final latestLinkedId = ref
        .watch(newestLinkedIdControllerProvider(id: linkedFrom?.id))
        .value;

    final showRecordIcon =
        item is JournalEntry &&
        (latestLinkedId == item.id || linkedFrom == null);

    var displayed = item;
    var isRecording = false;

    if (recording != null && recording.meta.id == item.meta.id) {
      displayed = recording;
      isRecording = true;
    }

    final labelColor = isRecording
        ? context.colorScheme.error
        : context.colorScheme.outline;

    final saveFn = ref.read(provider.notifier).save;

    return GestureDetector(
      onTap: () => EntryDateTimeMultiPageModal.show(
        entry: item,
        context: context,
      ),
      child: Visibility(
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
            FormattedTime(labelColor: labelColor, displayed: displayed),
            Visibility(
              visible: isRecent && showRecordIcon && !isRecording,
              child: IconButton(
                icon: const Icon(Icons.fiber_manual_record_sharp),
                iconSize: 20,
                tooltip: context.messages.addActionAddTimeRecording,
                color: context.colorScheme.error,
                onPressed: () {
                  if (entry != null) {
                    // Clear immediately so the rate button hides
                    // without waiting for the next stream tick
                    ref
                        .read(sessionEndedControllerProvider.notifier)
                        .clearSessionEnded(entryId);
                    _timeService.start(entry, linkedFrom);
                  }
                },
              ),
            ),
            Visibility(
              visible: isRecording,
              child: IconButton(
                icon: const Icon(Icons.stop),
                iconSize: 20,
                tooltip: context.messages.doneButton,
                color: labelColor,
                onPressed: () async {
                  await saveFn(stopRecording: true);
                },
              ),
            ),
            if (sessionJustEnded && !isRecording)
              Flexible(
                child: PulsatingRateButton(
                  entryId: entryId,
                  sessionJustEnded: sessionJustEnded,
                ),
              ),
            const SizedBox(width: 15),
          ],
        ),
      ),
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
    final style = monoTabularStyle(fontSize: fontSizeMedium, color: labelColor);
    final text = formatDuration(entryDuration(displayed));
    return Text(text, style: style);
  }
}
