import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/widgets/settings/settings_switch_row.dart';

/// `flutter_form_builder` toggle rendered as a design-system
/// [SettingsSwitchRow], so FormBuilder-driven definition forms share the
/// same switch treatment as the controller-driven ones.
///
/// Registers under [name] like any FormBuilder field; the row's title (and
/// optional [subtitle]/[icon]) render through the shared settings form
/// language.
class FormSwitch extends StatelessWidget {
  const FormSwitch({
    required this.initialValue,
    required this.name,
    required this.title,
    this.subtitle,
    this.icon,
    this.semanticsLabel,
    super.key,
  });

  final bool? initialValue;
  final String name;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<bool>(
      name: name,
      initialValue: initialValue ?? false,
      builder: (field) => Semantics(
        label: semanticsLabel,
        child: SettingsSwitchRow(
          title: title,
          subtitle: subtitle,
          icon: icon,
          value: field.value ?? false,
          onChanged: field.didChange,
        ),
      ),
    );
  }
}
