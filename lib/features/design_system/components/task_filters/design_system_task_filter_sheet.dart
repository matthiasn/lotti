import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemTaskFilterSection {
  status,
  category,
  label,
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
    this.selectedPriorityId = allPriorityId,
    this.categoryField,
    this.labelField,
    this.showDragHandle = true,
  }) : assert(
         priorityOptions.isEmpty ||
             priorityOptions.any((option) => option.id == allPriorityId),
         'priorityOptions must contain an option with id "$allPriorityId"',
       );

  factory DesignSystemTaskFilterState.fromJson(Map<String, dynamic> json) {
    return DesignSystemTaskFilterState(
      title: json['title'] as String,
      clearAllLabel: json['clearAllLabel'] as String,
      applyLabel: json['applyLabel'] as String,
      sortLabel: json['sortLabel'] as String? ?? '',
      sortOptions: ((json['sortOptions'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(DesignSystemTaskFilterOption.fromJson)
          .toList(growable: false),
      selectedSortId: json['selectedSortId'] as String? ?? '',
      statusField: switch (json['statusField']) {
        final Map<String, dynamic> value =>
          DesignSystemTaskFilterFieldState.fromJson(value),
        _ => null,
      },
      priorityLabel: json['priorityLabel'] as String? ?? '',
      priorityOptions: ((json['priorityOptions'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(DesignSystemTaskFilterOption.fromJson)
          .toList(growable: false),
      selectedPriorityId:
          json['selectedPriorityId'] as String? ?? allPriorityId,
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
      showDragHandle: json['showDragHandle'] as bool? ?? true,
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
  final String selectedPriorityId;
  final DesignSystemTaskFilterFieldState? categoryField;
  final DesignSystemTaskFilterFieldState? labelField;
  final bool showDragHandle;

  bool get hasSortSection => sortOptions.isNotEmpty;
  bool get hasStatusField => statusField != null;
  bool get hasPrioritySection => priorityOptions.isNotEmpty;
  bool get hasCategoryField => categoryField != null;
  bool get hasLabelField => labelField != null;

  int get appliedCount =>
      (statusField?.selectedIds.length ?? 0) +
      (categoryField?.selectedIds.length ?? 0) +
      (labelField?.selectedIds.length ?? 0) +
      (hasPrioritySection && selectedPriorityId != allPriorityId ? 1 : 0);

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
    String? selectedPriorityId,
    DesignSystemTaskFilterFieldState? categoryField,
    DesignSystemTaskFilterFieldState? labelField,
    bool? showDragHandle,
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
      selectedPriorityId: selectedPriorityId ?? this.selectedPriorityId,
      categoryField: categoryField ?? this.categoryField,
      labelField: labelField ?? this.labelField,
      showDragHandle: showDragHandle ?? this.showDragHandle,
    );
  }

  DesignSystemTaskFilterState selectSort(String sortId) {
    if (!hasSortSection || sortId == selectedSortId) {
      return this;
    }

    return copyWith(selectedSortId: sortId);
  }

  DesignSystemTaskFilterState selectPriority(String priorityId) {
    if (!hasPrioritySection || priorityId == selectedPriorityId) {
      return this;
    }

    return copyWith(selectedPriorityId: priorityId);
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
    };
  }

  DesignSystemTaskFilterState clearAll() {
    return copyWith(
      statusField: statusField?.clear(),
      selectedPriorityId: allPriorityId,
      categoryField: categoryField?.clear(),
      labelField: labelField?.clear(),
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
    'categoryField': categoryField?.toJson(),
    'labelField': labelField?.toJson(),
    'showDragHandle': showDragHandle,
  };
}

class DesignSystemTaskFilterSheet extends StatelessWidget {
  const DesignSystemTaskFilterSheet({
    required this.state,
    required this.onChanged,
    this.onApplyPressed,
    this.onClearAllPressed,
    this.onFieldPressed,
    super.key,
  });

  final DesignSystemTaskFilterState state;
  final ValueChanged<DesignSystemTaskFilterState> onChanged;
  final ValueChanged<DesignSystemTaskFilterState>? onApplyPressed;
  final ValueChanged<DesignSystemTaskFilterState>? onClearAllPressed;
  final ValueChanged<DesignSystemTaskFilterSection>? onFieldPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final palette = _TaskFilterPalette.fromTokens(tokens);
    final spacing = tokens.spacing;
    final contentSections = <Widget>[
      if (state.hasSortSection) ...[
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
      if (state.hasStatusField) ...[
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
      ],
      if (state.hasPrioritySection) ...[
        _TaskFilterSectionLabel(
          text: state.priorityLabel,
          color: palette.secondaryText,
          style: tokens.typography.styles.others.caption,
        ),
        SizedBox(height: spacing.step4),
        Wrap(
          spacing: spacing.step3,
          runSpacing: spacing.step3,
          children: [
            for (final option in state.priorityOptions)
              _TaskFilterChoicePill(
                key: ValueKey(
                  'design-system-task-filter-priority-${option.id}',
                ),
                label: option.label,
                selected: option.id == state.selectedPriorityId,
                palette: palette,
                textStyle: tokens.typography.styles.subtitle.subtitle2,
                leading: option.glyph != DesignSystemTaskFilterGlyph.none
                    ? _TaskFilterPriorityGlyph(
                        glyph: option.glyph,
                        palette: palette,
                      )
                    : null,
                onTap: () => onChanged(state.selectPriority(option.id)),
              ),
          ],
        ),
      ],
      if (state.hasCategoryField) ...[
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
      ],
      if (state.hasLabelField) ...[
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
      ],
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(_TaskFilterMetrics.frameRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(color: palette.sheetBackground),
        child: SizedBox(
          width: _TaskFilterMetrics.frameWidth,
          height: _TaskFilterMetrics.frameHeight,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    spacing.step5,
                    spacing.step4,
                    spacing.step5,
                    spacing.step6,
                  ),
                  child: SizedBox(
                    width: _TaskFilterMetrics.contentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.showDragHandle)
                          Center(
                            child: Container(
                              width: _TaskFilterMetrics.handleWidth,
                              height: _TaskFilterMetrics.handleHeight,
                              decoration: BoxDecoration(
                                color: palette.handleColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        SizedBox(height: spacing.step6),
                        Text(
                          state.title,
                          style: tokens.typography.styles.heading.heading2
                              .copyWith(color: palette.primaryText),
                        ),
                        if (contentSections.isNotEmpty) ...[
                          SizedBox(
                            height: spacing.step9 + spacing.step2,
                          ), // 52px
                          for (var i = 0; i < contentSections.length; i++) ...[
                            contentSections[i],
                            if (i != contentSections.length - 1)
                              SizedBox(height: spacing.step6),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Container(height: 1, color: palette.dividerColor),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.step5,
                  spacing.step4,
                  spacing.step5,
                  0,
                ),
                child: SizedBox(
                  width: _TaskFilterMetrics.contentWidth,
                  child: Row(
                    children: [
                      Expanded(
                        child: _TaskFilterActionButton(
                          key: const ValueKey(
                            'design-system-task-filter-clear',
                          ),
                          label: state.clearAllLabel,
                          palette: palette,
                          highlighted: false,
                          textStyle:
                              tokens.typography.styles.subtitle.subtitle1,
                          onTap: () {
                            final clearedState = state.clearAll();
                            onChanged(clearedState);
                            onClearAllPressed?.call(clearedState);
                          },
                        ),
                      ),
                      SizedBox(width: spacing.step5),
                      Expanded(
                        child: _TaskFilterActionButton(
                          key: const ValueKey(
                            'design-system-task-filter-apply',
                          ),
                          label: state.applyLabel,
                          palette: palette,
                          highlighted: true,
                          counter: state.appliedCount,
                          textStyle:
                              tokens.typography.styles.subtitle.subtitle1,
                          onTap: () => onApplyPressed?.call(state),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.step4),
              Padding(
                padding: EdgeInsets.only(bottom: spacing.step3),
                child: Container(
                  width: 134,
                  height: 5,
                  decoration: BoxDecoration(
                    color: palette.handleColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              SizedBox(
                height:
                    spacing.step5 + spacing.step2 + spacing.step1 / 2, // 21px
              ),
            ],
          ),
        ),
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
  final _TaskFilterPalette palette;
  final VoidCallback? onTap;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: palette.fieldBackground,
          borderRadius: BorderRadius.circular(_TaskFilterMetrics.fieldRadius),
          border: Border.all(color: palette.fieldOutline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(_TaskFilterMetrics.fieldRadius),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: _TaskFilterMetrics.fieldHeight,
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
                    Icons.keyboard_arrow_down_rounded,
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
  final _TaskFilterPalette palette;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;

    return Container(
      height: 28,
      padding: EdgeInsets.fromLTRB(
        spacing.step4,
        spacing.step1,
        spacing.step2,
        spacing.step1,
      ),
      decoration: BoxDecoration(
        color: palette.pillFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            option.label,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: palette.primaryText,
            ),
          ),
          SizedBox(width: spacing.step2 + spacing.step1), // 6px
          Material(
            color: Colors.transparent,
            child: Ink(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: palette.dismissFill,
                shape: BoxShape.circle,
              ),
              child: InkWell(
                key: ValueKey(
                  'design-system-task-filter-remove-${section.name}-${option.id}',
                ),
                borderRadius: BorderRadius.circular(999),
                onTap: onRemove,
                child: Icon(
                  Icons.close_rounded,
                  color: palette.dismissIcon,
                  size: 14,
                ),
              ),
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
  final _TaskFilterPalette palette;
  final TextStyle textStyle;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? palette.selectedPillBackground : palette.pillFill,
          borderRadius: BorderRadius.circular(_TaskFilterMetrics.pillRadius),
          border: Border.all(
            color: selected ? palette.accent : Colors.transparent,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(_TaskFilterMetrics.pillRadius),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: leading != null
                  ? spacing.step5
                  : spacing.step5 + spacing.step2,
              vertical:
                  spacing.step3 + spacing.step1 + spacing.step1 / 2, // 11px
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  leading!,
                  SizedBox(width: spacing.step3),
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
  final _TaskFilterPalette palette;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;

    if (glyph == DesignSystemTaskFilterGlyph.priorityP0) {
      return Icon(
        Icons.priority_high_rounded,
        color: palette.priorityP0,
        size: 18,
      );
    }

    final color = switch (glyph) {
      DesignSystemTaskFilterGlyph.priorityP1 => palette.priorityP1,
      DesignSystemTaskFilterGlyph.priorityP2 => palette.priorityP2,
      DesignSystemTaskFilterGlyph.priorityP3 => palette.priorityP3,
      _ => palette.secondaryText,
    };

    final alphaValues = switch (glyph) {
      DesignSystemTaskFilterGlyph.priorityP1 => const [0.7, 0.85, 1.0],
      DesignSystemTaskFilterGlyph.priorityP2 => const [0.8, 1.0, 0.6],
      DesignSystemTaskFilterGlyph.priorityP3 => const [1.0, 0.7, 0.45],
      _ => const [1.0, 1.0, 1.0],
    };

    return SizedBox(
      width: 18,
      height: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _TaskFilterMetrics.priorityBarHeights.length; i++)
            Padding(
              padding: EdgeInsets.only(
                right: i == _TaskFilterMetrics.priorityBarHeights.length - 1
                    ? 0
                    : spacing.step1 / 2,
              ),
              child: Container(
                width: 4,
                height: _TaskFilterMetrics.priorityBarHeights[i],
                decoration: BoxDecoration(
                  color: color.withValues(alpha: alphaValues[i]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskFilterActionButton extends StatelessWidget {
  const _TaskFilterActionButton({
    required this.label,
    required this.palette,
    required this.highlighted,
    required this.textStyle,
    required this.onTap,
    this.counter,
    super.key,
  });

  final String label;
  final _TaskFilterPalette palette;
  final bool highlighted;
  final TextStyle textStyle;
  final VoidCallback onTap;
  final int? counter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: highlighted ? palette.accent : palette.pillFill,
          borderRadius: BorderRadius.circular(_TaskFilterMetrics.actionRadius),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(_TaskFilterMetrics.actionRadius),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: textStyle.copyWith(
                    color: highlighted
                        ? palette.accentText
                        : palette.primaryText,
                  ),
                ),
                if (counter != null) ...[
                  SizedBox(width: spacing.step4 - spacing.step1),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: palette.applyBadgeFill,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$counter',
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(
                              color: highlighted
                                  ? palette.accentText
                                  : palette.primaryText,
                            ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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

class _TaskFilterPalette {
  const _TaskFilterPalette({
    required this.sheetBackground,
    required this.handleColor,
    required this.primaryText,
    required this.secondaryText,
    required this.pillFill,
    required this.selectedPillBackground,
    required this.fieldBackground,
    required this.fieldOutline,
    required this.dismissFill,
    required this.dismissIcon,
    required this.dividerColor,
    required this.accent,
    required this.accentText,
    required this.applyBadgeFill,
    required this.priorityP0,
    required this.priorityP1,
    required this.priorityP2,
    required this.priorityP3,
  });

  factory _TaskFilterPalette.fromTokens(DsTokens tokens) {
    final isDark = tokens.colors.background.level01.computeLuminance() < 0.5;

    if (isDark) {
      return _TaskFilterPalette(
        sheetBackground: const Color(0xFF1C1C1C),
        handleColor: tokens.colors.decorative.level02,
        primaryText: tokens.colors.text.highEmphasis,
        secondaryText: tokens.colors.text.mediumEmphasis,
        pillFill: const Color(0xFF2C2C2C),
        selectedPillBackground: const Color(0xFF253A36),
        fieldBackground: const Color(0xFF1C1C1C),
        fieldOutline: const Color(0xFF3A3A3A),
        dismissFill: const Color(0xFFCFCFCF),
        dismissIcon: const Color(0xFF373737),
        dividerColor: const Color(0xFF343434),
        accent: const Color(0xFF5AD5BE),
        accentText: const Color(0xFF0F2620),
        applyBadgeFill: const Color(0xFF8BE2D1),
        priorityP0: const Color(0xFFE2655D),
        priorityP1: const Color(0xFFF6A53B),
        priorityP2: const Color(0xFF5DB8FF),
        priorityP3: const Color(0xFF7AAE80),
      );
    }

    return _TaskFilterPalette(
      sheetBackground: const Color(0xFFFFFCF8),
      handleColor: tokens.colors.decorative.level02,
      primaryText: tokens.colors.text.highEmphasis,
      secondaryText: tokens.colors.text.mediumEmphasis,
      pillFill: const Color(0xFFF0EEE9),
      selectedPillBackground: const Color(0xFFE5F7F2),
      fieldBackground: const Color(0xFFFFFCF8),
      fieldOutline: const Color(0xFFD8D3CC),
      dismissFill: const Color(0xFF707070),
      dismissIcon: const Color(0xFFFFFFFF),
      dividerColor: const Color(0xFFE4DED7),
      accent: const Color(0xFF2CA990),
      accentText: const Color(0xFFFFFFFF),
      applyBadgeFill: const Color(0xFF1E8A74),
      priorityP0: const Color(0xFFD94A44),
      priorityP1: const Color(0xFFF19819),
      priorityP2: const Color(0xFF44AEEF),
      priorityP3: const Color(0xFF6C9E71),
    );
  }

  final Color sheetBackground;
  final Color handleColor;
  final Color primaryText;
  final Color secondaryText;
  final Color pillFill;
  final Color selectedPillBackground;
  final Color fieldBackground;
  final Color fieldOutline;
  final Color dismissFill;
  final Color dismissIcon;
  final Color dividerColor;
  final Color accent;
  final Color accentText;
  final Color applyBadgeFill;
  final Color priorityP0;
  final Color priorityP1;
  final Color priorityP2;
  final Color priorityP3;
}

class _TaskFilterMetrics {
  const _TaskFilterMetrics._();

  static const frameWidth = 402.0;
  static const frameHeight = 612.0;
  static const frameRadius = 32.0;
  static const contentWidth = 370.0;
  static const handleWidth = 40.0;
  static const handleHeight = 4.0;
  static const fieldHeight = 56.0;
  static const fieldRadius = 24.0;
  static const pillRadius = 24.0;
  static const actionRadius = 26.0;
  static const priorityBarHeights = [6.0, 10.0, 14.0];
}
