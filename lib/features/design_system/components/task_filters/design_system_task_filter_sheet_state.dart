import 'package:flutter/material.dart';

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
    // Only honour the new-format `selectedPriorityIds` key when it is
    // actually present on the payload. A *missing* key falls through to
    // the legacy `selectedPriorityId` migration so old JSON doesn't lose
    // its single-priority selection; a *present* key — even if empty or
    // non-List — is treated as the authoritative new-format value and
    // overrides any stale legacy `selectedPriorityId` still on the payload.
    Set<String>? parsedPriorityIds;
    if (json.containsKey('selectedPriorityIds')) {
      final raw = json['selectedPriorityIds'];
      parsedPriorityIds = raw is List<dynamic>
          ? raw.cast<String>().toSet()
          : const <String>{};
    }

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
      selectedPriorityIds: parsedPriorityIds,
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
