import 'package:flutter/material.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Base class for selection modals using Wolt Modal Sheet
///
/// Provides consistent modal structure and behavior across
/// different selection modal types.
abstract class SelectionModalBase {
  /// Shows the modal with standard Wolt configuration.
  ///
  /// [builder] receives the modal sheet's own [BuildContext]. Use *that*
  /// context — not the caller's page context — whenever the content needs to
  /// close the sheet with `Navigator.of(...).pop()`.
  ///
  /// This matters on mobile: `showSinglePageModal` pushes the sheet onto the
  /// root navigator (width < `WoltModalConfig.pageBreakpoint`), while a page's
  /// own context resolves to its nested (Beamer) navigator. Popping the latter
  /// would dismiss the whole page instead of the sheet, discarding any pending
  /// selection. Popping via the [builder] context always targets the sheet.
  static void show({
    required BuildContext context,
    required String title,
    required Widget Function(BuildContext modalContext) builder,
  }) {
    ModalUtils.showSinglePageModal<void>(
      context: context,
      title: title,
      padding: EdgeInsets.zero,
      builder: builder,
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
  final EdgeInsets padding;

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
