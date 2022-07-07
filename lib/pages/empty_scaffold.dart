import 'package:flutter/material.dart';
import 'package:flutter_fadein/flutter_fadein.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

class EmptyScaffoldWithTitle extends StatelessWidget {
  const EmptyScaffoldWithTitle(
    this.title, {
    super.key,
    this.body,
  });

  final String title;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    return FadeIn(
      duration: const Duration(seconds: 2),
      child: Scaffold(
        backgroundColor: colorConfig().bodyBgColor,
        appBar: TitleAppBar(
          title: title,
        ),
        body: body,
      ),
    );
  }
}
