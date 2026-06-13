import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

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
    final selected = await ModalUtils.showSinglePageModal<List<T?>>(
      context: context,
      title: title,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: () => _showModal(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            border: Border.all(color: context.colorScheme.outline),
          ),
          child: Row(
            children: [
              Icon(iconData, color: context.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  buttonText,
                  semanticsLabel: semanticsLabel,
                  style: context.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_drop_down,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ],
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
    final colorScheme = context.colorScheme;
    // Calculate max height: screen height minus safe areas and modal chrome
    final maxListHeight = MediaQuery.of(context).size.height * 0.4;

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

        const SizedBox(height: 16),

        // Item list with constrained height
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxListHeight,
          ),
          child: _filteredItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.messages.multiSelectNoItemsFound,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked ?? false) {
                              _selected.add(item.value);
                            } else {
                              _selected.remove(item.value);
                            }
                          });
                        },
                        title: Text(
                          item.label,
                          style: context.textTheme.bodyLarge,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: colorScheme.primary,
                        checkboxShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    },
                  ),
                ),
        ),

        const SizedBox(height: 16),

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
            const SizedBox(width: 12),
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
