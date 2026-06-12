import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';

/// `flutter_form_builder` text field rendered with the design-system input
/// components, so FormBuilder-driven definition forms (habits, measurables,
/// dashboards) look identical to controller-driven ones (categories,
/// labels).
///
/// Registers under [name] like any FormBuilder field (value collection,
/// validation, dirty tracking); the visual layer is
/// [DesignSystemTextInput] — or [DesignSystemTextarea] when [multiline].
class SettingsFormTextField extends StatefulWidget {
  const SettingsFormTextField({
    required this.initialValue,
    required this.name,
    required this.labelText,
    this.hintText,
    this.semanticsLabel,
    this.fieldRequired = true,
    this.multiline = false,
    this.autofocus = false,
    super.key,
  });

  final String initialValue;
  final String name;
  final String labelText;
  final String? hintText;
  final String? semanticsLabel;
  final bool fieldRequired;

  /// Renders a [DesignSystemTextarea] (3–5 lines) instead of the
  /// single-line input.
  final bool multiline;

  final bool autofocus;

  @override
  State<SettingsFormTextField> createState() => _SettingsFormTextFieldState();
}

class _SettingsFormTextFieldState extends State<SettingsFormTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<String>(
      name: widget.name,
      initialValue: widget.initialValue,
      validator: widget.fieldRequired ? FormBuilderValidators.required() : null,
      builder: (field) => widget.multiline
          ? DesignSystemTextarea(
              controller: _controller,
              label: widget.labelText,
              hintText: widget.hintText,
              errorText: field.errorText,
              semanticsLabel: widget.semanticsLabel,
              maxLines: 5,
              onChanged: field.didChange,
            )
          : DesignSystemTextInput(
              controller: _controller,
              label: widget.labelText,
              hintText: widget.hintText,
              errorText: field.errorText,
              semanticsLabel: widget.semanticsLabel,
              autofocus: widget.autofocus,
              textCapitalization: TextCapitalization.sentences,
              onChanged: field.didChange,
            ),
    );
  }
}
