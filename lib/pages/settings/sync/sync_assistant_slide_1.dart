import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/pages/tutorial/sliding_intro/tutorial_utils.dart';
import 'package:lotti/theme.dart';
import 'package:lottie/lottie.dart';

class SyncAssistantSlide1 extends StatelessWidget {
  final int page;
  final ValueNotifier<double> notifier;

  const SyncAssistantSlide1(
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
          Align(
            alignment: const Alignment(-0.82, 0.3),
            child: FractionallySizedBox(
              widthFactor: 0.1,
              heightFactor: 0.1,
              child: SlidingContainer(
                  offset: 150,
                  child: Image.asset(
                    "assets/images/tutorial/s_0_6.png",
                  )),
            ),
          ),
          Align(
            alignment: const Alignment(-0.52, -0.5),
            child: FractionallySizedBox(
              widthFactor: 0.1,
              heightFactor: 0.1,
              child: SlidingContainer(
                offset: 50,
                child: Image.asset(
                  "assets/images/tutorial/s_0_7.png",
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SlidingContainer(
              offset: 250,
              child: Padding(
                padding: const EdgeInsets.only(top: 32.0),
                child: Text(
                  localizations.syncAssistantHeadline1,
                  textAlign: TextAlign.center,
                  style: titleStyle.copyWith(fontSize: 40),
                ),
              ),
            ),
          ),
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
          Align(
            alignment: Alignment.bottomCenter,
            child: SlidingContainer(
              offset: 250,
              child: Container(
                padding: const EdgeInsets.only(bottom: 90),
                width: textBodyWidth(context),
                child: Text(
                  localizations.syncAssistantPage1,
                  textAlign: TextAlign.justify,
                  style: titleStyle.copyWith(fontSize: 28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
