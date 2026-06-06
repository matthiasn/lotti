part of 'agent_list_toolbar.dart';

class _FiltersPopoverPanel extends StatefulWidget {
  const _FiltersPopoverPanel({
    required this.tokens,
    required this.state,
    required this.onChanged,
    required this.axes,
  });

  final DsTokens tokens;
  final AgentListFilterState state;
  final ValueChanged<AgentListFilterState> onChanged;
  final List<AgentListFilterAxis> axes;

  @override
  State<_FiltersPopoverPanel> createState() => _FiltersPopoverPanelState();
}

class _FiltersPopoverPanelState extends State<_FiltersPopoverPanel> {
  late AgentListFilterState _local;

  @override
  void initState() {
    super.initState();
    _local = widget.state;
  }

  void _push(AgentListFilterState next) {
    setState(() => _local = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return Material(
      color: tokens.colors.background.level02,
      elevation: 8,
      borderRadius: BorderRadius.circular(tokens.radii.m),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          border: Border.all(color: tokens.colors.decorative.level01),
        ),
        padding: EdgeInsets.all(tokens.spacing.step3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < widget.axes.length; i++) ...[
              if (i > 0) SizedBox(height: tokens.spacing.step3),
              _PopHeader(
                label: widget.axes[i].sectionLabel,
                showClear: _local.selectionsFor(widget.axes[i].id).isNotEmpty,
                onClear: () => _push(_local.clearAxis(widget.axes[i].id)),
              ),
              for (final option in widget.axes[i].options)
                _PopRow(
                  label: option.label,
                  selected: _local
                      .selectionsFor(widget.axes[i].id)
                      .contains(option.id),
                  count: option.count,
                  swatchHue: option.swatchHue,
                  onTap: () =>
                      _push(_local.toggleOption(widget.axes[i].id, option.id)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PopHeader extends StatelessWidget {
  const _PopHeader({
    required this.label,
    required this.showClear,
    required this.onClear,
  });

  final String label;
  final bool showClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step3,
        tokens.spacing.step2,
        tokens.spacing.step3,
        tokens.spacing.step3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              // Closest DS token is `overline` (12px / 700 / wide
              // letter-spacing). Tighter than 9.5 but reads as the
              // intended uppercase section header.
              style: tokens.typography.styles.others.overline.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ),
          if (showClear)
            InkWell(
              onTap: onClear,
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.step1),
                child: Text(
                  context.messages.agentInstancesFilterClearSection,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                    fontWeight: tokens.typography.weight.semiBold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PopRow extends StatelessWidget {
  const _PopRow({
    required this.label,
    required this.selected,
    this.count,
    this.swatchHue,
    this.onTap,
  });

  final String label;
  final bool selected;
  final int? count;
  final int? swatchHue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    return Material(
      color: selected
          ? colors.interactive.enabled.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(tokens.radii.s),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.s),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step3,
            vertical: tokens.spacing.step3,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.interactive.enabled
                        : colors.surface.enabled,
                    border: selected
                        ? null
                        : Border.all(color: colors.decorative.level01),
                    borderRadius: BorderRadius.circular(tokens.radii.xs),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check,
                          size: 10,
                          color: colors.text.onInteractiveAlert,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              if (swatchHue != null) ...[
                _SoulSwatch(hue: swatchHue!),
                SizedBox(width: tokens.spacing.step3),
              ],
              Expanded(
                child: Text(
                  label,
                  style: tokens.typography.styles.others.caption.copyWith(
                    fontWeight: selected
                        ? tokens.typography.weight.semiBold
                        : tokens.typography.weight.regular,
                    color: selected
                        ? colors.text.highEmphasis
                        : colors.text.mediumEmphasis,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count != null)
                Text('$count', style: monoMetaStyle(tokens, colors)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoulSwatch extends StatelessWidget {
  const _SoulSwatch({required this.hue});
  final int hue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: HSLColor.fromAHSL(1, hue.toDouble(), 0.5, 0.5).toColor(),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
