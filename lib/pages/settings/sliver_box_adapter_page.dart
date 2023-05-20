import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/habits/habit_page_app_bar.dart';

class SliverBoxAdapterPage extends StatelessWidget {
  const SliverBoxAdapterPage({
    required this.child,
    required this.title,
    super.key,
  });

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: styleConfig().negspace,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverTitleBar(title),
          SliverToBoxAdapter(
            child: child,
          )
        ],
      ),
    );
  }
}
