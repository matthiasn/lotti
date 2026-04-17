import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

List<T> _parseJsonList<T>(
  dynamic jsonList,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (jsonList is! List) return const [];
  return jsonList
      .cast<Map<String, dynamic>>()
      .map(fromJson)
      .toList(growable: false);
}

enum DesignSystemTaskFilterSection {
  status,
  category,
  label,
  project,
}

enum DesignSystemTaskFilterGlyph {
  none,
  priorityP0,
  priorityP1,
  priorityP2,
  priorityP3,
}

@immutable
class DesignSystemTaskFilterOption {
  const DesignSystemTaskFilterOption({
    required this.id,
    required this.label,
    this.glyph = DesignSystemTaskFilterGlyph.none,
    this.icon,
    this.iconColor,
  });

  factory DesignSystemTaskFilterOption.fromJson(Map<String, dynamic> json) {
    return DesignSystemTaskFilterOption(
      id: json['id'] as String,
      label: json['label'] as String,
      glyph: DesignSystemTaskFilterGlyph.values.byName(
        json['glyph'] as String? ?? DesignSystemTaskFilterGlyph.none.name,
      ),
    );
  }

  final String id;
  final String label;
  final DesignSystemTaskFilterGlyph glyph;

  /// Optional leading icon for selected chips (e.g. status icons).
  final IconData? icon;

  /// Optional color for the leading icon or dot indicator.
  final Color? iconColor;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'glyph': glyph.name,
  };
}

@immutable
class DesignSystemTaskFilterFieldState {
  const DesignSystemTaskFilterFieldState({
    required this.label,
    required this.options,
    this.selectedIds = const <String>{},
  });

  factory DesignSystemTaskFilterFieldState.fromJson(Map<String, dynamic> json) {
    return DesignSystemTaskFilterFieldState(
      label: json['label'] as String,
      options: (json['options'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(DesignSystemTaskFilterOption.fromJson)
          .toList(growable: false),
      selectedIds: (json['selectedIds'] as List<dynamic>)
          .cast<String>()
          .toSet(),
    );
  }

  final String label;
  final List<DesignSystemTaskFilterOption> options;
  final Set<String> selectedIds;

  List<DesignSystemTaskFilterOption> get selectedOptions => options
      .where((option) => selectedIds.contains(option.id))
      .toList(growable: false);

  DesignSystemTaskFilterFieldState copyWith({
    String? label,
    List<DesignSystemTaskFilterOption>? options,
    Set<String>? selectedIds,
  }) {
    return DesignSystemTaskFilterFieldState(
      label: label ?? this.label,
      options: options ?? this.options,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }

  DesignSystemTaskFilterFieldState removeSelection(String id) {
    if (!selectedIds.contains(id)) {
      return this;
    }

    final nextSelection = {...selectedIds}..remove(id);
    return copyWith(selectedIds: nextSelection);
  }

  DesignSystemTaskFilterFieldState clear() {
    if (selectedIds.isEmpty) {
      return this;
    }

    return copyWith(selectedIds: const <String>{});
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'options': options.map((option) => option.toJson()).toList(growable: false),
    'selectedIds': selectedIds.toList(growable: false),
  };
}

/// A toggle option within the filter sheet (e.g., "Show creation date").
@immutable
class DesignSystemTaskFilterToggle {
  const DesignSystemTaskFilterToggle({
    required this.id,
    required this.label,
    required this.value,
  });

  factory DesignSystemTaskFilterToggle.fromJson(Map<String, dynamic> json) {
    return DesignSystemTaskFilterToggle(
      id: json['id'] as String,
      label: json['label'] as String,
      value: json['value'] as bool? ?? false,
    );
  }

  final String id;
  final String label;
  final bool value;

  DesignSystemTaskFilterToggle copyWith({bool? value}) {
    return DesignSystemTaskFilterToggle(
      id: id,
      label: label,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'value': value,
  };
}

@immutable
class DesignSystemTaskFilterState {
  DesignSystemTaskFilterState({
    required this.title,
    required this.clearAllLabel,
    required this.applyLabel,
    this.sortLabel = '',
    this.sortOptions = const <DesignSystemTaskFilterOption>[],
    this.selectedSortId = '',
    this.statusField,
    this.priorityLabel = '',
    this.priorityOptions = const <DesignSystemTaskFilterOption>[],
    String? selectedPriorityId,
    Set<String>? selectedPriorityIds,
    this.categoryField,
    this.labelField,
    this.projectField,
    this.agentFilterLabel = '',
    this.agentFilterOptions = const <DesignSystemTaskFilterOption>[],
    this.selectedAgentFilterId = '',
    this.searchModeLabel = '',
    this.searchModeOptions = const <DesignSystemTaskFilterOption>[],
    this.selectedSearchModeId = '',
    this.toggles = const <DesignSystemTaskFilterToggle>[],
  }) : assert(
         priorityOptions.isEmpty ||
             priorityOptions.any((option) => option.id == allPriorityId),
         'priorityOptions must contain an option with id "$allPriorityId"',
       ),
       // Priority selection is multi-select; the set is the source of truth.
       // Legacy callers that still pass a single [selectedPriorityId] are
       // migrated to a single-element set, and `allPriorityId`/null/empty
       // all resolve to an empty selection (meaning "no priority filter
       // applied, all priorities visible").
       selectedPriorityIds = Set<String>.unmodifiable(
         selectedPriorityIds ??
             (selectedPriorityId == null ||
                     selectedPriorityId == allPriorityId ||
                     selectedPriorityId.isEmpty
                 ? const <String>{}
                 : <String>{selectedPriorityId}),
       );

  factory DesignSystemTaskFilterState.fromJson(Map<String, dynamic> json) {
    return DesignSystemTaskFilterState(
      title: json['title'] as String,
      clearAllLabel: json['clearAllLabel'] as String,
      applyLabel: json['applyLabel'] as String,
      sortLabel: json['sortLabel'] as String? ?? '',
      sortOptions: _parseJsonList(
        json['sortOptions'],
        DesignSystemTaskFilterOption.fromJson,
      ),
      selectedSortId: json['selectedSortId'] as String? ?? '',
      statusField: switch (json['statusField']) {
        final Map<String, dynamic> value =>
          DesignSystemTaskFilterFieldState.fromJson(value),
        _ => null,
      },
      priorityLabel: json['priorityLabel'] as String? ?? '',
      priorityOptions: _parseJsonList(
        json['priorityOptions'],
        DesignSystemTaskFilterOption.fromJson,
      ),
      selectedPriorityIds: switch (json['selectedPriorityIds']) {
        final List<dynamic> ids => ids.cast<String>().toSet(),
        _ => null,
      },
      selectedPriorityId: json['selectedPriorityId'] as String?,
      categoryField: switch (json['categoryField']) {
        final Map<String, dynamic> value =>
          DesignSystemTaskFilterFieldState.fromJson(value),
        _ => null,
      },
      labelField: switch (json['labelField']) {
        final Map<String, dynamic> value =>
          DesignSystemTaskFilterFieldState.fromJson(value),
        _ => null,
      },
      projectField: switch (json['projectField']) {
        final Map<String, dynamic> value =>
          DesignSystemTaskFilterFieldState.fromJson(value),
        _ => null,
      },
      agentFilterLabel: json['agentFilterLabel'] as String? ?? '',
      agentFilterOptions: _parseJsonList(
        json['agentFilterOptions'],
        DesignSystemTaskFilterOption.fromJson,
      ),
      selectedAgentFilterId: json['selectedAgentFilterId'] as String? ?? '',
      searchModeLabel: json['searchModeLabel'] as String? ?? '',
      searchModeOptions: _parseJsonList(
        json['searchModeOptions'],
        DesignSystemTaskFilterOption.fromJson,
      ),
      selectedSearchModeId: json['selectedSearchModeId'] as String? ?? '',
      toggles: _parseJsonList(
        json['toggles'],
        DesignSystemTaskFilterToggle.fromJson,
      ),
    );
  }

  static const allPriorityId = 'all';

  final String title;
  final String clearAllLabel;
  final String applyLabel;
  final String sortLabel;
  final List<DesignSystemTaskFilterOption> sortOptions;
  final String selectedSortId;
  final DesignSystemTaskFilterFieldState? statusField;
  final String priorityLabel;
  final List<DesignSystemTaskFilterOption> priorityOptions;

  /// The set of currently selected priority IDs. Multi-select: zero or more
  /// of [priorityOptions] may be selected simultaneously. An empty set means
  /// "no priority filter applied" (equivalent to the legacy
  /// [allPriorityId] sentinel).
  final Set<String> selectedPriorityIds;

  /// Legacy single-select view of [selectedPriorityIds]. Returns
  /// [allPriorityId] when the set is empty, the single selected id when
  /// exactly one is selected, or [allPriorityId] when multiple are
  /// selected (so legacy callers keep a sensible default).
  String get selectedPriorityId => selectedPriorityIds.length == 1
      ? selectedPriorityIds.first
      : allPriorityId;
  final DesignSystemTaskFilterFieldState? categoryField;
  final DesignSystemTaskFilterFieldState? labelField;
  final DesignSystemTaskFilterFieldState? projectField;
  final String agentFilterLabel;
  final List<DesignSystemTaskFilterOption> agentFilterOptions;
  final String selectedAgentFilterId;
  final String searchModeLabel;
  final List<DesignSystemTaskFilterOption> searchModeOptions;
  final String selectedSearchModeId;
  final List<DesignSystemTaskFilterToggle> toggles;

  bool get hasSortSection => sortOptions.isNotEmpty;
  bool get hasStatusField => statusField != null;
  bool get hasPrioritySection => priorityOptions.isNotEmpty;
  bool get hasCategoryField => categoryField != null;
  bool get hasLabelField => labelField != null;
  bool get hasProjectField => projectField != null;
  bool get hasAgentFilter => agentFilterOptions.isNotEmpty;
  bool get hasSearchMode => searchModeOptions.isNotEmpty;

  int get appliedCount =>
      (statusField?.selectedIds.length ?? 0) +
      (categoryField?.selectedIds.length ?? 0) +
      (labelField?.selectedIds.length ?? 0) +
      (projectField?.selectedIds.length ?? 0) +
      (hasPrioritySection ? selectedPriorityIds.length : 0) +
      (hasAgentFilter &&
              selectedAgentFilterId.isNotEmpty &&
              selectedAgentFilterId != agentFilterOptions.first.id
          ? 1
          : 0);

  DesignSystemTaskFilterState copyWith({
    String? title,
    String? clearAllLabel,
    String? applyLabel,
    String? sortLabel,
    List<DesignSystemTaskFilterOption>? sortOptions,
    String? selectedSortId,
    DesignSystemTaskFilterFieldState? statusField,
    String? priorityLabel,
    List<DesignSystemTaskFilterOption>? priorityOptions,
    Set<String>? selectedPriorityIds,
    DesignSystemTaskFilterFieldState? categoryField,
    DesignSystemTaskFilterFieldState? labelField,
    DesignSystemTaskFilterFieldState? projectField,
    String? agentFilterLabel,
    List<DesignSystemTaskFilterOption>? agentFilterOptions,
    String? selectedAgentFilterId,
    String? searchModeLabel,
    List<DesignSystemTaskFilterOption>? searchModeOptions,
    String? selectedSearchModeId,
    List<DesignSystemTaskFilterToggle>? toggles,
  }) {
    return DesignSystemTaskFilterState(
      title: title ?? this.title,
      clearAllLabel: clearAllLabel ?? this.clearAllLabel,
      applyLabel: applyLabel ?? this.applyLabel,
      sortLabel: sortLabel ?? this.sortLabel,
      sortOptions: sortOptions ?? this.sortOptions,
      selectedSortId: selectedSortId ?? this.selectedSortId,
      statusField: statusField ?? this.statusField,
      priorityLabel: priorityLabel ?? this.priorityLabel,
      priorityOptions: priorityOptions ?? this.priorityOptions,
      selectedPriorityIds: selectedPriorityIds ?? this.selectedPriorityIds,
      categoryField: categoryField ?? this.categoryField,
      labelField: labelField ?? this.labelField,
      projectField: projectField ?? this.projectField,
      agentFilterLabel: agentFilterLabel ?? this.agentFilterLabel,
      agentFilterOptions: agentFilterOptions ?? this.agentFilterOptions,
      selectedAgentFilterId:
          selectedAgentFilterId ?? this.selectedAgentFilterId,
      searchModeLabel: searchModeLabel ?? this.searchModeLabel,
      searchModeOptions: searchModeOptions ?? this.searchModeOptions,
      selectedSearchModeId: selectedSearchModeId ?? this.selectedSearchModeId,
      toggles: toggles ?? this.toggles,
    );
  }

  DesignSystemTaskFilterState selectSort(String sortId) {
    if (!hasSortSection || sortId == selectedSortId) {
      return this;
    }

    return copyWith(selectedSortId: sortId);
  }

  /// Toggles [priorityId] in the current priority selection set. Tapping
  /// the `allPriorityId` sentinel clears every selection.
  DesignSystemTaskFilterState togglePriority(String priorityId) {
    if (!hasPrioritySection) return this;

    if (priorityId == allPriorityId) {
      if (selectedPriorityIds.isEmpty) return this;
      return copyWith(selectedPriorityIds: const <String>{});
    }

    final next = {...selectedPriorityIds};
    if (!next.remove(priorityId)) {
      next.add(priorityId);
    }
    return copyWith(selectedPriorityIds: next);
  }

  /// Legacy single-select variant kept for callers that still pass an
  /// explicit id. Use [togglePriority] for new code.
  ///
  /// Unlike [togglePriority], this *replaces* the selection rather than
  /// toggling: calling it with `allPriorityId` (or an empty id) clears the
  /// selection, and any other id becomes the sole selected priority.
  DesignSystemTaskFilterState selectPriority(String priorityId) {
    if (!hasPrioritySection) return this;
    if (priorityId == allPriorityId || priorityId.isEmpty) {
      if (selectedPriorityIds.isEmpty) return this;
      return copyWith(selectedPriorityIds: const <String>{});
    }
    if (selectedPriorityIds.length == 1 &&
        selectedPriorityIds.contains(priorityId)) {
      return this;
    }
    return copyWith(selectedPriorityIds: <String>{priorityId});
  }

  DesignSystemTaskFilterState selectAgentFilter(String agentFilterId) {
    if (!hasAgentFilter || agentFilterId == selectedAgentFilterId) {
      return this;
    }

    return copyWith(selectedAgentFilterId: agentFilterId);
  }

  DesignSystemTaskFilterState selectSearchMode(String searchModeId) {
    if (!hasSearchMode || searchModeId == selectedSearchModeId) {
      return this;
    }

    return copyWith(selectedSearchModeId: searchModeId);
  }

  DesignSystemTaskFilterState toggleValue(String toggleId) {
    final index = toggles.indexWhere((t) => t.id == toggleId);
    if (index < 0) return this;

    final updated = [...toggles];
    updated[index] = updated[index].copyWith(value: !updated[index].value);
    return copyWith(toggles: updated);
  }

  DesignSystemTaskFilterState removeSelection(
    DesignSystemTaskFilterSection section,
    String id,
  ) {
    return switch (section) {
      DesignSystemTaskFilterSection.status => copyWith(
        statusField: statusField?.removeSelection(id),
      ),
      DesignSystemTaskFilterSection.category => copyWith(
        categoryField: categoryField?.removeSelection(id),
      ),
      DesignSystemTaskFilterSection.label => copyWith(
        labelField: labelField?.removeSelection(id),
      ),
      DesignSystemTaskFilterSection.project => copyWith(
        projectField: projectField?.removeSelection(id),
      ),
    };
  }

  DesignSystemTaskFilterState clearAll() {
    return copyWith(
      statusField: statusField?.clear(),
      selectedPriorityIds: const <String>{},
      categoryField: categoryField?.clear(),
      labelField: labelField?.clear(),
      projectField: projectField?.clear(),
      selectedAgentFilterId: hasAgentFilter
          ? agentFilterOptions.first.id
          : selectedAgentFilterId,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'clearAllLabel': clearAllLabel,
    'applyLabel': applyLabel,
    'sortLabel': sortLabel,
    'sortOptions': sortOptions
        .map((option) => option.toJson())
        .toList(growable: false),
    'selectedSortId': selectedSortId,
    'statusField': statusField?.toJson(),
    'priorityLabel': priorityLabel,
    'priorityOptions': priorityOptions
        .map((option) => option.toJson())
        .toList(growable: false),
    'selectedPriorityId': selectedPriorityId,
    'selectedPriorityIds': selectedPriorityIds.toList(growable: false),
    'categoryField': categoryField?.toJson(),
    'labelField': labelField?.toJson(),
    'projectField': projectField?.toJson(),
    'agentFilterLabel': agentFilterLabel,
    'agentFilterOptions': agentFilterOptions
        .map((option) => option.toJson())
        .toList(growable: false),
    'selectedAgentFilterId': selectedAgentFilterId,
    'searchModeLabel': searchModeLabel,
    'searchModeOptions': searchModeOptions
        .map((option) => option.toJson())
        .toList(growable: false),
    'selectedSearchModeId': selectedSearchModeId,
    'toggles': toggles.map((t) => t.toJson()).toList(growable: false),
  };
}

/// The filter sheet content — designed to be placed inside a Wolt modal page.
///
/// This widget renders the scrollable filter sections (sort, status, priority,
/// category, label, project, agent, search mode, toggles). It does NOT include
/// the outer frame, background, drag handle, or action buttons — those are
/// provided by the Wolt modal via [DesignSystemTaskFilterActionBar].
class DesignSystemTaskFilterSheet extends StatelessWidget {
  const DesignSystemTaskFilterSheet({
    required this.state,
    required this.onChanged,
    this.onFieldPressed,
    super.key,
  });

  final DesignSystemTaskFilterState state;
  final ValueChanged<DesignSystemTaskFilterState> onChanged;
  final ValueChanged<DesignSystemTaskFilterSection>? onFieldPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final palette = DesignSystemFilterPalette.fromTokens(tokens);
    final spacing = tokens.spacing;
    final contentSections = <Widget>[
      if (state.hasSearchMode)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _TaskFilterSectionLabel(
              text: state.searchModeLabel,
              color: palette.secondaryText,
              style: tokens.typography.styles.others.caption,
            ),
            SizedBox(height: spacing.step4),
            Wrap(
              spacing: spacing.step3,
              runSpacing: spacing.step3,
              children: [
                for (final option in state.searchModeOptions)
                  _TaskFilterChoicePill(
                    key: ValueKey(
                      'design-system-task-filter-search-mode-${option.id}',
                    ),
                    label: option.label,
                    selected: option.id == state.selectedSearchModeId,
                    palette: palette,
                    textStyle: tokens.typography.styles.subtitle.subtitle2,
                    onTap: () => onChanged(state.selectSearchMode(option.id)),
                  ),
              ],
            ),
          ],
        ),
      if (state.hasSortSection)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _TaskFilterSectionLabel(
              text: state.sortLabel,
              color: palette.secondaryText,
              style: tokens.typography.styles.others.caption,
            ),
            SizedBox(height: spacing.step4),
            Wrap(
              spacing: spacing.step3,
              runSpacing: spacing.step3,
              children: [
                for (final option in state.sortOptions)
                  _TaskFilterChoicePill(
                    key: ValueKey(
                      'design-system-task-filter-sort-${option.id}',
                    ),
                    label: option.label,
                    selected: option.id == state.selectedSortId,
                    palette: palette,
                    textStyle: tokens.typography.styles.subtitle.subtitle2,
                    onTap: () => onChanged(state.selectSort(option.id)),
                  ),
              ],
            ),
          ],
        ),
      if (state.hasStatusField)
        _TaskFilterSelectionField(
          key: const ValueKey(
            'design-system-task-filter-field-status',
          ),
          label: state.statusField!.label,
          items: state.statusField!.selectedOptions,
          section: DesignSystemTaskFilterSection.status,
          palette: palette,
          onTap: onFieldPressed == null
              ? null
              : () => onFieldPressed!.call(
                  DesignSystemTaskFilterSection.status,
                ),
          onRemove: (id) => onChanged(
            state.removeSelection(
              DesignSystemTaskFilterSection.status,
              id,
            ),
          ),
        ),
      if (state.hasPrioritySection)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _TaskFilterSectionLabel(
              text: state.priorityLabel,
              color: palette.secondaryText,
              style: tokens.typography.styles.others.caption,
            ),
            SizedBox(height: spacing.step4),
            Wrap(
              spacing: spacing.step1,
              runSpacing: spacing.step1,
              children: [
                for (final option in state.priorityOptions)
                  _TaskFilterChoicePill(
                    key: ValueKey(
                      'design-system-task-filter-priority-${option.id}',
                    ),
                    label: option.label,
                    selected:
                        option.id == DesignSystemTaskFilterState.allPriorityId
                        ? state.selectedPriorityIds.isEmpty
                        : state.selectedPriorityIds.contains(option.id),
                    palette: palette,
                    textStyle: tokens.typography.styles.subtitle.subtitle2,
                    leading: option.glyph != DesignSystemTaskFilterGlyph.none
                        ? _TaskFilterPriorityGlyph(
                            glyph: option.glyph,
                            palette: palette,
                          )
                        : null,
                    onTap: () => onChanged(state.togglePriority(option.id)),
                  ),
              ],
            ),
          ],
        ),
      if (state.hasCategoryField)
        _TaskFilterSelectionField(
          key: const ValueKey(
            'design-system-task-filter-field-category',
          ),
          label: state.categoryField!.label,
          items: state.categoryField!.selectedOptions,
          section: DesignSystemTaskFilterSection.category,
          palette: palette,
          onTap: onFieldPressed == null
              ? null
              : () => onFieldPressed!.call(
                  DesignSystemTaskFilterSection.category,
                ),
          onRemove: (id) => onChanged(
            state.removeSelection(
              DesignSystemTaskFilterSection.category,
              id,
            ),
          ),
        ),
      if (state.hasProjectField)
        _TaskFilterSelectionField(
          key: const ValueKey(
            'design-system-task-filter-field-project',
          ),
          label: state.projectField!.label,
          items: state.projectField!.selectedOptions,
          section: DesignSystemTaskFilterSection.project,
          palette: palette,
          onTap: onFieldPressed == null
              ? null
              : () => onFieldPressed!.call(
                  DesignSystemTaskFilterSection.project,
                ),
          onRemove: (id) => onChanged(
            state.removeSelection(
              DesignSystemTaskFilterSection.project,
              id,
            ),
          ),
        ),
      if (state.hasLabelField)
        _TaskFilterSelectionField(
          key: const ValueKey(
            'design-system-task-filter-field-label',
          ),
          label: state.labelField!.label,
          items: state.labelField!.selectedOptions,
          section: DesignSystemTaskFilterSection.label,
          palette: palette,
          onTap: onFieldPressed == null
              ? null
              : () => onFieldPressed!.call(
                  DesignSystemTaskFilterSection.label,
                ),
          onRemove: (id) => onChanged(
            state.removeSelection(
              DesignSystemTaskFilterSection.label,
              id,
            ),
          ),
        ),
      if (state.hasAgentFilter)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _TaskFilterSectionLabel(
              text: state.agentFilterLabel,
              color: palette.secondaryText,
              style: tokens.typography.styles.others.caption,
            ),
            SizedBox(height: spacing.step4),
            Wrap(
              spacing: spacing.step3,
              runSpacing: spacing.step3,
              children: [
                for (final option in state.agentFilterOptions)
                  _TaskFilterChoicePill(
                    key: ValueKey(
                      'design-system-task-filter-agent-${option.id}',
                    ),
                    label: option.label,
                    selected: option.id == state.selectedAgentFilterId,
                    palette: palette,
                    textStyle: tokens.typography.styles.subtitle.subtitle2,
                    onTap: () => onChanged(state.selectAgentFilter(option.id)),
                  ),
              ],
            ),
          ],
        ),
      if (state.toggles.isNotEmpty)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final toggle in state.toggles)
              _TaskFilterToggleRow(
                key: ValueKey(
                  'design-system-task-filter-toggle-${toggle.id}',
                ),
                toggle: toggle,
                palette: palette,
                onChanged: () => onChanged(state.toggleValue(toggle.id)),
              ),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (contentSections.isNotEmpty)
          for (var i = 0; i < contentSections.length; i++) ...[
            contentSections[i],
            if (i != contentSections.length - 1)
              SizedBox(height: spacing.step6),
          ],
      ],
    );
  }
}

/// Sticky action bar for the filter sheet — Clear All + Apply buttons.
///
/// Designed to be used as the `stickyActionBar` in a Wolt modal page.
class DesignSystemTaskFilterActionBar extends StatelessWidget {
  const DesignSystemTaskFilterActionBar({
    required this.state,
    required this.onChanged,
    this.onApplyPressed,
    this.onClearAllPressed,
    super.key,
  });

  final DesignSystemTaskFilterState state;
  final ValueChanged<DesignSystemTaskFilterState> onChanged;
  final ValueChanged<DesignSystemTaskFilterState>? onApplyPressed;
  final ValueChanged<DesignSystemTaskFilterState>? onClearAllPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final palette = DesignSystemFilterPalette.fromTokens(tokens);
    final spacing = tokens.spacing;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.step5,
        vertical: spacing.step4,
      ),
      child: Row(
        children: [
          Expanded(
            child: DesignSystemFilterActionButton(
              key: const ValueKey(
                'design-system-task-filter-clear',
              ),
              label: state.clearAllLabel,
              palette: palette,
              highlighted: false,
              textStyle: tokens.typography.styles.subtitle.subtitle1,
              onTap: () {
                final clearedState = state.clearAll();
                onChanged(clearedState);
                onClearAllPressed?.call(clearedState);
              },
            ),
          ),
          SizedBox(width: spacing.step5),
          Expanded(
            child: DesignSystemFilterActionButton(
              key: const ValueKey(
                'design-system-task-filter-apply',
              ),
              label: state.applyLabel,
              palette: palette,
              highlighted: true,
              counter: state.appliedCount,
              textStyle: tokens.typography.styles.subtitle.subtitle1,
              onTap: () => onApplyPressed?.call(state),
            ),
          ),
        ],
      ),
    );
  }
}

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

class _TaskFilterChoicePill extends StatelessWidget {
  const _TaskFilterChoicePill({
    required this.label,
    required this.selected,
    required this.palette,
    required this.textStyle,
    required this.onTap,
    this.leading,
    super.key,
  });

  final String label;
  final bool selected;
  final DesignSystemFilterPalette palette;
  final TextStyle textStyle;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;

    final radii = context.designTokens.radii;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? palette.selectedPillBackground : palette.pillFill,
          borderRadius: BorderRadius.circular(radii.badgesPills),
          border: Border.all(
            color: selected ? palette.accent : Colors.transparent,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(radii.badgesPills),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: leading != null ? spacing.step4 : spacing.step5,
              vertical: spacing.step3,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  leading!,
                  SizedBox(width: spacing.step2),
                ],
                Text(
                  label,
                  style: textStyle.copyWith(color: palette.primaryText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
