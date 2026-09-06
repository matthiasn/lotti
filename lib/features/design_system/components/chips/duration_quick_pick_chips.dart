import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// A one-tap row of durations above a duration wheel: the handful of values
/// this user reaches for most, as outline [DsPill]s in a [Wrap] so a long
/// locale or large accessibility text runs to a second line rather than
/// clipping. The chip matching the value on show reads selected, so the row
/// doubles as the read-out of what is about to be replaced; while the
/// ranking is still loading, [placeholder] renders as inert outlines so the
/// row keeps its height.
///
/// The host says what a tap means ([hint]) and how a duration reads
/// ([labelOf], [semanticsLabelOf]) — a task estimate and a check-in length
/// share the shape, not the words.
class DurationQuickPickChips extends StatelessWidget {
  const DurationQuickPickChips({
    required this.suggestions,
    required this.placeholder,
    required this.current,
    required this.onPick,
    required this.hint,
    required this.labelOf,
    required this.semanticsLabelOf,
    required this.keyPrefix,
    super.key,
  });

  /// The ranked row, or null while it is still being derived.
  final List<Duration>? suggestions;

  /// What stands in for the row while [suggestions] is null.
  final List<Duration> placeholder;
  final Duration current;
  final ValueChanged<Duration> onPick;
  final String hint;
  final String Function(Duration) labelOf;
  final String Function(String label) semanticsLabelOf;

  /// `<keyPrefix>-<minutes>` on a live chip, `<keyPrefix>-placeholder-<minutes>`
  /// while loading, so a host's tests can name the chip they mean.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    final suggestions = this.suggestions;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          hint,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: tokens.spacing.step4,
          runSpacing: tokens.spacing.step4,
          children: suggestions == null
              ? [
                  for (final duration in placeholder)
                    DsPill(
                      key: ValueKey(
                        '$keyPrefix-placeholder-${duration.inMinutes}',
                      ),
                      variant: DsPillVariant.outline,
                      color: tokens.colors.decorative.level03,
                      labelColor: tokens.colors.text.lowEmphasis,
                      label: labelOf(duration),
                    ),
                ]
              : [
                  for (final duration in suggestions)
                    _DurationChip(
                      key: ValueKey('$keyPrefix-${duration.inMinutes}'),
                      label: labelOf(duration),
                      semanticsLabel: semanticsLabelOf(labelOf(duration)),
                      accent: accent,
                      selected: duration == current,
                      onPick: () => onPick(duration),
                    ),
                ],
        ),
      ],
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.semanticsLabel,
    required this.accent,
    required this.selected,
    required this.onPick,
    super.key,
  });

  final String label;
  final String semanticsLabel;
  final Color accent;
  final bool selected;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: semanticsLabel,
    onTap: onPick,
    excludeSemantics: true,
    child: DsPill(
      variant: DsPillVariant.outline,
      color: accent,
      selected: selected,
      label: label,
      onTap: onPick,
    ),
  );
}
