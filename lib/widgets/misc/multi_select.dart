import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:multi_select_flutter/bottom_sheet/multi_select_bottom_sheet_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';

class MultiSelect<T> extends StatelessWidget {
  const MultiSelect({
    required this.multiSelectItems,
    required this.onConfirm,
    required this.title,
    required this.buttonText,
    required this.iconData,
    required this.initialValue,
    super.key,
  });

  final List<MultiSelectItem<T?>> multiSelectItems;
  final void Function(List<T?>) onConfirm;
  final String title;
  final String buttonText;
  final IconData iconData;
  final List<T> initialValue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 321,
      child: MultiSelectBottomSheetField<T?>(
        backgroundColor: styleConfig().cardColor,
        items: multiSelectItems,
        initialChildSize: 0.8,
        maxChildSize: 0.8,
        title: Text(
          title,
          style: titleStyle(),
        ),
        checkColor: styleConfig().primaryTextColor,
        selectedColor: styleConfig().primaryColor,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withOpacity(0.2),
          border: Border.all(color: Colors.black26),
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
          color: styleConfig().secondaryTextColor,
        ),
        buttonText: Text(buttonText, style: searchFieldHintStyle()),
        onConfirm: onConfirm,
      ),
    );
  }
}
