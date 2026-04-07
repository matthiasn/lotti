import 'package:flutter/material.dart';
import 'package:lotti/features/agents/genui/evolution_catalog_helpers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/colors.dart';
import 'package:lotti/themes/gamey/gradients.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';

/// Expandable card showing a recorded evolution note.
///
/// Starts collapsed (2 lines max) and expands to show the full content on tap.
class EvolutionNoteConfirmationCard extends StatefulWidget {
  const EvolutionNoteConfirmationCard({
    required this.kind,
    required this.content,
    super.key,
  });

  final String kind;
  final String content;

  @override
  State<EvolutionNoteConfirmationCard> createState() =>
      _EvolutionNoteConfirmationCardState();
}

class _EvolutionNoteConfirmationCardState
    extends State<EvolutionNoteConfirmationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: ModernBaseCard(
          gradient: GameyGradients.cardDark(GameyColors.aiCyan),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _noteKindIcon(widget.kind),
                size: 18,
                color: GameyColors.aiCyan,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.messages.agentEvolutionNoteRecorded,
                            style: const TextStyle(
                              color: GameyColors.aiCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 200),
                      crossFadeState: _expanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: Text(
                        widget.content,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      secondChild: Text(
                        widget.content,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stateful card that renders star ratings for each feedback category.
class CategoryRatingsCard extends StatefulWidget {
  const CategoryRatingsCard({
    required this.categories,
    required this.onSubmit,
    super.key,
  });

  final List<Map<String, Object?>> categories;
  final void Function(Map<String, int> ratings) onSubmit;

  @override
  State<CategoryRatingsCard> createState() => _CategoryRatingsCardState();
}

class _CategoryRatingsCardState extends State<CategoryRatingsCard> {
  late List<String> _categoryKeys;
  late Map<String, int> _ratings;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _initializeCategoryState();
  }

  @override
  void didUpdateWidget(covariant CategoryRatingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameCategorySpec(oldWidget.categories, widget.categories)) {
      _initializeCategoryState();
    }
  }

  /// Returns true when both lists describe the same categories (by name).
  static bool _sameCategorySpec(
    List<Map<String, Object?>> a,
    List<Map<String, Object?>> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (readString(a[i], 'name') != readString(b[i], 'name')) return false;
    }
    return true;
  }

  void _initializeCategoryState() {
    final rawNames = widget.categories
        .map((cat) => readString(cat, 'name').trim())
        .toList(growable: false);

    final seen = <String>{};
    _categoryKeys = List<String>.generate(rawNames.length, (index) {
      var key = rawNames[index];
      if (key.isEmpty) {
        key = 'category_$index';
        debugPrint(
          'CategoryRatings received empty category name at index $index; '
          'using "$key".',
        );
      }
      if (seen.contains(key)) {
        final disambiguated = '${key}_$index';
        debugPrint(
          'CategoryRatings received duplicate category name "$key"; '
          'using "$disambiguated".',
        );
        key = disambiguated;
      }
      seen.add(key);
      return key;
    });

    _ratings = {
      for (final key in _categoryKeys) key: 0,
    };
    _submitted = false;
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
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
                  icon: Icons.star_rounded,
                  isCompact: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        messages.agentCategoryRatingsTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        messages.agentCategoryRatingsSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...widget.categories.asMap().entries.map((entry) {
              final index = entry.key;
              final cat = entry.value;
              final name = _categoryKeys[index];
              final label = readString(cat, 'label');
              final rating = _ratings[name] ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(5, (i) {
                          final starIndex = i + 1;
                          final selected = starIndex <= rating;
                          return Semantics(
                            label: messages.agentCategoryRatingsStarLabel(
                              starIndex,
                              5,
                            ),
                            selected: selected,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _submitted
                                  ? null
                                  : () => setState(
                                      () => _ratings[name] = starIndex,
                                    ),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(
                                  selected
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: 26,
                                  color: selected
                                      ? colorScheme.tertiary
                                      : colorScheme.onSurfaceVariant.withValues(
                                          alpha: 0.6,
                                        ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            messages.agentCategoryRatingsScaleMin,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            messages.agentCategoryRatingsScaleMax,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: _submitted
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          messages.agentCategoryRatingsSubmit,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : primaryActionButton(
                      label: messages.agentCategoryRatingsSubmit,
                      onPressed: () {
                        setState(() => _submitted = true);
                        widget.onSubmit(_ratings);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stateful binary choice prompt card with confirm/dismiss buttons.
class BinaryChoicePromptCard extends StatefulWidget {
  const BinaryChoicePromptCard({
    required this.question,
    required this.detail,
    required this.confirmLabel,
    required this.dismissLabel,
    required this.confirmValue,
    required this.dismissValue,
    required this.onSelect,
    super.key,
  });

  final String question;
  final String detail;
  final String confirmLabel;
  final String dismissLabel;
  final String confirmValue;
  final String dismissValue;
  final ValueChanged<String> onSelect;

  @override
  State<BinaryChoicePromptCard> createState() => _BinaryChoicePromptCardState();
}

class _BinaryChoicePromptCardState extends State<BinaryChoicePromptCard> {
  bool _submitted = false;

  @override
  void didUpdateWidget(covariant BinaryChoicePromptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final promptChanged =
        oldWidget.question != widget.question ||
        oldWidget.confirmValue != widget.confirmValue ||
        oldWidget.dismissValue != widget.dismissValue;
    if (promptChanged) {
      _submitted = false;
    }
  }

  void _handleSelect(String value) {
    if (_submitted) return;
    setState(() => _submitted = true);
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
                  icon: Icons.help_outline_rounded,
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
            if (widget.detail.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                widget.detail,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.end,
              children: [
                DesignSystemButton(
                  onPressed: _submitted
                      ? null
                      : () => _handleSelect(widget.dismissValue),
                  label: widget.dismissLabel,
                  variant: DesignSystemButtonVariant.secondary,
                  size: DesignSystemButtonSize.medium,
                ),
                DesignSystemButton(
                  onPressed: _submitted
                      ? null
                      : () => _handleSelect(widget.confirmValue),
                  label: widget.confirmLabel,
                  size: DesignSystemButtonSize.medium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
        oldWidget.question != widget.question;
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
    final buttonLabel = option == 'a' ? 'Choose A' : 'Choose B';

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
                'Option ${option.toUpperCase()}',
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
                  : () => _handleSelect(
                      option,
                      'I prefer Option ${option.toUpperCase()} — $label',
                    ),
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

IconData _noteKindIcon(String kind) {
  return switch (kind) {
    'reflection' => Icons.psychology,
    'hypothesis' => Icons.lightbulb_outline,
    'decision' => Icons.gavel,
    'pattern' => Icons.pattern,
    _ => Icons.note,
  };
}
