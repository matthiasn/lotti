import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/pages/tutorial/sliding_intro/sync_assistant_slide_1.dart';
import 'package:lotti/pages/tutorial/sliding_intro/tutorial_slide_2.dart';
import 'package:lotti/theme.dart';

import 'tutorial_slide_3.dart';

class SlidingTutorial extends StatefulWidget {
  const SlidingTutorial({
    required this.controller,
    required this.notifier,
    required this.pageCount,
    Key? key,
  }) : super(key: key);

  final ValueNotifier<double> notifier;
  final int pageCount;
  final PageController controller;

  @override
  State<StatefulWidget> createState() => _SlidingTutorial();
}

class _SlidingTutorial extends State<SlidingTutorial> {
  late PageController _pageController;

  @override
  void initState() {
    _pageController = widget.controller;
    _pageController.addListener(_onScroll);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackgroundColor(
      pageController: _pageController,
      pageCount: widget.pageCount,
      colors: [
        AppColors.bodyBgColor,
        AppColors.bottomNavIconSelected,
        AppColors.error,
        AppColors.tagColor,
        AppColors.outboxPendingColor,
        AppColors.outboxSuccessColor,
      ],
      child: Stack(
        children: [
          PageView(
            controller: _pageController,
            children: List<Widget>.generate(
              widget.pageCount,
              (index) => _getPageByIndex(index),
            ),
          ),
        ],
      ),
    );
  }

  /// Create different [SlidingPage] for indexes.
  Widget _getPageByIndex(int index) {
    switch (index % 3) {
      case 0:
        return TutorialSlide1(index, widget.notifier);
      case 1:
        return TutorialSlide2(index, widget.notifier);
      case 2:
        return TutorialSlide3(index, widget.notifier);
      default:
        throw ArgumentError("Unknown position: $index");
    }
  }

  /// Notify [SlidingPage] about current page changes.
  _onScroll() {
    widget.notifier.value = _pageController.page ?? 0;
  }
}
