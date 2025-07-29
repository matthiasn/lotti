import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/lotti_tertiary_button.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';

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
                    padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
                    child: Text(
                      title,
                      style: settingsCardTextStyle.copyWith(
                        fontSize: fontSizeMedium,
                      ),
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
                  void pop() {
                    Navigator.pop<T>(context, action.key);
                  }

                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: LottiTertiaryButton(
                      label: action.label,
                      onPressed: pop,
                      icon: action.icon,
                      fullWidth: true,
                      isDestructive: action.isDestructiveAction,
                    ),
                  );
                }),
                if (cancelLabel != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: LottiTertiaryButton(
                      label: cancelLabel,
                      onPressed: () => Navigator.pop(context),
                      fullWidth: true,
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
