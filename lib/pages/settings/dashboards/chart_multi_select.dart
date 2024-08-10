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

  @override
  Widget build(BuildContext context) {
    final fontColor = context.textTheme.titleLarge?.color;
    final itemTextStyle = multiSelectStyle.copyWith(
      color: fontColor,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: MultiSelectBottomSheetField<T?>(
        searchable: true,
        items: multiSelectItems,
        initialValue: const [],
        initialChildSize: 0.4,
        maxChildSize: 0.9,
        title: Text(title, style: titleStyle),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(color: context.colorScheme.outline),
        ),
        itemsTextStyle: itemTextStyle,
        selectedItemsTextStyle: itemTextStyle.copyWith(
          fontWeight: FontWeight.normal,
        ),
        unselectedColor: fontColor,
        searchIcon: const Icon(Icons.search),
        buttonIcon: Icon(iconData),
        buttonText: Text(
          buttonText,
          semanticsLabel: semanticsLabel,
          style: context.textTheme.titleMedium,
        ),
        onConfirm: onConfirm,
      ),
    );
  }
}
