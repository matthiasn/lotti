import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// Enhanced modal utilities with modern, high-budget styling
class ModernModalUtils {
  /// Creates a modern styled modal sheet page with enhanced visual effects
  static WoltModalSheetPage modernModalSheetPage({
    required BuildContext context,
    required Widget child,
    Widget? stickyActionBar,
    String? title,
    bool isTopBarLayerAlwaysVisible = true,
    bool showCloseButton = true,
    void Function()? onTapBack,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    double? navBarHeight,
    bool showDivider = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = context.colorScheme;

    return WoltModalSheetPage(
      backgroundColor: isDark
          ? Color.lerp(
              colorScheme.surface,
              colorScheme.surfaceContainerHighest,
              0.3,
            )!
          : colorScheme.surface,
      stickyActionBar: stickyActionBar,
      hasSabGradient: false,
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
      child: Stack(
        children: [
          // Subtle gradient overlay
          if (isDark)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.primaryContainer.withValues(alpha: 0.03),
                      colorScheme.primaryContainer.withValues(alpha: 0.01),
                    ],
                  ),
                ),
              ),
            ),
          // Content
          Padding(
            padding: padding,
            child: Column(
              children: [
                if (showDivider)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.outline.withValues(alpha: 0),
                          colorScheme.outline.withValues(alpha: 0.2),
                          colorScheme.outline.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Creates an enhanced single page modal with modern styling
  static Future<T?> showModernModal<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    String? title,
    Widget? stickyActionBar,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    double? navBarHeight,
    bool showDivider = false,
  }) async {
    return WoltModalSheet.show<T>(
      context: context,
      pageListBuilder: (modalSheetContext) {
        return [
          modernModalSheetPage(
            context: modalSheetContext,
            stickyActionBar: stickyActionBar,
            title: title,
            child: builder(modalSheetContext),
            isTopBarLayerAlwaysVisible: title != null,
            padding: padding,
            navBarHeight: navBarHeight,
            showDivider: showDivider,
          ),
        ];
      },
      modalTypeBuilder: (context) {
        final size = MediaQuery.of(context).size.width;
        if (size < WoltModalConfig.pageBreakpoint) {
          return WoltModalType.bottomSheet();
        } else {
          return WoltModalType.dialog();
        }
      },
      modalDecorator: (child) {
        return Stack(
          children: [
            // Enhanced backdrop blur
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: context.colorScheme.scrim.withValues(alpha: 0.5),
              ),
            ),
            child,
          ],
        );
      },
      barrierDismissible: true,
    );
  }

  /// Creates a modal with multiple pages and enhanced navigation
  static Future<T?> showMultiPageModernModal<T>({
    required BuildContext context,
    required List<WoltModalSheetPage> Function(BuildContext) pageListBuilder,
    ValueNotifier<int>? pageIndexNotifier,
    bool barrierDismissible = true,
  }) async {
    return WoltModalSheet.show<T>(
      context: context,
      pageListBuilder: pageListBuilder,
      modalTypeBuilder: (context) {
        final size = MediaQuery.of(context).size.width;
        if (size < WoltModalConfig.pageBreakpoint) {
          return WoltModalType.bottomSheet();
        } else {
          return WoltModalType.dialog();
        }
      },
      modalDecorator: (child) {
        return Stack(
          children: [
            // Enhanced backdrop blur
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: context.colorScheme.scrim.withValues(alpha: 0.5),
              ),
            ),
            child,
          ],
        );
      },
      pageIndexNotifier: pageIndexNotifier,
      barrierDismissible: barrierDismissible,
    );
  }
}
