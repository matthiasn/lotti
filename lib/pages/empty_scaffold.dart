import 'package:flutter/material.dart';
import 'package:flutter_fadein/flutter_fadein.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

class EmptyScaffoldWithTitle extends StatelessWidget {
  const EmptyScaffoldWithTitle(
    this.title, {
    Key? key,
  }) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    return FadeIn(
      duration: const Duration(seconds: 2),
      child: Scaffold(
        backgroundColor: AppColors.bodyBgColor,
        appBar: TitleAppBar(
          title: title,
        ),
      ),
    );
  }
}
