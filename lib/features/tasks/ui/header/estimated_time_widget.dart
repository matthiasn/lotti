import 'package:flutter/cupertino.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
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
    stickyActionBarBuilder: (modalContext) => _EstimatedTimeStickyActionBar(
      onCancel: () => Navigator.of(modalContext).pop(),
      onDone: () async {
        Navigator.of(modalContext).pop();
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
    return DesignSystemModalActionBar(
      glass: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      secondary: [
        DesignSystemButton(
          label: context.messages.cancelButton,
          variant: DesignSystemButtonVariant.secondary,
          size: DesignSystemButtonSize.large,
          onPressed: onCancel,
        ),
      ],
      primary: DesignSystemButton(
        label: context.messages.doneButton,
        size: DesignSystemButtonSize.large,
        fullWidth: true,
        onPressed: onDone,
      ),
    );
  }
}
