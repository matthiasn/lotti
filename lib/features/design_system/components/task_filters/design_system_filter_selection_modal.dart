import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

typedef DesignSystemFilterOptionAppearanceResolver =
    DesignSystemFilterSelectionOptionAppearance? Function(String optionId);

typedef DesignSystemFilterSelectionGroupsBuilder =
    List<DesignSystemFilterSelectionGroup> Function(
      DesignSystemTaskFilterState state,
    );

typedef DesignSystemFilterStateNormalizer =
    DesignSystemTaskFilterState Function(DesignSystemTaskFilterState state);

/// Per-option visual overrides for a filter selection page.
///
/// Color is intentionally applied only to the leading icon. Row labels retain
/// the design system's high-emphasis text color so status colors never become
/// low-contrast body text.
@immutable
class DesignSystemFilterSelectionOptionAppearance {
  const DesignSystemFilterSelectionOptionAppearance({
    this.icon,
    this.foregroundColor,
    this.enabled = true,
  });

  final IconData? icon;
  final Color? foregroundColor;
  final bool enabled;
}

/// A labelled subset of options on a filter selection page.
@immutable
class DesignSystemFilterSelectionGroup {
  const DesignSystemFilterSelectionGroup({
    required this.label,
    required this.optionIds,
  });

  final String label;
  final Set<String> optionIds;
}

/// Feature-specific behavior for one embedded filter selection page.
@immutable
class DesignSystemFilterFieldPageConfig {
  const DesignSystemFilterFieldPageConfig({
    this.appearanceResolver,
    this.searchHintText,
    this.groupsBuilder,
    this.normalizeState,
  });

  final DesignSystemFilterOptionAppearanceResolver? appearanceResolver;
  final String? searchHintText;
  final DesignSystemFilterSelectionGroupsBuilder? groupsBuilder;

  /// Runs after the field selection changes. Tasks use this to prune project
  /// selections that no longer belong to the selected categories.
  final DesignSystemFilterStateNormalizer? normalizeState;
}

/// A divider-free multi-select page embedded in the parent filter Wolt route.
///
/// It edits the same route-scoped draft as the overview, so forward/back
/// navigation is immediate and cannot lose or hide a child modal's temporary
/// selection state.
class DesignSystemFilterSelectionPage extends StatefulWidget {
  const DesignSystemFilterSelectionPage({
    required this.stateNotifier,
    required this.section,
    this.config = const DesignSystemFilterFieldPageConfig(),
    super.key,
  });

  final ValueNotifier<DesignSystemTaskFilterState> stateNotifier;
  final DesignSystemTaskFilterSection section;
  final DesignSystemFilterFieldPageConfig config;

  @override
  State<DesignSystemFilterSelectionPage> createState() =>
      _DesignSystemFilterSelectionPageState();
}

class _DesignSystemFilterSelectionPageState
    extends State<DesignSystemFilterSelectionPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;

    return ValueListenableBuilder<DesignSystemTaskFilterState>(
      valueListenable: widget.stateNotifier,
      builder: (context, state, _) {
        final field = state.fieldFor(widget.section);
        if (field == null) return const SizedBox.shrink();

        final query = _query.trim().toLowerCase();
        final searchHintText = widget.config.searchHintText;
        final filtered = query.isEmpty
            ? field.options
            : field.options
                  .where(
                    (option) => option.label.toLowerCase().contains(query),
                  )
                  .toList(growable: false);
        final groups = widget.config.groupsBuilder?.call(state);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...?(searchHintText == null
                ? null
                : [
                    DesignSystemSearch(
                      hintText: searchHintText,
                      semanticsLabel: searchHintText,
                      onChanged: (value) => setState(() => _query = value),
                      onClear: () => setState(() => _query = ''),
                    ),
                    SizedBox(height: spacing.step5),
                  ]),
            if (filtered.isEmpty)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: spacing.step4),
                  child: Text(
                    context.messages.filterSelectionNoMatches,
                    textAlign: TextAlign.center,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ),
              )
            else if (groups == null)
              _OptionList(
                options: filtered,
                selectedIds: field.selectedIds,
                appearanceResolver: widget.config.appearanceResolver,
                onToggle: _toggle,
              )
            else
              _GroupedOptionList(
                groups: groups,
                options: filtered,
                selectedIds: field.selectedIds,
                appearanceResolver: widget.config.appearanceResolver,
                onToggle: _toggle,
              ),
            SizedBox(height: spacing.step12),
          ],
        );
      },
    );
  }

  void _toggle(String optionId) {
    final state = widget.stateNotifier.value;
    final selectedIds = state.fieldFor(widget.section)?.selectedIds;
    if (selectedIds == null) return;
    final nextIds = {...selectedIds};
    if (!nextIds.add(optionId)) nextIds.remove(optionId);
    final nextState = state.replaceFieldSelection(widget.section, nextIds);
    widget.stateNotifier.value =
        widget.config.normalizeState?.call(nextState) ?? nextState;
  }
}

class _GroupedOptionList extends StatelessWidget {
  const _GroupedOptionList({
    required this.groups,
    required this.options,
    required this.selectedIds,
    required this.appearanceResolver,
    required this.onToggle,
  });

  final List<DesignSystemFilterSelectionGroup> groups;
  final List<DesignSystemTaskFilterOption> options;
  final Set<String> selectedIds;
  final DesignSystemFilterOptionAppearanceResolver? appearanceResolver;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final optionById = {for (final option in options) option.id: option};
    final visibleGroups = [
      for (final group in groups)
        (
          group: group,
          options: [
            for (final id in group.optionIds) ?optionById[id],
          ],
        ),
    ].where((entry) => entry.options.isNotEmpty).toList(growable: false);

    if (visibleGroups.isEmpty) {
      return Semantics(
        liveRegion: true,
        child: Text(
          context.messages.filterSelectionNoMatches,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < visibleGroups.length; index++) ...[
          Text(
            visibleGroups[index].group.label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: spacing.step2),
          _OptionList(
            options: visibleGroups[index].options,
            selectedIds: selectedIds,
            appearanceResolver: appearanceResolver,
            onToggle: onToggle,
          ),
          if (index != visibleGroups.length - 1)
            SizedBox(height: spacing.step6),
        ],
      ],
    );
  }
}

class _OptionList extends StatelessWidget {
  const _OptionList({
    required this.options,
    required this.selectedIds,
    required this.appearanceResolver,
    required this.onToggle,
  });

  final List<DesignSystemTaskFilterOption> options;
  final Set<String> selectedIds;
  final DesignSystemFilterOptionAppearanceResolver? appearanceResolver;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in options)
          _FilterSelectionRow(
            option: option,
            selected: selectedIds.contains(option.id),
            appearance: appearanceResolver?.call(option.id),
            onTap: () => onToggle(option.id),
          ),
      ],
    );
  }
}

class _FilterSelectionRow extends StatelessWidget {
  const _FilterSelectionRow({
    required this.option,
    required this.selected,
    required this.onTap,
    this.appearance,
  });

  final DesignSystemTaskFilterOption option;
  final bool selected;
  final VoidCallback onTap;
  final DesignSystemFilterSelectionOptionAppearance? appearance;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final enabled = appearance?.enabled ?? true;
    final icon = appearance?.icon ?? option.icon;
    final color = appearance?.foregroundColor ?? option.iconColor;
    final leading = icon != null
        ? Icon(
            icon,
            color: color ?? tokens.colors.text.mediumEmphasis,
            size: tokens.spacing.step6,
          )
        : color != null
        ? Container(
            width: tokens.spacing.step4,
            height: tokens.spacing.step4,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          )
        : null;

    return DesignSystemSelectionRow(
      key: ValueKey('design-system-filter-selection-option-${option.id}'),
      title: option.label,
      type: DesignSystemSelectionRowType.multiSelect,
      selected: selected,
      leading: leading,
      onTap: enabled ? onTap : null,
    );
  }
}
