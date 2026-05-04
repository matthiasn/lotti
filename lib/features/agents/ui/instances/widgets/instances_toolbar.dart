import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/instances/instance_filter_state.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Toolbar row: Filters / Group by / Sort buttons, search input, count.
class InstancesToolbar extends StatelessWidget {
  const InstancesToolbar({
    required this.state,
    required this.onChanged,
    required this.totalBeforeFilter,
    required this.totalAfterFilter,
    required this.counts,
    super.key,
  });

  final InstancesFilterState state;
  final ValueChanged<InstancesFilterState> onChanged;
  final int totalBeforeFilter;
  final int totalAfterFilter;
  final FilterCounts counts;

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
      style: tokens.typography.styles.others.caption.copyWith(
        fontFamily: 'Inconsolata',
        color: tokens.colors.text.lowEmphasis,
        letterSpacing: 0,
      ),
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
          final filtersBtn = _FiltersButton(
            state: state,
            onChanged: onChanged,
            counts: counts,
          );
          final groupBtn = _GroupByButton(state: state, onChanged: onChanged);
          final sortBtn = _SortButton(state: state, onChanged: onChanged);
          final search = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: _SearchField(
              value: state.search,
              onChanged: (v) => onChanged(state.copyWith(search: v)),
            ),
          );

          if (wide) {
            return Row(
              children: [
                filtersBtn,
                SizedBox(width: tokens.spacing.step2),
                groupBtn,
                SizedBox(width: tokens.spacing.step2),
                sortBtn,
                SizedBox(width: tokens.spacing.step3),
                Flexible(child: search),
                const Spacer(),
                countText,
              ],
            );
          }

          // Compact: buttons + count wrap across lines, search takes a full
          // line below so it always has enough width to be usable.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: tokens.spacing.step2,
                runSpacing: tokens.spacing.step2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [filtersBtn, groupBtn, sortBtn, countText],
              ),
              SizedBox(height: tokens.spacing.step3),
              SizedBox(
                width: double.infinity,
                child: _SearchField(
                  value: state.search,
                  onChanged: (v) => onChanged(state.copyWith(search: v)),
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
    required this.counts,
  });

  final InstancesFilterState state;
  final ValueChanged<InstancesFilterState> onChanged;
  final FilterCounts counts;

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
        counts: counts,
      ),
      trailing: activeCount > 0 ? _CountBadge(count: activeCount) : null,
      child: Text(messages.agentInstancesToolbarFilters),
    );
  }
}

class _GroupByButton extends StatelessWidget {
  const _GroupByButton({required this.state, required this.onChanged});

  final InstancesFilterState state;
  final ValueChanged<InstancesFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;
    final label = switch (state.groupKey) {
      InstancesGroupKey.soul => messages.agentInstancesGroupBySoul,
      InstancesGroupKey.type => messages.agentInstancesGroupByType,
      InstancesGroupKey.status => messages.agentInstancesGroupByStatus,
    };
    return _ToolbarButton(
      icon: Icons.layers_outlined,
      onTap: () async {
        final next = await _showSingleSelectPopover<InstancesGroupKey>(
          context: context,
          current: state.groupKey,
          options: [
            (InstancesGroupKey.soul, messages.agentInstancesGroupBySoul),
            (InstancesGroupKey.type, messages.agentInstancesGroupByType),
            (InstancesGroupKey.status, messages.agentInstancesGroupByStatus),
          ],
          width: 150,
        );
        if (next != null) onChanged(state.copyWith(groupKey: next));
      },
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${messages.agentInstancesToolbarGroupBy} '),
            TextSpan(
              text: label,
              style: TextStyle(color: tokens.colors.interactive.enabled),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.state, required this.onChanged});

  final InstancesFilterState state;
  final ValueChanged<InstancesFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final label = switch (state.sortKey) {
      InstancesSortKey.recent => messages.agentInstancesSortRecent,
      InstancesSortKey.oldest => messages.agentInstancesSortOldest,
      InstancesSortKey.name => messages.agentInstancesSortName,
    };
    return _ToolbarButton(
      icon: Icons.sort,
      onTap: () async {
        final next = await _showSingleSelectPopover<InstancesSortKey>(
          context: context,
          current: state.sortKey,
          options: [
            (InstancesSortKey.recent, messages.agentInstancesSortRecent),
            (InstancesSortKey.oldest, messages.agentInstancesSortOldest),
            (InstancesSortKey.name, messages.agentInstancesSortName),
          ],
          width: 150,
        );
        if (next != null) onChanged(state.copyWith(sortKey: next));
      },
      child: Text(label),
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
  const _SearchField({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

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
                hintText: messages.agentInstancesSearchPlaceholder,
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

/// Shows a generic popover anchored to the tapped widget. Returns the
/// selected value (single-select popovers) or `null` if dismissed.
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

Future<void> _showFiltersPopover({
  required BuildContext context,
  required InstancesFilterState state,
  required ValueChanged<InstancesFilterState> onChanged,
  required FilterCounts counts,
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
              counts: counts,
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
    required this.counts,
  });

  final DsTokens tokens;
  final InstancesFilterState state;
  final ValueChanged<InstancesFilterState> onChanged;
  final FilterCounts counts;

  @override
  State<_FiltersPopoverPanel> createState() => _FiltersPopoverPanelState();
}

class _FiltersPopoverPanelState extends State<_FiltersPopoverPanel> {
  late InstancesFilterState _local;

  @override
  void initState() {
    super.initState();
    _local = widget.state;
  }

  void _push(InstancesFilterState next) {
    setState(() => _local = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
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
            _PopHeader(
              label: messages.agentInstancesFilterSectionType,
              showClear: _local.types.isNotEmpty,
              onClear: () => _push(_local.copyWith(types: const {})),
            ),
            for (final t in InstanceType.values)
              _PopRow(
                label: instanceTypeLabel(messages, t),
                selected: _local.types.contains(t),
                count: widget.counts.types[t] ?? 0,
                onTap: () => _push(_local.toggleType(t)),
              ),
            SizedBox(height: tokens.spacing.step3),
            _PopHeader(
              label: messages.agentInstancesFilterSectionStatus,
              showClear: _local.statuses.isNotEmpty,
              onClear: () => _push(_local.copyWith(statuses: const {})),
            ),
            for (final s in const [
              AgentLifecycle.active,
              AgentLifecycle.dormant,
              AgentLifecycle.destroyed,
            ])
              _PopRow(
                label: agentLifecycleLabel(messages, s),
                selected: _local.statuses.contains(s),
                count: widget.counts.statuses[s] ?? 0,
                onTap: () => _push(_local.toggleStatus(s)),
              ),
            if (widget.counts.soulOptions.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step3),
              _PopHeader(
                label: messages.agentInstancesFilterSectionSoul,
                showClear: _local.soulIds.isNotEmpty,
                onClear: () => _push(_local.copyWith(soulIds: const {})),
              ),
              for (final s in widget.counts.soulOptions)
                _PopRow(
                  label: s.label,
                  selected: _local.soulIds.contains(s.id),
                  count: widget.counts.soulCounts[s.id] ?? 0,
                  swatchHue: s.hue,
                  onTap: () => _push(_local.toggleSoul(s.id)),
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
                Text(
                  '$count',
                  style: tokens.typography.styles.others.caption.copyWith(
                    fontFamily: 'Inconsolata',
                    color: colors.text.lowEmphasis,
                    letterSpacing: 0,
                  ),
                ),
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
