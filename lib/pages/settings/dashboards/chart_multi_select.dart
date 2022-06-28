import 'package:flutter/material.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme/theme.dart';
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
        backgroundColor: getIt<ThemeService>().colors.bodyBgColor,
        items: multiSelectItems,
        initialValue: const [],
        title: Text(title, style: titleStyle),
        checkColor: getIt<ThemeService>().colors.entryTextColor,
        selectedColor: Colors.blue,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: const BorderRadius.all(
            Radius.circular(40),
          ),
          border: Border.all(
            color: getIt<ThemeService>().colors.entryTextColor,
            width: 2,
          ),
        ),
        itemsTextStyle: multiSelectStyle,
        selectedItemsTextStyle: multiSelectStyle.copyWith(
          fontWeight: FontWeight.normal,
        ),
        unselectedColor: getIt<ThemeService>().colors.entryTextColor,
        searchIcon: Icon(
          Icons.search,
          size: 32,
          color: getIt<ThemeService>().colors.entryTextColor,
        ),
        searchTextStyle: formLabelStyle,
        searchHintStyle: formLabelStyle,
        buttonIcon: Icon(
          iconData,
          color: getIt<ThemeService>().colors.entryTextColor,
        ),
        buttonText: Text(
          buttonText,
          style: TextStyle(
            color: getIt<ThemeService>().colors.entryTextColor,
            fontSize: 16,
          ),
        ),
        onConfirm: onConfirm,
      ),
    );
  }
}
