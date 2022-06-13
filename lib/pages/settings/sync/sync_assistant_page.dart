import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lotti/pages/settings/sync/sync_assistant_slide_config.dart';
import 'package:lotti/pages/settings/sync/sync_assistant_slide_intro_1.dart';
import 'package:lotti/pages/settings/sync/sync_assistant_slide_intro_2.dart';
import 'package:lotti/pages/settings/sync/sync_assistant_slide_intro_3.dart';
import 'package:lotti/pages/settings/sync/sync_assistant_slide_qr_code.dart';
import 'package:lotti/pages/settings/sync/sync_assistant_slide_success.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

class SyncAssistantPage extends StatefulWidget {
  const SyncAssistantPage({
    Key? key,
  }) : super(key: key);

  @override
  State<SyncAssistantPage> createState() => _SyncAssistantPageState();
}

class _SyncAssistantPageState extends State<SyncAssistantPage> {
  final ValueNotifier<double> notifier = ValueNotifier(0);
  final _pageCtrl = PageController();
  int pageCount = 6;

  @override
  initState() {
    super.initState();
    if (Platform.isIOS || Platform.isAndroid) {
      pageCount = 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.bodyBgColor,
      appBar: TitleAppBar(title: localizations.settingsSyncCfgTitle),
      body: Center(
          child: Stack(
        children: <Widget>[
          SlidingTutorial(
            controller: _pageCtrl,
            pageCount: pageCount,
            notifier: notifier,
          ),

          /// Separator.
          Align(
            alignment: const Alignment(0, 0.85),
            child: Container(
              width: double.infinity,
              height: 0.5,
              color: Colors.white,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                _pageCtrl.previousPage(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.linear,
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
                textDirection: TextDirection.rtl,
              ),
              onPressed: () {
                _pageCtrl.nextPage(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.linear,
                );
              },
            ),
          ),

          Align(
            alignment: const Alignment(0, 0.94),
            child: SlidingIndicator(
              indicatorCount: pageCount,
              notifier: notifier,
              activeIndicator: const Icon(
                Icons.check_circle,
                color: Color(0xFF29B6F6),
              ),
              inActiveIndicator: SvgPicture.asset(
                'assets/images/tutorial/hollow_circle.svg',
              ),
              margin: 8,
              inactiveIndicatorSize: 14,
              activeIndicatorSize: 14,
            ),
          )
        ],
      )),
    );
  }
}

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
        AppColors.headerBgColor,
        AppColors.bodyBgColor,
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
    switch (index) {
      case 0:
        return SyncAssistantIntroSlide1(
            index, widget.pageCount, widget.notifier);
      case 1:
        return SyncAssistantIntroSlide2(
            index, widget.pageCount, widget.notifier);
      case 2:
        return SyncAssistantConfigSlide(
            index, widget.pageCount, widget.notifier);
      case 3:
        return SyncAssistantIntroSlide3(
            index, widget.pageCount, widget.notifier);
      case 4:
        return SyncAssistantQrCodeSlide(
            index, widget.pageCount, widget.notifier);
      case 5:
        return SyncAssistantSuccessSlide(
            index, widget.pageCount, widget.notifier);
      default:
        throw ArgumentError("Unknown position: $index");
    }
  }

  _onScroll() {
    widget.notifier.value = _pageController.page ?? 0;
  }
}
