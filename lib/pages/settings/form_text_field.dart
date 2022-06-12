import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lotti/theme.dart';

class FormTextField extends StatelessWidget {
  const FormTextField({
    Key? key,
    required this.initialValue,
    required this.name,
    required this.labelText,
    this.fieldRequired = true,
  }) : super(key: key);

  final String initialValue;
  final String name;
  final String labelText;
  final bool fieldRequired;

  @override
  Widget build(BuildContext context) {
    return FormBuilderTextField(
      name: name,
      minLines: 1,
      maxLines: 3,
      initialValue: initialValue,
      textCapitalization: TextCapitalization.sentences,
      keyboardAppearance: Brightness.dark,
      validator: fieldRequired ? FormBuilderValidators.required() : null,
      style: labelStyle,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: AppColors.entryTextColor, fontSize: 16),
      ),
    );
  }
}
