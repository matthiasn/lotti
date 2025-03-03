import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class ModalUtils {
  static WoltModalType modalTypeBuilder(
    BuildContext context,
  ) {
    final size = MediaQuery.of(context).size.width;
    if (size < WoltModalConfig.pageBreakpoint) {
      return WoltModalType.bottomSheet();
    } else {
      return WoltModalType.dialog();
    }
  }

  static WoltModalSheetPage modalSheetPage({
    required BuildContext context,
    required Widget child,
    String? title,
    Color? backgroundColor,
    bool isTopBarLayerAlwaysVisible = true,
    bool showCloseButton = true,
    EdgeInsetsGeometry padding = WoltModalConfig.pagePadding,
    double? navBarHeight,
  }) {
    final textTheme = context.textTheme;
    return WoltModalSheetPage(
      backgroundColor: context.colorScheme.surfaceContainerHigh,
      hasSabGradient: false,
      navBarHeight: navBarHeight,
      topBarTitle:
          title != null ? Text(title, style: textTheme.titleSmall) : null,
      isTopBarLayerAlwaysVisible: isTopBarLayerAlwaysVisible,
      trailingNavBarWidget: showCloseButton
          ? IconButton(
              padding: WoltModalConfig.pagePadding,
              icon: const Icon(Icons.close),
              onPressed: Navigator.of(context).pop,
            )
          : null,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }

  static Future<T?> showSinglePageModal<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    String? title,
    Widget Function(Widget)? modalDecorator,
    EdgeInsetsGeometry padding = WoltModalConfig.pagePadding,
    double? navBarHeight,
  }) async {
    return WoltModalSheet.show<T>(
      context: context,
      pageListBuilder: (modalSheetContext) {
        return [
          ModalUtils.modalSheetPage(
            context: modalSheetContext,
            title: title,
            child: builder(modalSheetContext),
            isTopBarLayerAlwaysVisible: title != null,
            showCloseButton: title != null,
            padding: padding,
            navBarHeight: navBarHeight,
          ),
        ];
      },
      modalTypeBuilder: ModalUtils.modalTypeBuilder,
      barrierDismissible: true,
      modalDecorator: modalDecorator,
    );
  }
}
