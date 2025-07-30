import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/form/form_widgets.dart';

/// A text field widget for editing category names.
///
/// This widget is designed to be independent of Riverpod for better testability.
/// It accepts callbacks for handling name changes and validation.
class CategoryNameField extends StatelessWidget {
  const CategoryNameField({
    required this.controller,
    required this.isCreateMode,
    this.onChanged,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final bool isCreateMode;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return LottiTextField(
      controller: controller,
      labelText: context.messages.settingsCategoriesNameLabel,
      hintText: context.messages.enterCategoryName,
      prefixIcon: Icons.category_outlined,
      onChanged: isCreateMode ? null : onChanged,
      validator: validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return context.messages.categoryNameRequired;
            }
            return null;
          },
    );
  }
}
