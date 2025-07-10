import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/app_bar/sliver_title_bar.dart';

class SliverBoxAdapterPage extends StatefulWidget {
  const SliverBoxAdapterPage({
    required this.child,
    required this.title,
    this.showBackButton = false,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final String title;
  final bool showBackButton;
  final EdgeInsets padding;

  @override
  State<SliverBoxAdapterPage> createState() => _SliverBoxAdapterPageState();
}

class _SliverBoxAdapterPageState extends State<SliverBoxAdapterPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    final listener = getIt<UserActivityService>().updateActivity;
    _scrollController.addListener(listener);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          SliverShowCaseTitleBar(
            title: widget.title,
            pinned: true,
            showBackButton: widget.showBackButton,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: widget.padding,
              child: widget.child
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 500)),
            ),
          ),
        ],
      ),
    );
  }
}
