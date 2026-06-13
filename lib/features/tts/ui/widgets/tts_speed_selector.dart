import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';

/// Segmented playback-speed control over [kTtsSpeedSequence] (0.5×–2×).
///
/// The active step is filled with the accent color; the row wraps to a second
/// line rather than truncating under large text. Each segment is a ≥44pt hit
/// target and carries a semantic label.
class TtsSpeedSelector extends StatelessWidget {
  const TtsSpeedSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;

  static String formatSpeed(double speed) {
    final text = speed == speed.roundToDouble()
        ? speed.toInt().toString()
        : speed.toString();
    return '$text×';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;

    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: [
        for (final speed in kTtsSpeedSequence)
          _SpeedSegment(
            label: formatSpeed(speed),
            selected: speed == value,
            onTap: () => onChanged(speed),
            accent: ai.accent,
            accentSoft: ai.accentSoft,
            border: ai.border,
            selectedGlyph: ai.background,
            bodyText: ai.bodyText,
            textStyle: tokens.typography.styles.others.caption,
          ),
      ],
    );
  }
}

class _SpeedSegment extends StatelessWidget {
  const _SpeedSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
    required this.accentSoft,
    required this.border,
    required this.selectedGlyph,
    required this.bodyText,
    required this.textStyle,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final Color accentSoft;
  final Color border;
  final Color selectedGlyph;
  final Color bodyText;
  final TextStyle textStyle;

  static const double _minTarget = 44;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(_minTarget / 2),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _minTarget,
                minHeight: _minTarget,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? accent : accentSoft,
                  borderRadius: BorderRadius.circular(_minTarget / 2),
                  border: Border.all(color: selected ? accent : border),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.designTokens.spacing.step4,
                    ),
                    child: Text(
                      label,
                      style: textStyle.copyWith(
                        color: selected ? selectedGlyph : bodyText,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
