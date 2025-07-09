import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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

  static Future<T?> showSinglePageModal<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    String? title,
    Widget? stickyActionBar,
    Widget Function(Widget)? modalDecorator,
    EdgeInsetsGeometry padding = WoltModalConfig.pagePadding,
    double? navBarHeight,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WoltModalSheet.show<T>(
      context: context,
      modalBarrierColor: isDark
          ? context.colorScheme.surfaceContainerLow.withAlpha(128)
          : context.colorScheme.outline.withAlpha(128),
      pageListBuilder: (modalSheetContext) {
        return [
          ModalUtils.modalSheetPage(
            context: modalSheetContext,
            stickyActionBar: stickyActionBar,
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
      modalDecorator: modalDecorator,
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

  static Future<bool> showConfirmationAndProgressModal({
    required BuildContext context,
    required String message,
    required String confirmLabel,
    required Widget Function(BuildContext) progressBuilder,
    required Future<void> Function() operation,
    bool isDestructive = true,
  }) async {
    final cancelLabel = context.messages.cancelButton.toUpperCase();
    final pageIndexNotifier = ValueNotifier(0);
    final theme = Theme.of(context);
    var confirmed = false;
    var operationCompleted = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await WoltModalSheet.show<void>(
      context: context,
      pageIndexNotifier: pageIndexNotifier,
      modalBarrierColor: isDark
          ? context.colorScheme.surfaceContainerLow.withAlpha(128)
          : context.colorScheme.outline.withAlpha(128),
      pageListBuilder: (modalSheetContext) {
        return [
          // Confirmation Page
          WoltModalSheetPage(
            backgroundColor: theme.colorScheme.inversePrimary,
            hasSabGradient: false,
            navBarHeight: 35,
            isTopBarLayerAlwaysVisible: false,
            trailingNavBarWidget: IconButton(
              padding: WoltModalConfig.pagePadding,
              icon: Icon(
                Icons.close,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              onPressed: () {
                confirmed = false;
                Navigator.of(context).pop();
              },
            ),
            child: Padding(
              padding: WoltModalConfig.pagePadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDestructive)
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 36,
                      color: theme.colorScheme.error,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            confirmed = false;
                            Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: theme.colorScheme.surfaceTint,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            cancelLabel,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onError,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            confirmed = true;
                            pageIndexNotifier.value = 1;
                            await operation();
                            operationCompleted = true;
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            confirmLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Progress Page
          WoltModalSheetPage(
            backgroundColor: theme.colorScheme.inversePrimary,
            hasSabGradient: false,
            navBarHeight: 35,
            isTopBarLayerAlwaysVisible: false,
            trailingNavBarWidget: IconButton(
              padding: WoltModalConfig.pagePadding,
              icon: Icon(
                Icons.close,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            child: Padding(
              padding: WoltModalConfig.pagePadding,
              child: progressBuilder(context),
            ),
          ),
        ];
      },
      modalTypeBuilder: ModalUtils.modalTypeBuilder,
      onModalDismissedWithBarrierTap: () {
        if (pageIndexNotifier.value == 0) {
          // On confirmation page, treat as cancel
          confirmed = false;
          Navigator.of(context).pop();
        } else if (operationCompleted) {
          // On progress page, only dismiss if operation is complete
          Navigator.of(context).pop();
        }
      },
    );

    return confirmed;
  }
}
