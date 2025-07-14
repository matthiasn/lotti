import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class EstimatedTimeWidget extends ConsumerWidget {
  const EstimatedTimeWidget({
    required this.task,
    required this.save,
    super.key,
  });

  final Task task;
  final Future<void> Function({Duration? estimate, bool stopRecording}) save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimate = task.data.estimate ?? Duration.zero;
    final formattedEstimate = formatDuration(estimate).substring(0, 5);

    Future<void> onTap() async {
      var selectedDuration = estimate;

      await ModalUtils.showSinglePageModal<void>(
        context: context,
        builder: (modalContext) {
          return _EstimatedTimePicker(
            initialDuration: estimate,
            onDurationChanged: (duration) {
              selectedDuration = duration;
            },
          );
        },
        title: context.messages.taskEstimateLabel,
        stickyActionBar: _EstimatedTimeStickyActionBar(
          onCancel: () => Navigator.of(context).pop(),
          onDone: () async {
            Navigator.of(context).pop();
            if (selectedDuration != estimate) {
              await save(estimate: selectedDuration);
            }
          },
        ),
        padding: const EdgeInsets.only(bottom: 40),
      );
    }

    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.taskEstimateLabel,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                formattedEstimate,
                style: context.textTheme.titleMedium,
              ),
              TimeRecordingIcon(
                taskId: task.id,
                padding: const EdgeInsets.only(left: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The time picker widget for selecting estimated duration
class _EstimatedTimePicker extends StatefulWidget {
  const _EstimatedTimePicker({
    required this.initialDuration,
    required this.onDurationChanged,
  });

  final Duration initialDuration;
  final void Function(Duration) onDurationChanged;

  @override
  State<_EstimatedTimePicker> createState() => _EstimatedTimePickerState();
}

class _EstimatedTimePickerState extends State<_EstimatedTimePicker> {
  @override
  void initState() {
    super.initState();
    // Pass initial value to callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDurationChanged(widget.initialDuration);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: CupertinoThemeData(
        textTheme: CupertinoTextThemeData(
          pickerTextStyle: context.textTheme.titleLarge?.withTabularFigures,
        ),
      ),
      child: SizedBox(
        height: 265,
        child: CupertinoTimerPicker(
          onTimerDurationChanged: widget.onDurationChanged,
          initialTimerDuration: widget.initialDuration,
          mode: CupertinoTimerPickerMode.hm,
        ),
      ),
    );
  }
}

/// Sticky action bar for the estimated time selection modal
class _EstimatedTimeStickyActionBar extends StatelessWidget {
  const _EstimatedTimeStickyActionBar({
    required this.onCancel,
    required this.onDone,
  });

  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: context.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                context.messages.cancelButton,
                style: TextStyle(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: onDone,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(context.messages.doneButton),
            ),
          ),
        ],
      ),
    );
  }
}
