import 'package:flutter/material.dart';
import 'package:lotti/themes/gamey/colors.dart';
import 'package:lotti/themes/gamey/gradients.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

/// A single metric card in the evolution dashboard header.
///
/// Displays a large value with a small label, an accent-colored icon, and a
/// dark gradient background. Optionally shows a circular progress overlay
/// for percentage-based metrics.
class EvolutionMetricTile extends StatelessWidget {
  const EvolutionMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor = GameyColors.aiCyan,
    this.progress,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  /// If non-null, shows a circular progress indicator (0.0–1.0).
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return ModernBaseCard(
      gradient: GameyGradients.cardDark(accentColor),
      customShadows: [
        BoxShadow(
          color: accentColor.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const Spacer(),
              if (progress != null)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(accentColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
