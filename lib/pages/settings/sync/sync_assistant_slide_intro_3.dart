import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/pages/settings/sync/tutorial_utils.dart';
import 'package:lottie/lottie.dart';

class SyncAssistantIntroSlide3 extends StatelessWidget {
  const SyncAssistantIntroSlide3(
    this.page,
    this.pageCount,
    this.notifier, {
    super.key,
  });

  final int page;
  final int pageCount;
  final ValueNotifier<double> notifier;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

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
                padding: const EdgeInsets.only(bottom: 60),
                width: textBodyWidth(context),
                child: Opacity(
                  opacity: 0.4,
                  child: Lottie.asset(
                    'assets/lottiefiles/gears.json',
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          AlignedText(localizations.syncAssistantPage3),
        ],
      ),
    );
  }
}
