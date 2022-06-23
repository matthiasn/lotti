import 'package:flutter/material.dart';
import 'package:lotti/theme.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class ChartMultiSelect<T> extends StatelessWidget {
  const ChartMultiSelect({
    super.key,
    required this.multiSelectItems,
    required this.onConfirm,
    required this.title,
    required this.buttonText,
    required this.iconData,
  });

  final List<MultiSelectItem<T?>> multiSelectItems;
  final void Function(List<T?>) onConfirm;
  final String title;
  final String buttonText;
  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
      ),
      child: MultiSelectDialogField<T?>(
        searchable: true,
        backgroundColor: AppColors.bodyBgColor,
        items: multiSelectItems,
        initialValue: const [],
        title: Text(title, style: titleStyle),
        checkColor: AppColors.entryTextColor,
        selectedColor: Colors.blue,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: const BorderRadius.all(
            Radius.circular(40),
          ),
          border: Border.all(
            color: AppColors.entryTextColor,
            width: 2,
          ),
        ),
        itemsTextStyle: multiSelectStyle,
        selectedItemsTextStyle: multiSelectStyle.copyWith(
          fontWeight: FontWeight.normal,
        ),
        unselectedColor: AppColors.entryTextColor,
        searchIcon: Icon(
          Icons.search,
          size: 32,
          color: AppColors.entryTextColor,
        ),
        searchTextStyle: formLabelStyle,
        searchHintStyle: formLabelStyle,
        buttonIcon: Icon(
          iconData,
          color: AppColors.entryTextColor,
        ),
        buttonText: Text(
          buttonText,
          style: TextStyle(
            color: AppColors.entryTextColor,
            fontSize: 16,
          ),
        ),
        onConfirm: onConfirm,
      ),
    );
  }
}
