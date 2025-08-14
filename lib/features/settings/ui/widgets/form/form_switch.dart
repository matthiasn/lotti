import 'package:flutter/material.dart';
import 'package:lotti/widgets/selection/unified_toggle.dart';

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
    return UnifiedFormBuilderToggle(
      name: name,
      title: title,
      initialValue: initialValue,
      activeColor: activeColor,
      semanticsLabel: semanticsLabel,
    );
  }
}
