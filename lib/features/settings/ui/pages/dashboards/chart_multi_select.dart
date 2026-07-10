import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/aggregation_label.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

/// Dropdown-style "add charts" entry used in the dashboard editor.
///
/// Renders a bordered, labeled row that opens a searchable multi-select
/// modal over [multiSelectItems]; when the user confirms a non-empty
/// selection, [onConfirm] receives the chosen values so the editor can
/// append the corresponding chart items. Parameterized over `T` so one
/// widget serves habits, measurables, health, survey, and workout pickers.
class ChartMultiSelect<T> extends StatelessWidget {
  const ChartMultiSelect({
    required this.multiSelectItems,
    required this.onConfirm,
    required this.title,
    required this.buttonText,
    required this.semanticsLabel,
    required this.iconData,
    super.key,
  });

  final List<MultiSelectItem<T?>> multiSelectItems;
  final void Function(List<T?>) onConfirm;
  final String title;
  final String buttonText;
  final String semanticsLabel;
  final IconData iconData;

  Future<void> _showModal(BuildContext context) async {
    final tokens = context.designTokens;
    final selected = await ModalUtils.showSinglePageModal<List<T?>>(
      context: context,
      title: title,
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      builder: (modalContext) {
        return _MultiSelectList<T>(
          items: multiSelectItems,
          onConfirm: (values) => Navigator.of(modalContext).pop(values),
        );
      },
    );

    if (selected != null && selected.isNotEmpty) {
      onConfirm(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ChartSelectTrigger(
      buttonText: buttonText,
      semanticsLabel: semanticsLabel,
      iconData: iconData,
      onTap: () => _showModal(context),
    );
  }
}

class MeasurementChartMultiSelect extends StatelessWidget {
  const MeasurementChartMultiSelect({
    required this.items,
    required this.onConfirm,
    required this.title,
    required this.buttonText,
    required this.semanticsLabel,
    required this.iconData,
    super.key,
  });

  final List<MeasurableDataType> items;
  final void Function(List<DashboardMeasurementItem>) onConfirm;
  final String title;
  final String buttonText;
  final String semanticsLabel;
  final IconData iconData;

  Future<void> _showModal(BuildContext context) async {
    final tokens = context.designTokens;
    final selected =
        await ModalUtils.showSinglePageModal<List<DashboardMeasurementItem>>(
          context: context,
          title: title,
          padding: EdgeInsets.all(tokens.spacing.cardPadding),
          builder: (modalContext) {
            return _MeasurementSelectList(
              items: items,
              onConfirm: (values) => Navigator.of(modalContext).pop(values),
            );
          },
        );

    if (selected != null && selected.isNotEmpty) {
      onConfirm(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ChartSelectTrigger(
      buttonText: buttonText,
      semanticsLabel: semanticsLabel,
      iconData: iconData,
      onTap: () => _showModal(context),
    );
  }
}

class _ChartSelectTrigger extends StatelessWidget {
  const _ChartSelectTrigger({
    required this.buttonText,
    required this.semanticsLabel,
    required this.iconData,
    required this.onTap,
  });

  final String buttonText;
  final String semanticsLabel;
  final IconData iconData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final radius = BorderRadius.circular(tokens.radii.s);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.step2),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            color: tokens.colors.background.level01,
            borderRadius: radius,
            border: Border.all(color: tokens.colors.decorative.level02),
          ),
          child: Semantics(
            button: true,
            enabled: true,
            label: semanticsLabel,
            excludeSemantics: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.step4,
                  vertical: spacing.step3,
                ),
                child: Row(
                  children: [
                    Icon(
                      iconData,
                      color: tokens.colors.text.mediumEmphasis,
                      size: spacing.step6,
                    ),
                    SizedBox(width: spacing.step3),
                    Flexible(
                      child: Text(
                        buttonText,
                        style: tokens.typography.styles.body.bodyLarge.copyWith(
                          color: tokens.colors.text.highEmphasis,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: spacing.step2),
                    Icon(
                      Icons.arrow_drop_down,
                      color: tokens.colors.text.mediumEmphasis,
                      size: spacing.step6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Searchable multi-select list for use inside WoltModalSheet
class _MultiSelectList<T> extends StatefulWidget {
  const _MultiSelectList({
    required this.items,
    required this.onConfirm,
  });

  final List<MultiSelectItem<T?>> items;
  final void Function(List<T?>) onConfirm;

  @override
  State<_MultiSelectList<T>> createState() => _MultiSelectListState<T>();
}

class _MultiSelectListState<T> extends State<_MultiSelectList<T>> {
  final Set<T?> _selected = {};
  String _searchQuery = '';

  List<MultiSelectItem<T?>> get _filteredItems {
    if (_searchQuery.isEmpty) return widget.items;
    final lowerCaseQuery = _searchQuery.toLowerCase();
    return widget.items
        .where(
          (item) => item.label.toLowerCase().contains(lowerCaseQuery),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.4;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search field — the design-system search used across the
        // settings revamp (flat, token-bordered); the old LottiSearchBar
        // carried a gradient fill and drop shadow that read as foreign
        // inside the modal. Its clear button fires `onChanged('')`.
        DesignSystemSearch(
          hintText: context.messages.searchHint,
          onChanged: (value) => setState(() => _searchQuery = value),
        ),

        SizedBox(height: spacing.step4),

        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxListHeight,
          ),
          child: _filteredItems.isEmpty
              ? _ModalEmptyState(
                  message: context.messages.multiSelectNoItemsFound,
                )
              : _SelectableListFrame(
                  child: _HoverlessList(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filteredItems.length,
                      separatorBuilder: (context, index) => Divider(
                        height: spacing.step1,
                        color: tokens.colors.decorative.level01,
                      ),
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final isSelected = _selected.contains(item.value);

                        return _PickerSelectRow(
                          label: item.label,
                          selected: isSelected,
                          onChanged: (checked) {
                            setState(() {
                              if (checked) {
                                _selected.add(item.value);
                              } else {
                                _selected.remove(item.value);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
        ),

        SizedBox(height: spacing.step4),

        _ModalActionRow(
          selectedCount: _selected.length,
          onConfirm: _selected.isEmpty
              ? null
              : () => widget.onConfirm(_selected.toList()),
        ),
      ],
    );
  }
}

class _MeasurementSelectList extends StatefulWidget {
  const _MeasurementSelectList({
    required this.items,
    required this.onConfirm,
  });

  final List<MeasurableDataType> items;
  final void Function(List<DashboardMeasurementItem>) onConfirm;

  @override
  State<_MeasurementSelectList> createState() => _MeasurementSelectListState();
}

class _MeasurementSelectListState extends State<_MeasurementSelectList> {
  final Map<String, AggregationType> _selected = {};
  String _searchQuery = '';

  List<MeasurableDataType> get _filteredItems {
    if (_searchQuery.isEmpty) return widget.items;
    final lowerCaseQuery = _searchQuery.toLowerCase();
    return widget.items
        .where(
          (item) => item.displayName.toLowerCase().contains(lowerCaseQuery),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.48;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.messages.dashboardMeasurementAggregationHelp,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        if (_selected.isNotEmpty) ...[
          SizedBox(height: spacing.step2),
          Text(
            context.messages.dashboardMeasurementSelectedCount(
              _selected.length,
            ),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.interactive.enabled,
            ),
          ),
        ],
        SizedBox(height: spacing.step3),
        DesignSystemSearch(
          hintText: context.messages.searchHint,
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        SizedBox(height: spacing.step3),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxListHeight),
          child: _filteredItems.isEmpty
              ? _ModalEmptyState(
                  message: context.messages.multiSelectNoItemsFound,
                )
              : _SelectableListFrame(
                  child: _HoverlessList(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filteredItems.length,
                      separatorBuilder: (context, index) => Divider(
                        height: spacing.step1,
                        color: tokens.colors.decorative.level01,
                      ),
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final selectedAggregation = _selected[item.id];

                        return _MeasurementSelectRow(
                          item: item,
                          selectedAggregation: selectedAggregation,
                          onSelectedChanged: (checked) {
                            setState(() {
                              if (checked ?? false) {
                                _selected[item.id] =
                                    item.aggregationType ??
                                    AggregationType.dailySum;
                              } else {
                                _selected.remove(item.id);
                              }
                            });
                          },
                          onAggregationChanged: (aggregationType) {
                            setState(() {
                              _selected[item.id] = aggregationType;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
        ),
        SizedBox(height: spacing.step4),
        _ModalActionRow(
          selectedCount: _selected.length,
          onConfirm: _selected.isEmpty ? null : _confirm,
          addButtonLabel: _selected.isEmpty
              ? null
              : context.messages.dashboardMeasurementAddButtonWithCount(
                  _selected.length,
                ),
        ),
      ],
    );
  }

  void _confirm() {
    widget.onConfirm(
      [
        for (final entry in _selected.entries)
          DashboardMeasurementItem(
            id: entry.key,
            aggregationType: entry.value,
          ),
      ],
    );
  }
}

class _MeasurementSelectRow extends StatelessWidget {
  const _MeasurementSelectRow({
    required this.item,
    required this.selectedAggregation,
    required this.onSelectedChanged,
    required this.onAggregationChanged,
  });

  final MeasurableDataType item;
  final AggregationType? selectedAggregation;
  final ValueChanged<bool?> onSelectedChanged;
  final ValueChanged<AggregationType> onAggregationChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final selected = selectedAggregation != null;

    return _PickerSelectRow(
      label: item.displayName,
      selected: selected,
      onChanged: onSelectedChanged,
      child: selected
          ? Padding(
              padding: EdgeInsetsDirectional.only(
                top: spacing.step3,
                end: spacing.step3,
                bottom: spacing.step3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.messages.dashboardMeasurementAggregationFor(
                      item.displayName,
                    ),
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                  SizedBox(height: spacing.step3),
                  Wrap(
                    spacing: spacing.step2,
                    runSpacing: spacing.step2,
                    children: [
                      for (final aggregationType in AggregationType.values)
                        DesignSystemChip(
                          label: aggregationTypeLabel(
                            context.messages,
                            aggregationType,
                          ),
                          selected: aggregationType == selectedAggregation,
                          onPressed: () =>
                              onAggregationChanged(aggregationType),
                        ),
                    ],
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class _PickerSelectRow extends StatelessWidget {
  const _PickerSelectRow({
    required this.label,
    required this.selected,
    required this.onChanged,
    this.child,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final trailingContent = child;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: selected
              ? tokens.colors.background.level02
              : tokens.colors.background.level01,
          border: selected
              ? BorderDirectional(
                  start: BorderSide(
                    color: tokens.colors.interactive.enabled,
                    width: spacing.step1,
                  ),
                )
              : null,
        ),
        child: InkWell(
          onTap: () => onChanged(!selected),
          child: Semantics(
            button: true,
            explicitChildNodes: true,
            selected: selected,
            label: label,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.step4,
                vertical: spacing.step3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExcludeSemantics(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: tokens.typography.styles.body.bodyMedium
                                .copyWith(
                                  color: tokens.colors.text.highEmphasis,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: spacing.step3),
                        _PickerSelectionIndicator(selected: selected),
                      ],
                    ),
                  ),
                  ?trailingContent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerSelectionIndicator extends StatelessWidget {
  const _PickerSelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final size = spacing.step5;

    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? tokens.colors.interactive.enabled
              : Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          border: Border.all(
            color: selected
                ? tokens.colors.interactive.enabled
                : tokens.colors.decorative.level01,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check_rounded,
                color: tokens.colors.text.onInteractiveAlert,
                size: spacing.step4,
              )
            : null,
      ),
    );
  }
}

class _ModalEmptyState extends StatelessWidget {
  const _ModalEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step6),
        child: Text(
          message,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ),
    );
  }
}

class _ModalActionRow extends StatelessWidget {
  const _ModalActionRow({
    required this.selectedCount,
    required this.onConfirm,
    this.addButtonLabel,
  });

  final int selectedCount;
  final VoidCallback? onConfirm;
  final String? addButtonLabel;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        DesignSystemButton(
          label: context.messages.cancelButton,
          variant: DesignSystemButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SizedBox(width: spacing.step3),
        DesignSystemButton(
          label:
              addButtonLabel ??
              (selectedCount == 0
                  ? context.messages.multiSelectAddButton
                  : context.messages.multiSelectAddButtonWithCount(
                      selectedCount,
                    )),
          onPressed: onConfirm,
        ),
      ],
    );
  }
}

class _SelectableListFrame extends StatelessWidget {
  const _SelectableListFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.s);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          color: tokens.colors.background.level01,
          borderRadius: radius,
          border: Border.all(color: tokens.colors.decorative.level01),
        ),
        child: child,
      ),
    );
  }
}

/// Strips the Material hover/splash/highlight from selectable rows so desktop
/// hover doesn't paint a grey band across the framed list. Scoped to the list
/// so the modal's action buttons keep their own overlays.
class _HoverlessList extends StatelessWidget {
  const _HoverlessList({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: child,
    );
  }
}
