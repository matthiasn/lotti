import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/pages/tutorial/sliding_intro/tutorial_utils.dart';
import 'package:lotti/theme.dart';
import 'package:lottie/lottie.dart';

class TutorialSlide1 extends StatelessWidget {
  final int page;
  final ValueNotifier<double> notifier;

  const TutorialSlide1(
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
            alignment: const Alignment(0, -0.1),
            child: FractionallySizedBox(
              widthFactor: 0.6,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_0_1.png",
                  ),
                  offset: 300),
            ),
          ),
          Align(
            alignment: const Alignment(-0.6, 0.1),
            child: FractionallySizedBox(
              widthFactor: 0.3,
              heightFactor: 0.25,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_0_3.png",
                  ),
                  offset: 100),
            ),
          ),
          Align(
            alignment: const Alignment(-0.7, -0.48),
            child: FractionallySizedBox(
              widthFactor: 0.20,
              heightFactor: 0.15,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_0_4.png",
                  ),
                  offset: 100),
            ),
          ),
          Align(
            alignment: const Alignment(-0.92, -0.75),
            child: FractionallySizedBox(
              widthFactor: 0.06,
              heightFactor: 0.06,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_0_6.png",
                  ),
                  offset: 150),
            ),
          ),
          Align(
            alignment: const Alignment(-0.72, -0.86),
            child: FractionallySizedBox(
              widthFactor: 0.09,
              heightFactor: 0.08,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_0_7.png",
                  ),
                  offset: 50),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.8),
            child: FractionallySizedBox(
              widthFactor: 0.45,
              heightFactor: 0.15,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_0_5.png",
                  ),
                  offset: 140),
            ),
          ),
          Align(
            alignment: const Alignment(0.7, -0.60),
            child: FractionallySizedBox(
              widthFactor: 0.12,
              heightFactor: 0.10,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_0_2.png",
                  ),
                  offset: 140),
            ),
          ),
          Align(
            alignment: const Alignment(0.65, -0.8),
            child: FractionallySizedBox(
              widthFactor: 0.08,
              heightFactor: 0.06,
              child: SlidingContainer(
                child: Image.asset(
                  "assets/images/tutorial/s_0_8.png",
                ),
                offset: 140,
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SlidingContainer(
              offset: 250,
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  localizations.tutorialSlide1Title,
                  textAlign: TextAlign.center,
                  style: titleStyle.copyWith(fontSize: 40),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: SlidingContainer(
              offset: 250,
              child: Container(
                padding: const EdgeInsets.only(bottom: 80),
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
                padding: const EdgeInsets.only(bottom: 80),
                width: textBodyWidth(context),
                child: Text(
                  localizations.tutorialSlide1Body,
                  textAlign: TextAlign.justify,
                  style: titleStyle.copyWith(fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
