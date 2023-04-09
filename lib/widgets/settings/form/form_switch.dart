import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/themes/theme.dart';

class FormSwitch extends StatelessWidget {
  const FormSwitch({
    required this.initialValue,
    required this.name,
    required this.title,
    required this.activeColor,
    this.semanticsLabel,
    super.key,
  });

  final bool? initialValue;
  final String name;
  final String? semanticsLabel;
  final String title;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    return FormBuilderSwitch(
      name: name,
      initialValue: initialValue,
      title: Text(
        title,
        style: formLabelStyle(),
        semanticsLabel: semanticsLabel,
      ),
      activeColor: activeColor,
      inactiveThumbColor: styleConfig().secondaryTextColor,
      inactiveTrackColor: styleConfig().secondaryTextColor.withOpacity(0.2),
      decoration: switchDecoration,
    );
  }
}
