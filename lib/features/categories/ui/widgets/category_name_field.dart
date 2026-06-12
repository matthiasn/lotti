import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// A text field widget for editing category names, rendered with the
/// design-system text input.
///
/// This widget is designed to be independent of Riverpod for better
/// testability. The page owns the [controller] and change handling; in
/// create mode the field autofocuses and changes are tracked via the
/// controller only ([onChanged] is not invoked).
class CategoryNameField extends StatelessWidget {
  const CategoryNameField({
    required this.controller,
    required this.isCreateMode,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final bool isCreateMode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DesignSystemTextInput(
      controller: controller,
      label: context.messages.settingsCategoriesNameLabel,
      hintText: context.messages.enterCategoryName,
      autofocus: isCreateMode,
      textCapitalization: TextCapitalization.sentences,
      onChanged: isCreateMode ? null : onChanged,
    );
  }
}
