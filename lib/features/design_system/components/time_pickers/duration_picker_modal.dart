import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the one-tap row above the wheel for [current], with [onQuickPick]
/// committing and closing.
typedef DurationQuickPicksBuilder =
    Widget Function(
      BuildContext context,
      Duration current,
      ValueChanged<Duration> onQuickPick,
    );

/// A duration picker modal: a host-supplied row of quick picks over the
/// design-system duration wheel, with *Done* committing the wheel and
/// *Clear* (only when there is something to clear) committing zero.
///
/// One shape for a task's estimate and a check-in's length: the host names
/// the modal, reads the wheel's draft back for accessibility through
/// [semanticsLabelOf], and supplies the chips.
Future<void> showDurationPicker({
  required BuildContext context,
  required String title,
  required Duration initialDuration,
  required DurationQuickPicksBuilder quickPicks,
  required String Function(Duration) semanticsLabelOf,
  required Future<void> Function(Duration duration) onDurationChanged,
}) async {
  final tokens = context.designTokens;
  var selectedDuration = initialDuration;
  await ModalUtils.showSinglePageModal<void>(
    context: context,
    builder: (modalContext) => _DurationPickerBody(
      initialDuration: initialDuration,
      quickPicks: quickPicks,
      semanticsLabelOf: semanticsLabelOf,
      onDurationChanged: (duration) => selectedDuration = duration,
      onQuickPick: (duration) async {
        // Pop first, then write — the same order Clear uses below, so the
        // modal never sits open over an awaited save.
        Navigator.of(modalContext).pop();
        if (duration != initialDuration) await onDurationChanged(duration);
      },
    ),
    title: title,
    padding: EdgeInsets.fromLTRB(
      tokens.spacing.step5,
      tokens.spacing.step5,
      tokens.spacing.step5,
      tokens.spacing.step11 + tokens.spacing.step6,
    ),
    stickyActionBarBuilder: (modalContext) => _DurationPickerActionBar(
      title: title,
      onClear: initialDuration == Duration.zero
          ? null
          : () async {
              Navigator.of(modalContext).pop();
              await onDurationChanged(Duration.zero);
            },
      onDone: () async {
        Navigator.of(modalContext).pop();
        if (selectedDuration != initialDuration) {
          await onDurationChanged(selectedDuration);
        }
      },
    ),
  );
}

/// The quick picks over the wheel. The wheel is deliberately unframed: it is
/// the fallback, and a bordered card around it made the escape hatch the
/// largest object in the modal.
class _DurationPickerBody extends StatefulWidget {
  const _DurationPickerBody({
    required this.initialDuration,
    required this.quickPicks,
    required this.semanticsLabelOf,
    required this.onDurationChanged,
    required this.onQuickPick,
  });

  final Duration initialDuration;
  final DurationQuickPicksBuilder quickPicks;
  final String Function(Duration) semanticsLabelOf;
  final ValueChanged<Duration> onDurationChanged;
  final ValueChanged<Duration> onQuickPick;

  @override
  State<_DurationPickerBody> createState() => _DurationPickerBodyState();
}

class _DurationPickerBodyState extends State<_DurationPickerBody> {
  late Duration _selectedDuration = widget.initialDuration;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The wheel's draft, not the value the modal opened on: spinning the
        // wheel moves the selected chip with it, so the row and the wheel
        // never claim two different values at once.
        widget.quickPicks(context, _selectedDuration, widget.onQuickPick),
        // A gap larger than anything inside either element is the whole
        // separation the two groups need — no divider, no second card.
        SizedBox(height: tokens.spacing.sectionGap),
        DesignSystemDurationWheel(
          initialDuration: widget.initialDuration,
          semanticsLabel: widget.semanticsLabelOf(_selectedDuration),
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

class _DurationPickerActionBar extends StatelessWidget {
  const _DurationPickerActionBar({
    required this.title,
    required this.onClear,
    required this.onDone,
  });

  final String title;
  final VoidCallback? onClear;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return DesignSystemModalActionBar(
      glass: true,
      padding: EdgeInsets.all(tokens.spacing.step5),
      secondary: [
        if (onClear != null)
          DesignSystemButton(
            label: messages.clearButton,
            semanticsLabel: '${messages.clearButton} $title',
            variant: DesignSystemButtonVariant.secondary,
            size: DesignSystemButtonSize.large,
            onPressed: onClear,
          ),
      ],
      primary: DesignSystemButton(
        label: messages.doneButton,
        leadingIcon: LottiIcons.confirm,
        size: DesignSystemButtonSize.large,
        fullWidth: true,
        onPressed: onDone,
      ),
    );
  }
}
