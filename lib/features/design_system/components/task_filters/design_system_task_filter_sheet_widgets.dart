part of 'design_system_task_filter_sheet.dart';

class _TaskFilterNavigationField extends StatelessWidget {
  const _TaskFilterNavigationField({
    required this.field,
    required this.onTap,
    super.key,
  });

  final DesignSystemTaskFilterFieldState field;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final selected = field.selectedOptions;
    final summary = switch (selected) {
      [] => context.messages.tasksPriorityFilterAll,
      [final only] => only.label,
      [final first, final second] => '${first.label}, ${second.label}',
      [final first, final second, ...final rest] =>
        '${first.label}, ${second.label} +${rest.length}',
    };

    return DesignSystemSelectionRow(
      title: field.label,
      subtitle: summary,
      size: DesignSystemListItemSize.small,
      type: DesignSystemSelectionRowType.navigation,
      semanticLabel: '${field.label}, $summary',
      onTap: onTap,
    );
  }
}

class _TaskFilterChoiceSection extends StatelessWidget {
  const _TaskFilterChoiceSection({
    required this.label,
    required this.children,
    this.compact = false,
  });

  final String label;
  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _TaskFilterSectionLabel(text: label),
        SizedBox(height: spacing.step3),
        Wrap(
          spacing: compact ? spacing.step2 : spacing.step3,
          runSpacing: spacing.step2,
          children: children,
        ),
      ],
    );
  }
}

class _TaskFilterPriorityGlyph extends StatelessWidget {
  const _TaskFilterPriorityGlyph({required this.glyph});

  final DesignSystemTaskFilterGlyph glyph;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final (icon, color) = switch (glyph) {
      DesignSystemTaskFilterGlyph.priorityP0 => (
        Icons.new_releases_rounded,
        tokens.colors.alert.error.defaultColor,
      ),
      DesignSystemTaskFilterGlyph.priorityP1 => (
        Icons.signal_cellular_alt_rounded,
        tokens.colors.alert.warning.defaultColor,
      ),
      DesignSystemTaskFilterGlyph.priorityP2 => (
        Icons.signal_cellular_alt_2_bar_rounded,
        tokens.colors.alert.info.defaultColor,
      ),
      DesignSystemTaskFilterGlyph.priorityP3 => (
        Icons.signal_cellular_alt_1_bar_rounded,
        tokens.colors.alert.success.defaultColor,
      ),
      DesignSystemTaskFilterGlyph.none => (
        Icons.remove_rounded,
        tokens.colors.text.mediumEmphasis,
      ),
    };
    return Icon(icon, color: color, size: tokens.spacing.step5);
  }
}

class _TaskFilterSectionLabel extends StatelessWidget {
  const _TaskFilterSectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Text(
      text,
      style: tokens.typography.styles.subtitle.subtitle2.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }
}

class _TaskFilterToggleGroup extends StatelessWidget {
  const _TaskFilterToggleGroup({
    required this.toggles,
    required this.onChanged,
  });

  final List<DesignSystemTaskFilterToggle> toggles;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < toggles.length; index++) ...[
          DesignSystemFilterToggleRow(
            key: ValueKey(
              'design-system-task-filter-toggle-${toggles[index].id}',
            ),
            label: toggles[index].label,
            value: toggles[index].value,
            onChanged: (_) => onChanged(toggles[index].id),
          ),
          if (index != toggles.length - 1) SizedBox(height: spacing.step1),
        ],
      ],
    );
  }
}
