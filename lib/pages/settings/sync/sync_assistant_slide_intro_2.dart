import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/pages/settings/sync/tutorial_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lottie/lottie.dart';

class SyncAssistantIntroSlide2 extends StatelessWidget {
  final int page;
  final int pageCount;
  final ValueNotifier<double> notifier;

  const SyncAssistantIntroSlide2(
    this.page,
    this.pageCount,
    this.notifier, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return SlidingPage(
      page: page,
      notifier: notifier,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SyncAssistantHeaderWidget(
            index: page,
            pageCount: pageCount,
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: SlidingContainer(
              offset: 50,
              child: Container(
                padding: const EdgeInsets.only(bottom: 80),
                width: textBodyWidth(context),
                child: Opacity(
                  opacity: 0.4,
                  child: Lottie.asset(
                    'assets/lottiefiles/gears.json',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          AlignedText(isMobile
              ? localizations.syncAssistantPage2mobile
              : localizations.syncAssistantPage2),
        ],
      ),
    );
  }
}
