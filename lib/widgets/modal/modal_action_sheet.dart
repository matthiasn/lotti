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
    constraints: const BoxConstraints(maxHeight: 200),
    context: context,
    isDismissible: isDismissible,
    useRootNavigator: useRootNavigator,
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      title,
                      style: settingsCardTextStyle.copyWith(fontSize: fontSizeMedium),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Text(
                      message,
                      style: settingsCardTextStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ...actions.map((action) {
                  final color = action.isDestructiveAction
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary;

                  void pop() {
                    Navigator.pop<T>(context, action.key);
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: pop,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (action.icon != null) ...[
                              Icon(
                                action.icon,
                                color: color,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                action.label,
                                style: (action.style ?? settingsCardTextStyle).copyWith(
                                  color: color,
                                  fontWeight: action.isDefaultAction ? FontWeight.bold : null,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (cancelLabel != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text(
                          cancelLabel,
                          style: settingsCardTextStyle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
