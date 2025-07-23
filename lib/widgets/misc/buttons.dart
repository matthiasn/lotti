import 'package:flutter/material.dart';
import 'package:lotti/widgets/lotti_secondary_button.dart';

class RoundedButton extends StatelessWidget {
  const RoundedButton(
    this.label, {
    required this.onPressed,
    super.key,
  });

  final String label;
  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return LottiSecondaryButton(
      label: label,
      onPressed: onPressed,
    );
  }
}
