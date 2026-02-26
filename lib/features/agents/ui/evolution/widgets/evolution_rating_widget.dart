import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Gradient slider for rating the template's performance during approval.
///
/// Track color goes from red (0.0, "Needs work") through yellow (0.5,
/// "Adequate") to green (1.0, "Excellent"). Provides haptic feedback on
/// 0.1 increments.
class EvolutionRatingWidget extends StatefulWidget {
  const EvolutionRatingWidget({
    required this.onRatingChanged,
    this.initialRating = 0.5,
    super.key,
  });

  final ValueChanged<double> onRatingChanged;
  final double initialRating;

  @override
  State<EvolutionRatingWidget> createState() => _EvolutionRatingWidgetState();
}

class _EvolutionRatingWidgetState extends State<EvolutionRatingWidget> {
  late double _value;
  int _lastHapticTick = -1;

  @override
  void initState() {
    super.initState();
    _value = widget.initialRating;
  }

  void _onChanged(double newValue) {
    final tick = (newValue * 10).round();
    if (tick != _lastHapticTick) {
      _lastHapticTick = tick;
      HapticFeedback.selectionClick();
    }
    setState(() => _value = newValue);
    widget.onRatingChanged(newValue);
  }

  Color _trackColor(double value) {
    if (value < 0.5) {
      return Color.lerp(
        GameyColors.primaryRed,
        GameyColors.primaryOrange,
        value * 2,
      )!;
    }
    return Color.lerp(
      GameyColors.primaryOrange,
      GameyColors.primaryGreen,
      (value - 0.5) * 2,
    )!;
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          messages.agentEvolutionRatingPrompt,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        // Percentage display
        Center(
          child: Text(
            '${(_value * 100).round()}%',
            style: TextStyle(
              color: _trackColor(_value),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            activeTrackColor: _trackColor(_value),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            thumbColor: _trackColor(_value),
            overlayColor: _trackColor(_value).withValues(alpha: 0.2),
            thumbShape: const RoundSliderThumbShape(),
          ),
          child: Slider(
            value: _value,
            onChanged: _onChanged,
          ),
        ),
        // Labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                messages.agentEvolutionRatingNeedsWork,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
              Text(
                messages.agentEvolutionRatingAdequate,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
              Text(
                messages.agentEvolutionRatingExcellent,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
