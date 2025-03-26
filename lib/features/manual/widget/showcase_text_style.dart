import 'package:flutter/material.dart';

class ShowcaseTextStyle extends StatelessWidget {
  const ShowcaseTextStyle({
    required this.descriptionText,
    super.key,
  });

  final String descriptionText;

  @override
  Widget build(BuildContext context) {
    return Text(
      descriptionText,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
