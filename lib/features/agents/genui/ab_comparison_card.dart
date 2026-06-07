import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';

/// Self-contained A/B comparison card showing two full option texts as
/// tappable cards. The user reads both phrasings and taps "Choose" on the
/// one they prefer — no surrounding text needed.
class ABComparisonCard extends StatefulWidget {
  const ABComparisonCard({
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.onSelect,
    this.labelA = 'A',
    this.labelB = 'B',
    super.key,
  });

  final String question;
  final String optionA;
  final String optionB;
  final String labelA;
  final String labelB;
  final ValueChanged<String> onSelect;

  @override
  State<ABComparisonCard> createState() => _ABComparisonCardState();
}

class _ABComparisonCardState extends State<ABComparisonCard> {
  bool _submitted = false;
  String? _selectedOption;

  @override
  void didUpdateWidget(covariant ABComparisonCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.optionA != widget.optionA ||
        oldWidget.optionB != widget.optionB ||
        oldWidget.question != widget.question ||
        oldWidget.labelA != widget.labelA ||
        oldWidget.labelB != widget.labelB;
    if (changed) {
      _submitted = false;
      _selectedOption = null;
    }
  }

  void _handleSelect(String option, String value) {
    if (_submitted) return;
    setState(() {
      _submitted = true;
      _selectedOption = option;
    });
    widget.onSelect(value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ModernBaseCard(
        backgroundColor: colorScheme.surfaceContainerLow,
        borderColor: colorScheme.outlineVariant.withValues(alpha: 0.45),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModernIconContainer(
                  icon: Icons.compare_arrows_rounded,
                  isCompact: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.question,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildOptionCard(
              context,
              option: 'a',
              label: widget.labelA,
              text: widget.optionA,
            ),
            const SizedBox(height: 12),
            _buildOptionCard(
              context,
              option: 'b',
              label: widget.labelB,
              text: widget.optionB,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String option,
    required String label,
    required String text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isSelected = _selectedOption == option;
    final optionUpper = option.toUpperCase();
    final buttonLabel = context.messages.agentABComparisonChoose(optionUpper);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.messages.agentABComparisonOption(optionUpper),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '· $label',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (isSelected) ...[
                const Spacer(),
                Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: DesignSystemButton(
              onPressed: _submitted
                  ? null
                  : () {
                      final base = context.messages.agentABComparisonPrefer(
                        optionUpper,
                      );
                      final value = label.isNotEmpty ? '$base — $label' : base;
                      _handleSelect(option, value);
                    },
              label: isSelected
                  ? context.messages.agentBinaryChoiceYes
                  : buttonLabel,
              variant: isSelected
                  ? DesignSystemButtonVariant.primary
                  : DesignSystemButtonVariant.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget-specific helpers ────────────────────────────────────────────────
