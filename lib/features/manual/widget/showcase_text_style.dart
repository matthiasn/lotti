import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

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

class ShowcaseTitleText extends StatelessWidget {
  const ShowcaseTitleText({required this.titleText, super.key});

  final String titleText;

  @override
  Widget build(BuildContext context) {
    return Text(
      titleText,
      style: appBarTextStyleNewLarge.copyWith(
        color: Theme.of(context).primaryColor,
      ),
    );
  }
}
