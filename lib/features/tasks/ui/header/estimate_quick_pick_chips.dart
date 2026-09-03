import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/state/task_estimate_suggestions_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The estimate picker's one-tap row: the durations this user reaches for
/// most, as chips above the duration wheel.
///
/// The same affordance the habit completion sheet gives a measurable — an
/// outline [DsPill] per value, in a [Wrap] so a long locale or large
/// accessibility text runs to a second line rather than clipping. Two
/// differences, both because an estimate is a single value rather than a
/// stream of recordings:
///
/// * **No "+ Other" chip.** The measurement row needs one because its full
///   capture lives in another modal; here the wheel is directly beneath, and
///   a second route to it would be noise.
/// * **The chip matching the value on show reads selected**, so the row
///   doubles as the read-out of what is about to be replaced. A measurement
///   chip appends; this one overwrites, and the user should see what they are
///   overwriting.
///
/// A tap commits — [onPick] writes the estimate and closes the modal — which
/// is the whole point: the common case costs one tap, not a scroll plus a
/// confirm. Labels use [formatRangeDuration], the same compact form the task
/// header reads the estimate back in, so tapping `2h` produces a header that
/// says `2h`.
///
/// The gap between chips is `spacing.step3`, one step wider than the habit
/// row's: duration labels are short enough that at `step2` four of them read
/// as one segmented control rather than four choices.
class EstimateQuickPickChips extends ConsumerWidget {
  const EstimateQuickPickChips({
    required this.currentEstimate,
    required this.onPick,
    super.key,
  });

  /// The estimate currently on show — the task's own as the modal opens, then
  /// whatever the wheel is spun to. The chip carrying it reads selected, so
  /// the row and the wheel never state two different answers to "what is the
  /// estimate". `Duration.zero` (no estimate) matches no chip, since zero is
  /// never suggested.
  final Duration currentEstimate;

  final ValueChanged<Duration> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final suggestions = ref
        .watch(taskEstimateSuggestionsControllerProvider)
        .value;
    final accent = tokens.colors.interactive.enabled;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // What a tap does, said out loud, naming the outcome rather than
        // the gesture. A chip saves and closes while a Done button sits at
        // the bottom of the same sheet — without this line the row reads as
        // a staging control, and the users most wary of an irreversible tap
        // were the ones who would not risk it.
        Text(
          context.messages.taskEstimateQuickPickHint,
          // Centred over a centred row: at large accessibility text, or in a
          // locale whose wording is longer, this line wraps and its second
          // line would otherwise sit left of the chips it describes.
          textAlign: TextAlign.center,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        _chipRow(tokens, accent, suggestions),
      ],
    );
  }

  /// The chips themselves: the ranking once it lands, the design system's
  /// placeholder variant until then.
  Widget _chipRow(
    DsTokens tokens,
    Color accent,
    List<Duration>? suggestions,
  ) {
    return Wrap(
      alignment: WrapAlignment.center,
      // step4, not step3: at step3 the gap between chips equalled DsPill's
      // own interior padding, and four short duration labels read as one
      // segmented control rather than four choices.
      spacing: tokens.spacing.step4,
      runSpacing: tokens.spacing.step4,
      children: suggestions == null
          // The row's shape while the ranking loads. A blank strip would
          // open the modal's lead control as a hole, and would be the wrong
          // height once accessibility text wraps the real row to two lines.
          //
          // Quiet outline rather than `DsPillVariant.muted`: the dashed
          // muted shell is this app's "unset — tap me to fill" vocabulary
          // (the task header's own category and due-date offers wear it),
          // and these placeholders are inert.
          ? [
              for (final duration in kDefaultEstimateSuggestions)
                DsPill(
                  key: ValueKey(
                    'estimate-quick-pick-placeholder-'
                    '${duration.inMinutes}',
                  ),
                  variant: DsPillVariant.outline,
                  color: tokens.colors.decorative.level03,
                  labelColor: tokens.colors.text.lowEmphasis,
                  label: formatRangeDuration(duration),
                ),
            ]
          : [
              for (final duration in suggestions)
                // Keyed on whole minutes, which `getRankedTaskEstimates`
                // guarantees: it ranks only whole-minute durations, so two
                // suggestions can never collapse to the same key (or to the
                // same label) here.
                _EstimateChip(
                  key: ValueKey('estimate-quick-pick-${duration.inMinutes}'),
                  duration: duration,
                  accent: accent,
                  selected: duration == currentEstimate,
                  onPick: onPick,
                ),
            ],
    );
  }
}

class _EstimateChip extends StatelessWidget {
  const _EstimateChip({
    required this.duration,
    required this.accent,
    required this.selected,
    required this.onPick,
    super.key,
  });

  final Duration duration;
  final Color accent;
  final bool selected;
  final ValueChanged<Duration> onPick;

  @override
  Widget build(BuildContext context) {
    final label = formatRangeDuration(duration);
    void pick() => onPick(duration);
    return Semantics(
      button: true,
      selected: selected,
      label: context.messages.taskEstimateQuickPickSemanticsLabel(label),
      // The node carries the tap itself: `excludeSemantics` drops the
      // InkWell's own action, and without this the row's whole point — one
      // tap to the estimate — would not be activatable from a screen reader.
      onTap: pick,
      excludeSemantics: true,
      child: DsPill(
        variant: DsPillVariant.outline,
        color: accent,
        // Fill, full-alpha border and a bold label — three channels, two of
        // them luminance rather than hue. No leading glyph: a tick would say
        // the same thing a fourth time, and an icon appearing and vanishing
        // shifts a chip by its whole width plus a gap every time the wheel
        // moves the selection. (The bold weight does widen the label a
        // little; that is a glyph-advance nudge, not a re-layout.)
        selected: selected,
        label: label,
        onTap: pick,
      ),
    );
  }
}
