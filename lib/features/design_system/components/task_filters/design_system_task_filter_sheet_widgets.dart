part of 'design_system_task_filter_sheet.dart';

class _TaskFilterSelectionField extends StatelessWidget {
  const _TaskFilterSelectionField({
    required this.label,
    required this.items,
    required this.section,
    required this.palette,
    required this.onTap,
    required this.onRemove,
    super.key,
  });

  final String label;
  final List<DesignSystemTaskFilterOption> items;
  final DesignSystemTaskFilterSection section;
  final DesignSystemFilterPalette palette;
  final VoidCallback? onTap;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;

    final radii = tokens.radii;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: palette.fieldBackground,
          borderRadius: BorderRadius.circular(radii.badgesPills),
          border: Border.all(color: palette.fieldOutline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(radii.badgesPills),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: spacing.step9 + spacing.step2, // 52
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.step5,
                vertical: spacing.step2 + spacing.step1, // 6px
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: tokens.typography.styles.others.caption
                              .copyWith(color: palette.secondaryText),
                        ),
                        SizedBox(height: spacing.step2),
                        if (items.isEmpty)
                          Text(
                            ' ',
                            style: tokens.typography.styles.subtitle.subtitle2
                                .copyWith(color: palette.primaryText),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (var i = 0; i < items.length; i++) ...[
                                  _TaskFilterSelectedChip(
                                    option: items[i],
                                    section: section,
                                    palette: palette,
                                    onRemove: () => onRemove(items[i].id),
                                  ),
                                  if (i != items.length - 1)
                                    SizedBox(width: spacing.step3),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: spacing.step3),
                  Icon(
                    Icons.arrow_drop_down,
                    color: palette.secondaryText,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskFilterSelectedChip extends StatelessWidget {
  const _TaskFilterSelectedChip({
    required this.option,
    required this.section,
    required this.palette,
    required this.onRemove,
  });

  final DesignSystemTaskFilterOption option;
  final DesignSystemTaskFilterSection section;
  final DesignSystemFilterPalette palette;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;

    return Container(
      height: spacing.step6 + spacing.step2, // 28
      padding: EdgeInsets.fromLTRB(
        spacing.step4,
        spacing.step1,
        spacing.step2,
        spacing.step1,
      ),
      decoration: BoxDecoration(
        color: palette.pillFill,
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (option.icon != null) ...[
            Icon(option.icon, color: option.iconColor, size: 18),
            SizedBox(width: spacing.step2),
          ] else if (option.iconColor != null) ...[
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: option.iconColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: spacing.step2),
          ],
          Text(
            option.label,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: palette.primaryText,
            ),
          ),
          SizedBox(width: spacing.step2),
          GestureDetector(
            key: ValueKey(
              'design-system-task-filter-remove-${section.name}-${option.id}',
            ),
            onTap: onRemove,
            child: Icon(
              Icons.cancel,
              color: palette.dismissFill,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

/// Duration used to cross-fade the pill's border and fill colours between
// `DesignSystemFilterChoicePill` is the shared exclusive-choice pill —
// see `design_system_filter_shared.dart`. The previous private copy in
// this file has been merged into the shared version so the linked-entries
// filter modal can render the same chrome.

class _TaskFilterPriorityGlyph extends StatelessWidget {
  const _TaskFilterPriorityGlyph({
    required this.glyph,
    required this.palette,
  });

  final DesignSystemTaskFilterGlyph glyph;
  final DesignSystemFilterPalette palette;

  @override
  Widget build(BuildContext context) {
    // P0: new_releases icon (star burst)
    if (glyph == DesignSystemTaskFilterGlyph.priorityP0) {
      return Icon(
        Icons.new_releases,
        color: palette.priorityP0,
        size: 20,
      );
    }

    // P1: signal_cellular_alt (3 ascending bars)
    if (glyph == DesignSystemTaskFilterGlyph.priorityP1) {
      return Icon(
        Icons.signal_cellular_alt,
        color: palette.priorityP1,
        size: 20,
      );
    }

    final color = switch (glyph) {
      DesignSystemTaskFilterGlyph.priorityP2 => palette.priorityP2,
      DesignSystemTaskFilterGlyph.priorityP3 => palette.priorityP3,
      _ => palette.secondaryText,
    };

    // P2: 2 bars (medium signal), P3: 1 bar (low signal)
    // Rendered as ascending bars with fewer filled
    final filledBars = switch (glyph) {
      DesignSystemTaskFilterGlyph.priorityP2 => 2,
      DesignSystemTaskFilterGlyph.priorityP3 => 1,
      _ => 3,
    };

    const barWidths = [4.0, 4.0, 4.0];
    const barHeights = [5.0, 9.0, 13.0];

    return SizedBox(
      width: 16,
      height: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < barHeights.length; i++)
            Padding(
              padding: EdgeInsets.only(
                right: i < barHeights.length - 1 ? 1.0 : 0,
              ),
              child: Container(
                width: barWidths[i],
                height: barHeights[i],
                decoration: BoxDecoration(
                  color: i < filledBars ? color : color.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskFilterSectionLabel extends StatelessWidget {
  const _TaskFilterSectionLabel({
    required this.text,
    required this.color,
    required this.style,
  });

  final String text;
  final Color color;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style.copyWith(color: color),
    );
  }
}

class _TaskFilterToggleRow extends StatelessWidget {
  const _TaskFilterToggleRow({
    required this.toggle,
    required this.palette,
    required this.onChanged,
    super.key,
  });

  final DesignSystemTaskFilterToggle toggle;
  final DesignSystemFilterPalette palette;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Semantics(
      toggled: toggle.value,
      label: toggle.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          onTap: onChanged,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    toggle.label,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: palette.primaryText,
                    ),
                  ),
                ),
                SizedBox(
                  height: tokens.spacing.step6,
                  width: tokens.spacing.step8,
                  child: FittedBox(
                    child: ExcludeSemantics(
                      child: IgnorePointer(
                        child: Switch.adaptive(
                          value: toggle.value,
                          activeTrackColor: palette.accent,
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
