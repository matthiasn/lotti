import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_filter_state.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Toolbar row: Filters / Group by / Sort buttons, search input, count.
///
/// Generic over the page's filter axes — Instances, Templates, Souls,
/// and Pending Wakes all build their own list of [AgentListFilterAxis] /
/// [AgentListGroupAxis] / [AgentListSortAxis] and feed them to this
/// shared toolbar.
class AgentListToolbar extends StatelessWidget {
  const AgentListToolbar({
    required this.state,
    required this.onChanged,
    required this.totalBeforeFilter,
    required this.totalAfterFilter,
    required this.filterAxes,
    required this.groupAxes,
    required this.sortAxes,
    required this.searchPlaceholder,
    super.key,
  });

  final AgentListFilterState state;
  final ValueChanged<AgentListFilterState> onChanged;
  final int totalBeforeFilter;
  final int totalAfterFilter;
  final List<AgentListFilterAxis> filterAxes;
  final List<AgentListGroupAxis> groupAxes;
  final List<AgentListSortAxis> sortAxes;
  final String searchPlaceholder;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    final countText = Text(
      totalAfterFilter == totalBeforeFilter
          ? messages.agentInstancesResultCountAll(totalBeforeFilter)
          : messages.agentInstancesResultCountFiltered(
              totalAfterFilter,
              totalBeforeFilter,
            ),
      style: monoMetaStyle(tokens, tokens.colors),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step6,
        tokens.spacing.step4,
        tokens.spacing.step6,
        tokens.spacing.step3,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Wide enough to keep everything on one line: filter / group /
          // sort buttons (~260) + search (max 280) + count (~110) + gaps.
          final wide = constraints.maxWidth >= 700;
          final filtersBtn = filterAxes.isEmpty
              ? null
              : _FiltersButton(
                  state: state,
                  onChanged: onChanged,
                  axes: filterAxes,
                );
          final groupBtn = groupAxes.length < 2
              ? null
              : _GroupByButton(
                  state: state,
                  onChanged: onChanged,
                  axes: groupAxes,
                );
          final sortBtn = sortAxes.length < 2
              ? null
              : _SortButton(
                  state: state,
                  onChanged: onChanged,
                  axes: sortAxes,
                );
          final search = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: _SearchField(
              value: state.search,
              onChanged: (v) => onChanged(state.copyWith(search: v)),
              placeholder: searchPlaceholder,
            ),
          );

          if (wide) {
            return Row(
              children: [
                if (filtersBtn != null) ...[
                  filtersBtn,
                  SizedBox(width: tokens.spacing.step2),
                ],
                if (groupBtn != null) ...[
                  groupBtn,
                  SizedBox(width: tokens.spacing.step2),
                ],
                if (sortBtn != null) ...[
                  sortBtn,
                  SizedBox(width: tokens.spacing.step2),
                ],
                SizedBox(width: tokens.spacing.step3),
                Flexible(child: search),
                const Spacer(),
                countText,
              ],
            );
          }

          // Compact: buttons + count wrap across lines, search takes a
          // full line below so it always has enough width to be usable.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: tokens.spacing.step2,
                runSpacing: tokens.spacing.step2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ?filtersBtn,
                  ?groupBtn,
                  ?sortBtn,
                  countText,
                ],
              ),
              SizedBox(height: tokens.spacing.step3),
              SizedBox(
                width: double.infinity,
                child: _SearchField(
                  value: state.search,
                  onChanged: (v) => onChanged(state.copyWith(search: v)),
                  placeholder: searchPlaceholder,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Buttons ─────────────────────────────────────────────────────────────────

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.onTap,
    required this.child,
    this.trailing,
    this.emphasised = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Widget child;
  final Widget? trailing;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(tokens.radii.s),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.s),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4,
            vertical: tokens.spacing.step2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: emphasised
                    ? colors.text.highEmphasis
                    : colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step3),
              DefaultTextStyle.merge(
                style: tokens.typography.styles.others.caption.copyWith(
                  color: emphasised
                      ? colors.text.highEmphasis
                      : colors.text.mediumEmphasis,
                ),
                child: child,
              ),
              if (trailing != null) ...[
                SizedBox(width: tokens.spacing.step3),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FiltersButton extends StatelessWidget {
  const _FiltersButton({
    required this.state,
    required this.onChanged,
    required this.axes,
  });

  final AgentListFilterState state;
  final ValueChanged<AgentListFilterState> onChanged;
  final List<AgentListFilterAxis> axes;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final activeCount = state.activeFilterCount;
    return _ToolbarButton(
      icon: Icons.tune,
      emphasised: activeCount > 0,
      onTap: () => _showFiltersPopover(
        context: context,
        state: state,
        onChanged: onChanged,
        axes: axes,
      ),
      trailing: activeCount > 0 ? _CountBadge(count: activeCount) : null,
      child: Text(messages.agentInstancesToolbarFilters),
    );
  }
}

class _GroupByButton extends StatelessWidget {
  const _GroupByButton({
    required this.state,
    required this.onChanged,
    required this.axes,
  });

  final AgentListFilterState state;
  final ValueChanged<AgentListFilterState> onChanged;
  final List<AgentListGroupAxis> axes;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;
    final current = axes.firstWhere(
      (a) => a.id == state.groupAxisId,
      orElse: () => axes.first,
    );
    return _ToolbarButton(
      icon: Icons.layers_outlined,
      onTap: () async {
        final next = await _showSingleSelectPopover<String>(
          context: context,
          current: current.id,
          options: [for (final a in axes) (a.id, a.label)],
          width: 150,
        );
        if (next != null) onChanged(state.copyWith(groupAxisId: next));
      },
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${messages.agentInstancesToolbarGroupBy} '),
            TextSpan(
              text: current.label,
              style: TextStyle(color: tokens.colors.interactive.enabled),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.state,
    required this.onChanged,
    required this.axes,
  });

  final AgentListFilterState state;
  final ValueChanged<AgentListFilterState> onChanged;
  final List<AgentListSortAxis> axes;

  @override
  Widget build(BuildContext context) {
    final current = axes.firstWhere(
      (a) => a.id == state.sortAxisId,
      orElse: () => axes.first,
    );
    return _ToolbarButton(
      icon: Icons.sort,
      onTap: () async {
        final next = await _showSingleSelectPopover<String>(
          context: context,
          current: current.id,
          options: [for (final a in axes) (a.id, a.label)],
          width: 150,
        );
        if (next != null) onChanged(state.copyWith(sortAxisId: next));
      },
      child: Text(current.label),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.colors.interactive.enabled,
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      ),
      child: Text(
        '$count',
        style: tokens.typography.styles.others.caption.copyWith(
          fontFamily: 'Inconsolata',
          fontWeight: tokens.typography.weight.bold,
          color: tokens.colors.text.onInteractiveAlert,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.value,
    required this.onChanged,
    required this.placeholder,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final String placeholder;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode()
      ..addListener(() {
        if (_focused != _focusNode.hasFocus) {
          setState(() => _focused = _focusNode.hasFocus);
        }
      });
  }

  @override
  void didUpdateWidget(covariant _SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync external clears (e.g. "Clear all") into the field.
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final messages = context.messages;
    final borderColor = _focused
        ? colors.interactive.enabled
        : colors.decorative.level01;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: colors.surface.enabled,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(tokens.radii.s),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: colors.interactive.enabled.withValues(alpha: 0.25),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step1,
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 13, color: colors.text.lowEmphasis),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              // Guard no-op keystrokes: the controller fires `onChanged`
              // for every keystroke even when the resulting text matches
              // the value the parent already holds (e.g. didUpdateWidget
              // syncs reset the field). Skipping those avoids a full
              // filter/sort/group rebuild for nothing.
              onChanged: (v) {
                if (v == widget.value) return;
                widget.onChanged(v);
              },
              cursorColor: colors.interactive.enabled,
              style: tokens.typography.styles.others.caption.copyWith(
                color: colors.text.highEmphasis,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                // Suppress all of the field's own decoration so the outer
                // container is the only thing that paints a border / focus
                // ring. Without these explicit overrides Material draws a
                // default underline in the focused state.
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                hintText: widget.placeholder,
                hintStyle: tokens.typography.styles.others.caption.copyWith(
                  color: colors.text.lowEmphasis,
                ),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              iconSize: 12,
              icon: const Icon(Icons.close),
              color: colors.text.mediumEmphasis,
              tooltip: messages.agentInstancesSearchClear,
              onPressed: () {
                _controller.clear();
                widget.onChanged('');
              },
            ),
        ],
      ),
    );
  }
}

// ── Popovers ────────────────────────────────────────────────────────────────

/// Anchored single-select popover used by Group by / Sort. Returns the
/// selected option id (string) or null if dismissed.
Future<T?> _showSingleSelectPopover<T>({
  required BuildContext context,
  required T current,
  required List<(T, String)> options,
  required double width,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null) return null;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return null;
  final position = box.localToGlobal(Offset.zero, ancestor: overlay);
  final size = box.size;
  final tokens = context.designTokens;

  return showMenu<T>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(
        position.dx,
        position.dy + size.height + 6,
        width,
        0,
      ),
      Offset.zero & overlay.size,
    ),
    color: tokens.colors.background.level02,
    elevation: 8,
    constraints: BoxConstraints.tightFor(width: width),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: tokens.colors.decorative.level01),
    ),
    items: [
      for (final (value, label) in options)
        PopupMenuItem<T>(
          value: value,
          padding: EdgeInsets.zero,
          height: 32,
          child: _PopRow(label: label, selected: value == current),
        ),
    ],
  );
}

/// Anchored multi-select popover used by Filters. One section per
/// [AgentListFilterAxis] supplied; per-section "Clear" link wipes that
/// axis's selections.
Future<void> _showFiltersPopover({
  required BuildContext context,
  required AgentListFilterState state,
  required ValueChanged<AgentListFilterState> onChanged,
  required List<AgentListFilterAxis> axes,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null) return;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return;
  final position = box.localToGlobal(Offset.zero, ancestor: overlay);
  final size = box.size;
  final tokens = context.designTokens;

  await showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (dialogContext) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).pop(),
            ),
          ),
          Positioned(
            left: position.dx,
            top: position.dy + size.height + 6,
            width: 240,
            child: _FiltersPopoverPanel(
              tokens: tokens,
              state: state,
              onChanged: onChanged,
              axes: axes,
            ),
          ),
        ],
      );
    },
  );
}

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
