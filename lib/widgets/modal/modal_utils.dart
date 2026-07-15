import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class ModalUtils {
  static bool shouldUseRootNavigatorForBottomSheet(BuildContext context) {
    return MediaQuery.of(context).size.width < WoltModalConfig.pageBreakpoint;
  }

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

  /// Standard sheet content inset, derived entirely from design-system
  /// spacing tokens.
  static EdgeInsets defaultPadding(BuildContext context) {
    final spacing = _tokens(context).spacing;
    return EdgeInsets.fromLTRB(
      spacing.step5,
      spacing.step5,
      spacing.step5,
      spacing.step8,
    );
  }

  /// Shared text style for a modal's top-bar title, so plain-string titles and
  /// bespoke `titleWidget`s (e.g. a branded provider header) render identically
  /// and can't drift apart one tap into a multi-page flow.
  static TextStyle modalTitleStyle(BuildContext context) {
    final tokens = _tokens(context);
    return tokens.typography.styles.heading.heading3.copyWith(
      color: tokens.colors.text.highEmphasis,
      fontWeight: tokens.typography.weight.semiBold,
    );
  }

  static DsTokens _tokens(BuildContext context) {
    return Theme.of(context).extension<DsTokens>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? dsTokensDark
            : dsTokensLight);
  }

  static Widget _navigationButton({
    required BuildContext context,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final tokens = _tokens(context);
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.all(tokens.spacing.step4),
      icon: Container(
        padding: EdgeInsets.all(tokens.spacing.step3),
        decoration: BoxDecoration(
          color: tokens.colors.surface.enabled,
          borderRadius: BorderRadius.circular(tokens.radii.m),
        ),
        child: Icon(
          icon,
          color: tokens.colors.text.mediumEmphasis,
          size: tokens.spacing.step6,
        ),
      ),
      onPressed: onPressed,
    );
  }

  /// Creates a modern styled modal sheet page with enhanced visual effects
  static WoltModalSheetPage modalSheetPage({
    required BuildContext context,
    required Widget child,
    Widget? stickyActionBar,
    String? title,
    Widget? titleWidget,
    bool isTopBarLayerAlwaysVisible = true,
    bool showCloseButton = false,
    IconData closeButtonIcon = Icons.close_rounded,
    String? closeButtonTooltip,
    VoidCallback? onClosePressed,
    void Function()? onTapBack,
    EdgeInsets? padding,
    double? navBarHeight,
    bool hasTopBarLayer = true,
    Widget? leadingNavBarWidget,
  }) {
    final materialLocalizations = MaterialLocalizations.of(context);
    final tokens = _tokens(context);

    return WoltModalSheetPage(
      stickyActionBar: stickyActionBar,
      backgroundColor: getModalBackgroundColor(context),
      hasSabGradient: false,
      navBarHeight: navBarHeight ?? tokens.spacing.step10,
      hasTopBarLayer: hasTopBarLayer,
      topBarTitle:
          titleWidget ??
          (title != null
              ? Padding(
                  padding: EdgeInsets.only(top: tokens.spacing.step2),
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: modalTitleStyle(context),
                    ),
                  ),
                )
              : null),
      isTopBarLayerAlwaysVisible: isTopBarLayerAlwaysVisible,
      leadingNavBarWidget: onTapBack != null
          ? _navigationButton(
              context: context,
              tooltip: materialLocalizations.backButtonTooltip,
              icon: Icons.arrow_back_rounded,
              onPressed: onTapBack,
            )
          : leadingNavBarWidget,
      trailingNavBarWidget: showCloseButton
          ? Builder(
              builder: (navigationContext) => _navigationButton(
                context: navigationContext,
                tooltip:
                    closeButtonTooltip ??
                    materialLocalizations.closeButtonTooltip,
                icon: closeButtonIcon,
                onPressed: () {
                  onClosePressed?.call();
                  Navigator.of(navigationContext).pop();
                },
              ),
            )
          : null,
      child: Padding(
        padding: padding ?? defaultPadding(context),
        child: child,
      ),
    );
  }

  static Future<T?> showBottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = false,
    bool useRootNavigator = false,
    bool isDismissible = true,
    bool enableDrag = true,
    bool useSafeArea = false,
    Color? backgroundColor,
    Color? barrierColor,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    ShapeBorder? shape,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
      useRootNavigator:
          useRootNavigator || shouldUseRootNavigatorForBottomSheet(context),
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: useSafeArea,
      backgroundColor: backgroundColor,
      barrierColor: barrierColor,
      clipBehavior: clipBehavior,
      constraints: constraints,
      shape: shape,
    );
  }

  /// Creates an enhanced single page modal with modern styling
  static Future<T?> showSinglePageModal<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    String? title,
    Widget? titleWidget,
    Widget? stickyActionBar,
    Widget Function(BuildContext)? stickyActionBarBuilder,
    EdgeInsets? padding,
    double? navBarHeight,
    bool hasTopBarLayer = true,
    Widget Function(Widget)? modalDecorator,
    bool showCloseButton = true,
    IconData closeButtonIcon = Icons.close_rounded,
    String? closeButtonTooltip,
    VoidCallback? onClosePressed,
    bool? useRootNavigator,
  }) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return WoltModalSheet.show<T>(
      context: context,
      useRootNavigator:
          useRootNavigator ?? shouldUseRootNavigatorForBottomSheet(context),
      modalDecorator: modalDecorator,
      pageListBuilder: (modalSheetContext) {
        return [
          modalSheetPage(
            stickyActionBar:
                stickyActionBar ??
                stickyActionBarBuilder?.call(modalSheetContext),
            title: title,
            titleWidget: titleWidget,
            hasTopBarLayer: hasTopBarLayer,
            navBarHeight: navBarHeight,
            showCloseButton: showCloseButton,
            closeButtonIcon: closeButtonIcon,
            closeButtonTooltip: closeButtonTooltip,
            onClosePressed: onClosePressed,
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
    WoltModalType Function(BuildContext)? modalTypeBuilderOverride,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WoltModalSheet.show<T>(
      context: context,
      useRootNavigator: shouldUseRootNavigatorForBottomSheet(context),
      modalDecorator: modalDecorator,
      pageListBuilder: pageListBuilder,
      modalTypeBuilder: modalTypeBuilderOverride ?? modalTypeBuilder,
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
    Widget? titleWidget,
    bool isTopBarLayerAlwaysVisible = true,
    bool showCloseButton = true,
    void Function()? onTapBack,
    double? navBarHeight,
  }) {
    final materialLocalizations = MaterialLocalizations.of(context);
    final tokens = _tokens(context);

    return SliverWoltModalSheetPage(
      scrollController: scrollController,
      stickyActionBar: stickyActionBar,
      backgroundColor: getModalBackgroundColor(context),
      hasSabGradient: false,
      useSafeArea: true,
      resizeToAvoidBottomInset: true,
      navBarHeight: navBarHeight ?? tokens.spacing.step10,
      topBarTitle:
          titleWidget ??
          (title != null
              ? Padding(
                  padding: EdgeInsets.only(top: tokens.spacing.step2),
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: modalTitleStyle(context),
                    ),
                  ),
                )
              : null),
      isTopBarLayerAlwaysVisible: isTopBarLayerAlwaysVisible,
      leadingNavBarWidget: onTapBack != null
          ? _navigationButton(
              context: context,
              tooltip: materialLocalizations.backButtonTooltip,
              icon: Icons.arrow_back_rounded,
              onPressed: onTapBack,
            )
          : null,
      trailingNavBarWidget: showCloseButton
          ? Builder(
              builder: (navigationContext) => _navigationButton(
                context: navigationContext,
                tooltip: materialLocalizations.closeButtonTooltip,
                icon: Icons.close_rounded,
                onPressed: () => Navigator.of(navigationContext).pop(),
              ),
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
      useRootNavigator: shouldUseRootNavigatorForBottomSheet(context),
      modalBarrierColor: getModalBarrierColor(isDark: isDark, context: context),
      pageListBuilder: (modalSheetContext) => [builder(modalSheetContext)],
      modalTypeBuilder: modalTypeBuilder,
      modalDecorator: modalDecorator,
      barrierDismissible: barrierDismissible,
    );
  }

  static Color getModalBackgroundColor(BuildContext context) =>
      _tokens(context).colors.background.level02;
}
