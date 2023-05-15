import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:meta/meta.dart';

@useResult
Future<T?> showModalActionSheet<T>({
  required BuildContext context,
  String? title,
  String? message,
  List<ModalSheetAction<T>> actions = const [],
  String? cancelLabel,
  bool isDismissible = true,
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet(
    constraints: const BoxConstraints(maxHeight: 150),
    context: context,
    isScrollControlled: false,
    isDismissible: isDismissible,
    useRootNavigator: useRootNavigator,
    builder: (context) {
      return ColoredBox(
        color: styleConfig().cardColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                title ?? '',
                style:
                    settingsCardTextStyle().copyWith(fontSize: fontSizeMedium),
              ),
            ),
            ...actions.map((action) {
              final color = action.isDestructiveAction
                  ? styleConfig().alarm
                  : styleConfig().primaryColor;

              void pop() {
                Navigator.pop<T>(context, action.key);
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: TextButton(
                  onPressed: pop,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        action.icon,
                        color: color,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        action.label,
                        style: settingsCardTextStyle().copyWith(color: color),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}
