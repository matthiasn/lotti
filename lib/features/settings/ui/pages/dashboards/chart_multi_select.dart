import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
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

  Future<void> _showDialog(BuildContext context) async {
    final fontColor = context.textTheme.titleLarge?.color;
    final itemTextStyle = multiSelectStyle.copyWith(
      color: fontColor,
    );

    final selected = await showDialog<List<T?>>(
      context: context,
      builder: (dialogContext) {
        return MultiSelectDialog<T?>(
          items: multiSelectItems,
          initialValue: const [],
          title: Text(title, style: titleStyle),
          searchable: true,
          itemsTextStyle: itemTextStyle,
          selectedItemsTextStyle: itemTextStyle.copyWith(
            fontWeight: FontWeight.normal,
          ),
          unselectedColor: fontColor,
          searchIcon: const Icon(Icons.search),
          confirmText: const Text('Add'),
          cancelText: const Text('Cancel'),
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
        onTap: () => _showDialog(context),
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
