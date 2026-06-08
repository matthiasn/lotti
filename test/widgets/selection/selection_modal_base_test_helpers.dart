import 'package:flutter/material.dart';
import 'package:lotti/widgets/selection/selection_save_button.dart';

// Concrete implementation for testing
class TestSelectionModal extends StatelessWidget {
  const TestSelectionModal({
    required this.title,
    required this.child,
    this.onSave,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final VoidCallback? onSave;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // Since SelectionModalBase.show() shows a modal, we'll just render the content directly for testing
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          Flexible(child: child),
          if (onSave != null) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SelectionSaveButton(onPressed: onSave),
            ),
          ],
          ?trailing,
        ],
      ),
    );
  }
}
