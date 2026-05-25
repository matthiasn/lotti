import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Teal-tinted "✦ REASONING" card on the Drafting screen.
///
/// Renders the lines the agent has emitted so far. The most-recent
/// line is highlighted with a pulsing teal dot (driven internally by
/// an animation controller) and high-emphasis text. Older lines fade
/// to medium emphasis.
class ReasoningPanel extends StatelessWidget {
  const ReasoningPanel({required this.lines, super.key});

  final List<ReasoningLine> lines;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    return Container(
      decoration: BoxDecoration(
        color: teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: teal.withValues(alpha: 0.18)),
      ),
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.dailyOsNextDraftingReasoningOverline,
            style: tokens.typography.styles.others.overline.copyWith(
              color: teal,
            ),
          ),
          SizedBox(height: tokens.spacing.step4),
          for (final (index, line) in lines.indexed) ...[
            _ReasoningRow(
              line: line,
              isActive: index == lines.length - 1,
            ),
            if (index < lines.length - 1)
              SizedBox(height: tokens.spacing.step3),
          ],
        ],
      ),
    );
  }
}

class _ReasoningRow extends StatefulWidget {
  const _ReasoningRow({required this.line, required this.isActive});

  final ReasoningLine line;
  final bool isActive;

  @override
  State<_ReasoningRow> createState() => _ReasoningRowState();
}

class _ReasoningRowState extends State<_ReasoningRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isActive) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant _ReasoningRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.isActive && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  IconData _iconFor(ReasoningIcon icon) {
    switch (icon) {
      case ReasoningIcon.review:
        return Icons.history_rounded;
      case ReasoningIcon.calendar:
        return Icons.event_rounded;
      case ReasoningIcon.shield:
        return Icons.shield_outlined;
      case ReasoningIcon.energy:
        return Icons.bolt_rounded;
      case ReasoningIcon.balance:
        return Icons.balance_rounded;
      case ReasoningIcon.ready:
        return Icons.check_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final isReady = widget.line.icon == ReasoningIcon.ready;
    final color = widget.isActive || isReady
        ? (isReady ? teal : tokens.colors.text.highEmphasis)
        : tokens.colors.text.lowEmphasis;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: teal.withValues(alpha: widget.isActive ? 0.18 : 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(_iconFor(widget.line.icon), size: 12, color: teal),
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            widget.line.text,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: color,
              fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        if (widget.isActive && !isReady)
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              return Opacity(
                opacity: 0.4 + 0.6 * (1 - (_pulse.value - 0.5).abs() * 2),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: teal,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
