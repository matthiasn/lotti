import 'package:flutter/material.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

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
    ModalUtils.showSinglePageModal<void>(
      context: context,
      title: title,
      padding: EdgeInsets.zero,
      builder: (BuildContext _) {
        return child;
      },
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
