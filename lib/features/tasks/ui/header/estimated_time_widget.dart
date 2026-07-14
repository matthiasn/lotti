import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

Future<void> showEstimatePicker({
  required BuildContext context,
  required Duration initialDuration,
  required Future<void> Function(Duration newDuration) onEstimateChanged,
}) async {
  final tokens = context.designTokens;
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
    title: context.messages.taskEstimateModalTitle,
    padding: EdgeInsets.fromLTRB(
      tokens.spacing.step5,
      tokens.spacing.step5,
      tokens.spacing.step5,
      tokens.spacing.step11 + tokens.spacing.step6,
    ),
    stickyActionBarBuilder: (modalContext) => _EstimatedTimeStickyActionBar(
      onClear: initialDuration == Duration.zero
          ? null
          : () async {
              Navigator.of(modalContext).pop();
              await onEstimateChanged(Duration.zero);
            },
      onDone: () async {
        Navigator.of(modalContext).pop();
        if (selectedDuration != initialDuration) {
          await onEstimateChanged(selectedDuration);
        }
      },
    ),
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
  late Duration _selectedDuration;

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.initialDuration;
    // Pass initial value to callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDurationChanged(widget.initialDuration);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final durationLabel = context.messages
        .designSystemMyDailyDurationHoursMinutesCompact(
          _selectedDuration.inHours,
          _selectedDuration.inMinutes.remainder(60),
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: DesignSystemDurationWheel(
          initialDuration: widget.initialDuration,
          semanticsLabel:
              '${context.messages.taskEstimateModalTitle}: $durationLabel',
          semanticsLiveRegion: true,
          onDurationChanged: (duration) {
            setState(() => _selectedDuration = duration);
            widget.onDurationChanged(duration);
          },
        ),
      ),
    );
  }
}

/// Sticky action bar for the estimated time selection modal
class _EstimatedTimeStickyActionBar extends StatelessWidget {
  const _EstimatedTimeStickyActionBar({
    required this.onClear,
    required this.onDone,
  });

  final VoidCallback? onClear;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemModalActionBar(
      glass: true,
      padding: EdgeInsets.all(tokens.spacing.step5),
      secondary: [
        if (onClear != null)
          DesignSystemButton(
            label: context.messages.clearButton,
            semanticsLabel:
                '${context.messages.clearButton} '
                '${context.messages.taskEstimateModalTitle}',
            variant: DesignSystemButtonVariant.secondary,
            size: DesignSystemButtonSize.large,
            onPressed: onClear,
          ),
      ],
      primary: DesignSystemButton(
        label: context.messages.doneButton,
        leadingIcon: Icons.check_rounded,
        size: DesignSystemButtonSize.large,
        fullWidth: true,
        onPressed: onDone,
      ),
    );
  }
}
