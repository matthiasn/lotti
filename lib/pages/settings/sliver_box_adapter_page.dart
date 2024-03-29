import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lotti/widgets/app_bar/sliver_title_bar.dart';

class SliverBoxAdapterPage extends StatelessWidget {
  const SliverBoxAdapterPage({
    required this.child,
    required this.title,
    this.showBackButton = false,
    super.key,
  });

  final Widget child;
  final String title;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverTitleBar(
            title,
            pinned: true,
            showBackButton: showBackButton,
          ),
          SliverToBoxAdapter(
            child: child
                .animate()
                .fadeIn(duration: const Duration(milliseconds: 500)),
          ),
        ],
      ),
    );
  }
}
