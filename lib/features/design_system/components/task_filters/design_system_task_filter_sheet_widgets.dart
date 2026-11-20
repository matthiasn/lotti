part of 'design_system_task_filter_sheet.dart';

class _TaskFilterNavigationField extends StatelessWidget {
  const _TaskFilterNavigationField({
    required this.field,
    required this.onTap,
    this.focusNode,
    super.key,
  });

  final DesignSystemTaskFilterFieldState field;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

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
      focusNode: focusNode,
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
  const _TaskFilterPriorityGlyph({required this.glyph})
    : assert(
        glyph != DesignSystemTaskFilterGlyph.none,
        'Priority glyph widgets require a visible glyph.',
      );

  final DesignSystemTaskFilterGlyph glyph;

  // The same mark the task row and header draw, so a priority picked here
  // looks like the priority it filters for.
  @override
  Widget build(BuildContext context) => DesignSystemPriorityGlyph(
    priority: switch (glyph) {
      DesignSystemTaskFilterGlyph.priorityP0 => DesignSystemTaskPriority.p0,
      DesignSystemTaskFilterGlyph.priorityP1 => DesignSystemTaskPriority.p1,
      DesignSystemTaskFilterGlyph.priorityP2 => DesignSystemTaskPriority.p2,
      DesignSystemTaskFilterGlyph.priorityP3 => DesignSystemTaskPriority.p3,
      DesignSystemTaskFilterGlyph.none => throw StateError('no glyph'),
    },
  );
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
