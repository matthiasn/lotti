import 'package:flutter/cupertino.dart';
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
