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

  /// Creates a top bar title widget for modal sheets.
  /// Returns null if [title] is null.
  @visibleForTesting
  static Widget? buildTopBarTitle(
    BuildContext context,
    String? title,
  ) {
    if (title == null) return null;

    final textTheme = context.textTheme;
    final colorScheme = context.colorScheme;
    return Text(
      title,
      style: textTheme.titleSmall?.copyWith(color: colorScheme.outline),
    );
  }

  /// Creates a leading navigation bar widget (back button) for modal sheets.
  /// Returns null if [onTapBack] is null.
  @visibleForTesting
  static Widget? buildLeadingNavBarWidget(
    BuildContext context,
    void Function()? onTapBack,
  ) {
    if (onTapBack == null) return null;

    final colorScheme = context.colorScheme;
    return IconButton(
      padding: WoltModalConfig.pagePadding,
      icon: Icon(Icons.arrow_back, color: colorScheme.outline),
      onPressed: onTapBack,
    );
  }

  /// Creates a trailing navigation bar widget (close button) for modal sheets.
  /// Returns null if [showCloseButton] is false.
  @visibleForTesting
  static Widget? buildTrailingNavBarWidget(
    BuildContext context, {
    required bool showCloseButton,
  }) {
    if (!showCloseButton) return null;

    final colorScheme = context.colorScheme;
    return IconButton(
      padding: WoltModalConfig.pagePadding,
      icon: Icon(Icons.close, color: colorScheme.outline),
      onPressed: Navigator.of(context).pop,
    );
  }

  static WoltModalSheetPage modalSheetPage({
    required BuildContext context,
    required Widget child,
    Widget? stickyActionBar,
    String? title,
    Color? backgroundColor,
    bool isTopBarLayerAlwaysVisible = true,
    bool showCloseButton = true,
    void Function()? onTapBack,
    EdgeInsetsGeometry padding = WoltModalConfig.pagePadding,
    double? navBarHeight,
  }) {
    return WoltModalSheetPage(
      backgroundColor: context.colorScheme.surfaceContainer,
      stickyActionBar: stickyActionBar,
      hasSabGradient: false,
      navBarHeight: navBarHeight ?? 55,
      topBarTitle: buildTopBarTitle(context, title),
      isTopBarLayerAlwaysVisible: isTopBarLayerAlwaysVisible,
      leadingNavBarWidget: buildLeadingNavBarWidget(context, onTapBack),
      trailingNavBarWidget:
          buildTrailingNavBarWidget(context, showCloseButton: showCloseButton),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }

  static SliverWoltModalSheetPage sliverModalSheetPage({
    required BuildContext context,
    required List<Widget> slivers,
    Widget? stickyActionBar,
    ScrollController? scrollController,
    String? title,
    Color? backgroundColor,
    bool isTopBarLayerAlwaysVisible = true,
    bool showCloseButton = true,
    void Function()? onTapBack,
    double? navBarHeight,
  }) {
    return SliverWoltModalSheetPage(
      scrollController: scrollController,
      stickyActionBar: stickyActionBar,
      backgroundColor: context.colorScheme.surfaceContainer,
      hasSabGradient: true,
      useSafeArea: true,
      resizeToAvoidBottomInset: true,
      navBarHeight: navBarHeight ?? 55,
      topBarTitle: buildTopBarTitle(context, title),
      isTopBarLayerAlwaysVisible: isTopBarLayerAlwaysVisible,
      leadingNavBarWidget: buildLeadingNavBarWidget(context, onTapBack),
      trailingNavBarWidget:
          buildTrailingNavBarWidget(context, showCloseButton: showCloseButton),
      mainContentSliversBuilder: (BuildContext context) {
        return slivers;
      },
    );
  }

  static Future<T?> showSingleSliverWoltModalSheetPageModal<T>({
    required BuildContext context,
    required SliverWoltModalSheetPage Function(BuildContext) builder,
    Widget Function(Widget)? modalDecorator,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WoltModalSheet.show<T>(
      context: context,
      modalBarrierColor: isDark
          ? context.colorScheme.surfaceContainerLow.withAlpha(128)
          : context.colorScheme.outline.withAlpha(128),
      pageListBuilder: (modalSheetContext) => [builder(modalSheetContext)],
      modalTypeBuilder: ModalUtils.modalTypeBuilder,
      modalDecorator: modalDecorator,
    );
  }
}
