import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lotti/blocs/sync/sync_config_state.dart';
import 'package:lotti/pages/settings/sync/sync_assistant_nav.dart';
import 'package:lotti/pages/settings/sync/sync_assistant_slide_config.dart';
import 'package:lotti/pages/settings/sync/sync_assistant_slide_intro_1.dart';
import 'package:lotti/pages/settings/sync/sync_assistant_slide_intro_2.dart';
import 'package:lotti/pages/settings/sync/sync_assistant_slide_intro_3.dart';
import 'package:lotti/pages/settings/sync/sync_assistant_slide_qr_code.dart';
import 'package:lotti/pages/settings/sync/sync_assistant_slide_success.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

class SyncAssistantPage extends StatefulWidget {
  const SyncAssistantPage({super.key});

  @override
  State<SyncAssistantPage> createState() => _SyncAssistantPageState();
}

class _SyncAssistantPageState extends State<SyncAssistantPage> {
  final ValueNotifier<double> notifier = ValueNotifier(0);
  final _pageCtrl = PageController();
  int pageCount = 6;

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS || Platform.isAndroid) {
      pageCount = 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: styleConfig().negspace,
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
                color: styleConfig().primaryTextColor,
              ),
            ),
            SyncNavPrevious(
              pageCtrl: _pageCtrl,
              notifier: notifier,
            ),
            SyncNavNext(
              pageCtrl: _pageCtrl,
              guardedPage: 2,
              pageCount: pageCount,
              notifier: notifier,
              guardedPagesAllowed: {
                2: (SyncConfigState state) => state.maybeMap(
                      configured: (_) => true,
                      imapSaved: (_) => true,
                      orElse: () => false,
                    ),
                4: (SyncConfigState state) => state.maybeMap(
                      configured: (_) => true,
                      orElse: () => false,
                    ),
              },
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
                inactiveIndicatorSize: 14,
                activeIndicatorSize: 14,
              ),
            )
          ],
        ),
      ),
    );
  }
}

class SlidingTutorial extends StatefulWidget {
  const SlidingTutorial({
    required this.controller,
    required this.notifier,
    required this.pageCount,
    super.key,
  });

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
        styleConfig().secondaryTextColor,
        styleConfig().ice,
        styleConfig().secondaryTextColor,
      ],
      child: Stack(
        children: [
          PageView(
            controller: _pageController,
            children: List<Widget>.generate(
              widget.pageCount,
              _getPageByIndex,
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
          index,
          widget.pageCount,
          widget.notifier,
        );
      case 1:
        return SyncAssistantIntroSlide2(
          index,
          widget.pageCount,
          widget.notifier,
        );
      case 2:
        return SyncAssistantConfigSlide(
          index,
          widget.pageCount,
          widget.notifier,
        );
      case 3:
        return SyncAssistantIntroSlide3(
          index,
          widget.pageCount,
          widget.notifier,
        );
      case 4:
        return SyncAssistantQrCodeSlide(
          index,
          widget.pageCount,
          widget.notifier,
        );
      case 5:
        return SyncAssistantSuccessSlide(
          index,
          widget.pageCount,
          widget.notifier,
        );
      default:
        throw ArgumentError('Unknown position: $index');
    }
  }

  void _onScroll() {
    widget.notifier.value = _pageController.page ?? 0;
  }
}
