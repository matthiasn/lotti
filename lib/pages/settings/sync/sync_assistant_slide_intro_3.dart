import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/pages/settings/sync/tutorial_utils.dart';
import 'package:lotti/theme.dart';
import 'package:lottie/lottie.dart';

class SyncAssistantIntroSlide3 extends StatelessWidget {
  final int page;
  final ValueNotifier<double> notifier;

  const SyncAssistantIntroSlide3(
    this.page,
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
              title: localizations.syncAssistantHeadline4),
          Align(
            alignment: Alignment.bottomRight,
            child: SlidingContainer(
              offset: 50,
              child: Container(
                padding: const EdgeInsets.only(bottom: 60),
                width: textBodyWidth(context),
                child: Lottie.asset(
                  'assets/lottiefiles/gears.json',
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: SlidingContainer(
              offset: 250,
              child: SizedBox(
                width: textBodyWidth(context),
                child: Text(
                  localizations.syncAssistantPage3,
                  textAlign: TextAlign.justify,
                  style: titleStyle.copyWith(fontSize: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
