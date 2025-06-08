import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// Base class for selection modals using Wolt Modal Sheet
///
/// Provides consistent modal structure and behavior across
/// different selection modal types.
abstract class SelectionModalBase {
  /// Shows the modal with standard Wolt configuration
  static void show({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    WoltModalSheet.show<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      pageListBuilder: (modalSheetContext) => [
        buildModalPage(
          context: modalSheetContext,
          title: title,
          child: child,
        ),
      ],
    );
  }

  /// Builds a standard Wolt modal sheet page
  static WoltModalSheetPage buildModalPage({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    return WoltModalSheetPage(
      hasSabGradient: false,
      backgroundColor: context.colorScheme.surfaceContainerHigh,
      topBarTitle: Text(
        title,
        style: context.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.colorScheme.onSurface,
        ),
      ),
      trailingNavBarWidget: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(
          Icons.close,
          color: context.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        tooltip: 'Close',
      ),
      isTopBarLayerAlwaysVisible: true,
      child: child,
    );
  }
}

/// Base widget for selection modal content
///
/// Provides consistent padding and structure for modal content
class SelectionModalContent extends StatelessWidget {
  const SelectionModalContent({
    required this.children,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Standard list of selection options with consistent spacing
class SelectionOptionsList extends StatelessWidget {
  const SelectionOptionsList({
    required this.itemCount,
    required this.itemBuilder,
    this.separatorHeight = 8,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double separatorHeight;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: itemCount,
        separatorBuilder: (context, index) => SizedBox(height: separatorHeight),
        itemBuilder: itemBuilder,
      ),
    );
  }
}
