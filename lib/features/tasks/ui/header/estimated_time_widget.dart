import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

Future<void> showEstimatePicker({
  required BuildContext context,
  required Duration initialDuration,
  required Future<void> Function(Duration newDuration) onEstimateChanged,
}) async {
  var selectedDuration = initialDuration;

  await ModalUtils.showSinglePageModal<void>(
    context: context,
    builder: (modalContext) {
      return _EstimatedTimePicker(
        initialDuration: initialDuration,
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
        if (selectedDuration != initialDuration) {
          await onEstimateChanged(selectedDuration);
        }
      },
    ),
    padding: const EdgeInsets.only(bottom: 40),
  );
}

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
    final rawEstimate = task.data.estimate;
    final hasEstimate = rawEstimate != null;
    final estimate = rawEstimate ?? Duration.zero;
    final formattedEstimate =
        hasEstimate ? formatDuration(estimate).substring(0, 5) : null;

    Future<void> onTap() async {
      await showEstimatePicker(
        context: context,
        initialDuration: estimate,
        onEstimateChanged: (newDuration) async {
          await save(estimate: newDuration);
        },
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
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasEstimate && formattedEstimate != null)
                Text(
                  formattedEstimate,
                  style: context.textTheme.titleMedium,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color:
                        context.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                  ),
                  child: Text(
                    context.messages.taskNoEstimateLabel,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant.withValues(
                        alpha: AppTheme.alphaSurfaceVariant,
                      ),
                    ),
                  ),
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
            child: LottiSecondaryButton(
              label: context.messages.cancelButton,
              onPressed: onCancel,
              fullWidth: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LottiPrimaryButton(
              onPressed: onDone,
              label: context.messages.doneButton,
            ),
          ),
        ],
      ),
    );
  }
}
