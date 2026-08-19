import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// Upper bound on a create/edit form's height as a fraction of the viewport
/// — shared by `ProjectCreateForm`, `RelationshipForm` and `CheckInCaptureForm`
/// so the three modals can't drift apart.
const double modalMaxHeightFraction = 0.9;

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
    // A neutral scrim, not a tinted surface: a translucent gray surface laid
    // over the page read as haze rather than dimming — the backdrop got
    // *lighter*. Scrim is black in both design-system themes; dark mode dims
    // harder because its surfaces start dark.
    return isDark
        ? context.colorScheme.scrim.withAlpha(170)
        : context.colorScheme.scrim.withAlpha(110);
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

  /// A modal route name and heading share one semantic node so assistive
  /// technology announces the destination when a Wolt sheet takes focus.
  static Widget _modalTitle(BuildContext context, String title) {
    final tokens = _tokens(context);
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step2),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        header: true,
        namesRoute: true,
        scopesRoute: true,
        label: title,
        child: ExcludeSemantics(
          // Bounded: the title bar is a fixed height with the close button's
          // width mirrored on the leading edge, so a title that needs a second
          // line silently reflows the bar or clips mid-word. A long string, a
          // long locale or a large text scale should degrade to an ellipsis —
          // the route's semantics above still announce the full title.
          child: Text(
            title,
            style: modalTitleStyle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
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
    // A plain glyph at mediumEmphasis, not a filled chip: the dismiss
    // affordance is chrome, and its old surface-filled container was the
    // brightest element on a dark sheet — outshining the content it existed
    // to close. The IconButton's own padding keeps the 48pt hit target.
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.all(tokens.spacing.step4),
      icon: Icon(
        icon,
        color: tokens.colors.text.mediumEmphasis,
        // IconSizes.l, the callout/header glyph tier (24) — not the step6
        // gap that happens to share the number.
        size: IconSizes.l,
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
    IconData closeButtonIcon = LottiIcons.close,
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
          titleWidget ?? (title != null ? _modalTitle(context, title) : null),
      isTopBarLayerAlwaysVisible: isTopBarLayerAlwaysVisible,
      leadingNavBarWidget: onTapBack != null
          ? _navigationButton(
              context: context,
              tooltip: materialLocalizations.backButtonTooltip,
              icon: LottiIcons.back,
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
    IconData closeButtonIcon = LottiIcons.close,
    String? closeButtonTooltip,
    VoidCallback? onClosePressed,
    bool? useRootNavigator,
    WoltModalType Function(BuildContext)? modalTypeBuilderOverride,
  }) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return WoltModalSheet.show<T>(
      context: context,
      useRootNavigator:
          useRootNavigator ?? shouldUseRootNavigatorForBottomSheet(context),
      modalDecorator: modalDecorator,
      modalTypeBuilder: modalTypeBuilderOverride ?? modalTypeBuilder,
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
          titleWidget ?? (title != null ? _modalTitle(context, title) : null),
      isTopBarLayerAlwaysVisible: isTopBarLayerAlwaysVisible,
      leadingNavBarWidget: onTapBack != null
          ? _navigationButton(
              context: context,
              tooltip: materialLocalizations.backButtonTooltip,
              icon: LottiIcons.back,
              onPressed: onTapBack,
            )
          : null,
      trailingNavBarWidget: showCloseButton
          ? Builder(
              builder: (navigationContext) => _navigationButton(
                context: navigationContext,
                tooltip: materialLocalizations.closeButtonTooltip,
                icon: LottiIcons.close,
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
