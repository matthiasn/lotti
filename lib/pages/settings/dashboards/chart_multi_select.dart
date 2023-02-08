import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class ChartMultiSelect<T> extends StatelessWidget {
  const ChartMultiSelect({
    required this.multiSelectItems,
    required this.onConfirm,
    required this.title,
    required this.buttonText,
    required this.iconData,
    super.key,
  });

  final List<MultiSelectItem<T?>> multiSelectItems;
  final void Function(List<T?>) onConfirm;
  final String title;
  final String buttonText;
  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: MultiSelectBottomSheetField<T?>(
        searchable: true,
        backgroundColor: styleConfig().cardColor,
        items: multiSelectItems,
        initialValue: const [],
        title: Text(
          title,
          style: titleStyle(),
        ),
        checkColor: styleConfig().primaryTextColor,
        selectedColor: styleConfig().primaryColor,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: const BorderRadius.all(
            Radius.circular(40),
          ),
          border: Border.all(
            color: styleConfig().secondaryTextColor,
          ),
        ),
        itemsTextStyle: multiSelectStyle(),
        selectedItemsTextStyle: multiSelectStyle().copyWith(
          fontWeight: FontWeight.normal,
        ),
        unselectedColor: styleConfig().primaryTextColor,
        searchIcon: Icon(
          Icons.search,
          size: fontSizeLarge,
          color: styleConfig().primaryTextColor,
        ),
        searchTextStyle: formLabelStyle(),
        searchHintStyle: formLabelStyle(),
        buttonIcon: Icon(
          iconData,
          color: styleConfig().primaryTextColor,
        ),
        buttonText: Text(
          buttonText,
          style: TextStyle(
            color: styleConfig().primaryTextColor,
            fontSize: fontSizeMedium,
          ),
        ),
        onConfirm: onConfirm,
      ),
    );
  }
}
