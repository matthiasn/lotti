import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lotti/themes/theme.dart';

class FormTextField extends StatelessWidget {
  const FormTextField({
    required this.initialValue,
    required this.name,
    required this.labelText,
    this.semanticsLabel,
    super.key,
    this.fieldRequired = true,
    this.large = false,
  });

  final String initialValue;
  final String? semanticsLabel;
  final String name;
  final String labelText;
  final bool fieldRequired;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.titleMedium;
    return FormBuilderTextField(
      name: name,
      minLines: 1,
      maxLines: 3,
      initialValue: initialValue,
      textCapitalization: TextCapitalization.sentences,
      keyboardAppearance: Theme.of(context).brightness,
      validator: fieldRequired ? FormBuilderValidators.required() : null,
      style: large ? style?.copyWith(fontSize: fontSizeLarge) : style,
      decoration: inputDecoration(
        labelText: labelText,
        semanticsLabel: semanticsLabel,
        themeData: Theme.of(context),
      ),
    );
  }
}
