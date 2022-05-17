import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/pages/tutorial/sliding_intro/tutorial_utils.dart';
import 'package:lotti/theme.dart';
import 'package:lottie/lottie.dart';

class TutorialSlide2 extends StatelessWidget {
  final int page;
  final ValueNotifier<double> notifier;

  const TutorialSlide2(
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
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.45,
              heightFactor: 0.25,
              child: SlidingContainer(
                offset: 300,
                child: Image.asset(
                  "assets/images/tutorial/s_1_1.png",
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0.0, -0.5),
            child: FractionallySizedBox(
              widthFactor: 0.25,
              heightFactor: 0.10,
              child: SlidingContainer(
                offset: 170,
                child: Image.asset(
                  "assets/images/tutorial/s_1_8.png",
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0.0, -0.30),
            child: FractionallySizedBox(
              widthFactor: 0.15,
              heightFactor: 0.1,
              child: SlidingContainer(
                offset: 50,
                child: Image.asset(
                  "assets/images/tutorial/s_1_5.png",
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0.05, -0.45),
            child: FractionallySizedBox(
              widthFactor: 0.15,
              heightFactor: 0.8,
              child: SlidingContainer(
                offset: 150,
                child: Image.asset(
                  "assets/images/tutorial/s_1_3.png",
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.15),
            child: FractionallySizedBox(
              widthFactor: 0.13,
              heightFactor: 0.1,
              child: SlidingContainer(
                offset: 50,
                child: Image.asset(
                  "assets/images/tutorial/s_1_4.png",
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-0.5, 0),
            child: FractionallySizedBox(
              widthFactor: 0.20,
              heightFactor: 0.07,
              child: SlidingContainer(
                offset: 100,
                child: Image.asset(
                  "assets/images/tutorial/s_1_6.png",
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-0.5, -0.25),
            child: FractionallySizedBox(
              widthFactor: 0.17,
              heightFactor: 0.08,
              child: SlidingContainer(
                offset: 240,
                child: Image.asset(
                  "assets/images/tutorial/s_1_7.png",
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0.65, -0.35),
            child: FractionallySizedBox(
              widthFactor: 0.19,
              heightFactor: 0.06,
              child: SlidingContainer(
                offset: 850,
                child: Image.asset(
                  "assets/images/tutorial/s_1_2.png",
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SlidingContainer(
              offset: 250,
              child: Padding(
                padding: const EdgeInsets.only(top: 48.0),
                child: Text(
                  localizations.tutorialSlide2Title,
                  textAlign: TextAlign.center,
                  style: titleStyle.copyWith(
                    fontSize: 40,
                    color: AppColors.bodyBgColor,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-2, -0.6),
            child: SlidingContainer(
              offset: 250,
              child: Container(
                padding: const EdgeInsets.only(bottom: 80),
                width: textBodyWidth(context),
                child: Lottie.asset(
                  'assets/lottiefiles/penguin.json',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(2.8, 0.6),
            child: SlidingContainer(
              offset: 250,
              child: Container(
                padding: const EdgeInsets.only(bottom: 80),
                width: textBodyWidth(context),
                child: Lottie.asset(
                  'assets/lottiefiles/walking.json',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
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
                  localizations.tutorialSlide2Body,
                  textAlign: TextAlign.justify,
                  style: titleStyle.copyWith(
                    fontSize: 18,
                    color: AppColors.bodyBgColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
