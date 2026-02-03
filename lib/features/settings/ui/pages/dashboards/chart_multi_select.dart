import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/search/lotti_search_bar.dart';
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
  final _searchController = TextEditingController();

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    // Calculate max height: screen height minus safe areas and modal chrome
    final maxListHeight = MediaQuery.of(context).size.height * 0.4;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search field
        LottiSearchBar(
          controller: _searchController,
          hintText: context.messages.searchHint,
          onChanged: (value) => setState(() => _searchQuery = value),
          onClear: () => setState(() => _searchQuery = ''),
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
              : ListView.builder(
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

        const SizedBox(height: 16),

        // Action buttons - always visible
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.messages.cancelButton),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => widget.onConfirm(_selected.toList()),
                child: Text(
                  _selected.isEmpty
                      ? context.messages.multiSelectAddButton
                      : context.messages
                          .multiSelectAddButtonWithCount(_selected.length),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
