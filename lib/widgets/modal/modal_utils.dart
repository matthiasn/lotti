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

  static Color getModalBarrierColor({
    required bool isDark,
    required BuildContext context,
  }) {
    return isDark
        ? context.colorScheme.surfaceContainerLow.withAlpha(180)
        : context.colorScheme.outline.withAlpha(128);
  }

  static const defaultPadding =
      EdgeInsets.only(left: 20, top: 20, right: 20, bottom: 40);

  /// Creates a modern styled modal sheet page with enhanced visual effects
  static WoltModalSheetPage modalSheetPage({
    required BuildContext context,
    required Widget child,
    Widget? stickyActionBar,
    String? title,
    Widget? titleWidget,
    bool isTopBarLayerAlwaysVisible = true,
    bool showCloseButton = false,
    void Function()? onTapBack,
    EdgeInsets padding = defaultPadding,
    double? navBarHeight,
    bool hasTopBarLayer = true,
    Widget? leadingNavBarWidget,
  }) {
    final colorScheme = context.colorScheme;

    return WoltModalSheetPage(
      stickyActionBar: stickyActionBar,
      backgroundColor: getModalBackgroundColor(context),
      hasSabGradient: false,
      navBarHeight: navBarHeight ?? 65,
      hasTopBarLayer: hasTopBarLayer,
      topBarTitle: titleWidget ??
          (title != null
              ? Container(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    title,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                )
              : null),
      isTopBarLayerAlwaysVisible: isTopBarLayerAlwaysVisible,
      leadingNavBarWidget: onTapBack != null
          ? IconButton(
              padding: const EdgeInsets.all(12),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              onPressed: onTapBack,
            )
          : leadingNavBarWidget,
      trailingNavBarWidget: showCloseButton
          ? IconButton(
              padding: const EdgeInsets.all(12),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              onPressed: Navigator.of(context).pop,
            )
          : null,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }

  /// Creates an enhanced single page modal with modern styling
  static Future<T?> showSinglePageModal<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    String? title,
    Widget? titleWidget,
    Widget? stickyActionBar,
    EdgeInsets padding = defaultPadding,
    double? navBarHeight,
    bool hasTopBarLayer = true,
    Widget Function(Widget)? modalDecorator,
    bool showCloseButton = true,
  }) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return WoltModalSheet.show<T>(
      context: context,
      modalDecorator: modalDecorator,
      pageListBuilder: (modalSheetContext) {
        return [
          modalSheetPage(
            stickyActionBar: stickyActionBar,
            title: title,
            titleWidget: titleWidget,
            hasTopBarLayer: hasTopBarLayer,
            navBarHeight: navBarHeight,
            showCloseButton: showCloseButton,
            padding: padding,
            child: builder(modalSheetContext),
            context: modalSheetContext,
          ),
        ];
      },
      modalTypeBuilder: modalTypeBuilder,
      barrierDismissible: true,
      modalBarrierColor: getModalBarrierColor(isDark: isDark, context: context),
    );
  }

  /// Creates a modal with multiple pages and enhanced navigation
  static Future<T?> showMultiPageModal<T>({
    required BuildContext context,
    required List<SliverWoltModalSheetPage> Function(BuildContext)
        pageListBuilder,
    ValueNotifier<int>? pageIndexNotifier,
    bool barrierDismissible = true,
    Widget Function(Widget)? modalDecorator,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WoltModalSheet.show<T>(
      context: context,
      modalDecorator: modalDecorator,
      pageListBuilder: pageListBuilder,
      modalTypeBuilder: modalTypeBuilder,
      pageIndexNotifier: pageIndexNotifier,
      barrierDismissible: barrierDismissible,
      modalBarrierColor: getModalBarrierColor(isDark: isDark, context: context),
    );
  }

  /// Creates a modern styled sliver modal sheet page with enhanced visual effects
  static SliverWoltModalSheetPage sliverModalSheetPage({
    required BuildContext context,
    required List<Widget> slivers,
    Widget? stickyActionBar,
    ScrollController? scrollController,
    String? title,
    bool isTopBarLayerAlwaysVisible = true,
    bool showCloseButton = true,
    void Function()? onTapBack,
    double? navBarHeight,
  }) {
    final colorScheme = context.colorScheme;

    return SliverWoltModalSheetPage(
      scrollController: scrollController,
      stickyActionBar: stickyActionBar,
      backgroundColor: getModalBackgroundColor(context),
      hasSabGradient: false,
      useSafeArea: true,
      resizeToAvoidBottomInset: true,
      navBarHeight: navBarHeight ?? 65,
      topBarTitle: title != null
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                title,
                style: context.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            )
          : null,
      isTopBarLayerAlwaysVisible: isTopBarLayerAlwaysVisible,
      leadingNavBarWidget: onTapBack != null
          ? IconButton(
              padding: const EdgeInsets.all(12),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              onPressed: onTapBack,
            )
          : null,
      trailingNavBarWidget: showCloseButton
          ? IconButton(
              padding: const EdgeInsets.all(12),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              onPressed: Navigator.of(context).pop,
            )
          : null,
      mainContentSliversBuilder: (BuildContext context) {
        return slivers;
      },
    );
  }

  /// Creates a single sliver modal sheet page modal with modern styling
  static Future<T?> showSingleSliverPageModal<T>({
    required BuildContext context,
    required SliverWoltModalSheetPage Function(BuildContext) builder,
    Widget Function(Widget)? modalDecorator,
    bool barrierDismissible = true,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WoltModalSheet.show<T>(
      context: context,
      modalBarrierColor: getModalBarrierColor(isDark: isDark, context: context),
      pageListBuilder: (modalSheetContext) => [builder(modalSheetContext)],
      modalTypeBuilder: modalTypeBuilder,
      modalDecorator: modalDecorator,
      barrierDismissible: barrierDismissible,
    );
  }

  static Color? getModalBackgroundColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.colorScheme.surfaceContainerHigh;
  }
}
