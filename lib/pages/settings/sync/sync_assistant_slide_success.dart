import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/pages/settings/sync/tutorial_utils.dart';
import 'package:lottie/lottie.dart';

class SyncAssistantSuccessSlide extends StatelessWidget {
  final int page;
  final ValueNotifier<double> notifier;

  const SyncAssistantSuccessSlide(
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
              title: localizations.syncAssistantHeadline6),
          Align(
            alignment: Alignment.center,
            child: SlidingContainer(
              offset: 300,
              child: Container(
                padding: const EdgeInsets.only(bottom: 180),
                width: textBodyWidth(context),
                child: Lottie.asset('assets/lottiefiles/angel.zip'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
