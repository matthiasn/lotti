import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
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
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(spacing.step6),
                    child: Text(
                      context.messages.multiSelectNoItemsFound,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ),
                )
              : _HoverlessList(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final isSelected = _selected.contains(item.value);

                      return DesignSystemCheckbox(
                        value: isSelected,
                        label: item.label,
                        onChanged: (checked) {
                          setState(() {
                            if (checked ?? false) {
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

        SizedBox(height: spacing.step4),

        // Action buttons — design-system buttons, end-aligned (secondary
        // then primary), mirroring the detail-page action bar language.
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            DesignSystemButton(
              label: context.messages.cancelButton,
              variant: DesignSystemButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            SizedBox(width: spacing.step3),
            DesignSystemButton(
              label: _selected.isEmpty
                  ? context.messages.multiSelectAddButton
                  : context.messages.multiSelectAddButtonWithCount(
                      _selected.length,
                    ),
              onPressed: _selected.isEmpty
                  ? null
                  : () => widget.onConfirm(_selected.toList()),
            ),
          ],
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
        SizedBox(height: spacing.step4),
        DesignSystemSearch(
          hintText: context.messages.searchHint,
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        SizedBox(height: spacing.step4),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxListHeight),
          child: _filteredItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(spacing.step6),
                    child: Text(
                      context.messages.multiSelectNoItemsFound,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ),
                )
              : _HoverlessList(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredItems.length,
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
        SizedBox(height: spacing.step4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            DesignSystemButton(
              label: context.messages.cancelButton,
              variant: DesignSystemButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            SizedBox(width: spacing.step3),
            DesignSystemButton(
              label: _selected.isEmpty
                  ? context.messages.multiSelectAddButton
                  : context.messages.multiSelectAddButtonWithCount(
                      _selected.length,
                    ),
              onPressed: _selected.isEmpty ? null : _confirm,
            ),
          ],
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
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesignSystemCheckbox(
          value: selected,
          label: item.displayName,
          onChanged: onSelectedChanged,
        ),
        if (selected) ...[
          SizedBox(height: spacing.step2),
          Padding(
            padding: EdgeInsetsDirectional.only(start: spacing.step7),
            child: Wrap(
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
                    onPressed: () => onAggregationChanged(aggregationType),
                  ),
              ],
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.step3),
      child: selected
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.colors.background.level02,
                borderRadius: BorderRadius.circular(tokens.radii.s),
                border: Border.all(color: tokens.colors.decorative.level01),
              ),
              child: Padding(
                padding: EdgeInsets.all(spacing.step2),
                child: content,
              ),
            )
          : content,
    );
  }
}

/// Strips the Material hover/splash/highlight from its subtree so the
/// `CheckboxListTile` rows don't paint a grey hover band on desktop —
/// the rows are passive selectables, not buttons. Scoped to the list so
/// the modal's action buttons keep their own overlays.
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
