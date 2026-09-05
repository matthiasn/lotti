import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/header/estimate_quick_pick_chips.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

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
        onQuickPick: (duration) async {
          // Pop first, then write — the same order `Clear` uses below, so the
          // modal never sits open over an awaited save.
          Navigator.of(modalContext).pop();
          if (duration != initialDuration) {
            await onEstimateChanged(duration);
          }
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

/// The estimate picker's body: a row of one-tap quick-pick chips over the
/// duration wheel.
///
/// The chips answer the common case — the handful of durations this user
/// actually estimates in — and commit on tap. The wheel below stays for
/// everything else, and is deliberately unframed: it is the fallback now, and
/// a bordered card around it made the escape hatch the largest object in the
/// modal.
class _EstimatedTimePicker extends StatefulWidget {
  const _EstimatedTimePicker({
    required this.initialDuration,
    required this.onDurationChanged,
    required this.onQuickPick,
  });

  final Duration initialDuration;
  final void Function(Duration) onDurationChanged;
  final ValueChanged<Duration> onQuickPick;

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The wheel's draft, not the value the modal opened on: spinning the
        // wheel moves the selected chip with it, so the row and the wheel
        // never claim two different estimates at once.
        EstimateQuickPickChips(
          currentEstimate: _selectedDuration,
          onPick: widget.onQuickPick,
        ),
        // A gap larger than anything inside either element is the whole
        // separation the two groups need — no divider, no second card.
        SizedBox(height: tokens.spacing.sectionGap),
        DesignSystemDurationWheel(
          initialDuration: widget.initialDuration,
          semanticsLabel:
              '${context.messages.taskEstimateModalTitle}: $durationLabel',
          semanticsLiveRegion: true,
          onDurationChanged: (duration) {
            setState(() => _selectedDuration = duration);
            widget.onDurationChanged(duration);
          },
        ),
      ],
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
        leadingIcon: LottiIcons.confirm,
        size: DesignSystemButtonSize.large,
        fullWidth: true,
        onPressed: onDone,
      ),
    );
  }
}
