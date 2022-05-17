import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/pages/tutorial/sliding_intro/tutorial_utils.dart';
import 'package:lotti/theme.dart';
import 'package:lottie/lottie.dart';

class TutorialSlide3 extends StatelessWidget {
  final int page;
  final ValueNotifier<double> notifier;

  const TutorialSlide3(
    this.page,
    this.notifier, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return SlidingPage(
      notifier: notifier,
      page: page,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: FractionallySizedBox(
              widthFactor: 1,
              heightFactor: 0.4,
              child: SlidingContainer(
                offset: 300,
                child: Image.asset(
                  "assets/images/tutorial/s_2_3.png",
                ),
              ),
            ),
          ),
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.55,
              heightFactor: 0.18,
              child: SlidingContainer(
                offset: 100,
                child: Image.asset(
                  "assets/images/tutorial/s_2_1.png",
                ),
              ),
            ),
          ),
          Opacity(
            opacity: 0.5,
            child: Align(
              alignment: const Alignment(0.3, -0.35),
              child: FractionallySizedBox(
                widthFactor: 0.75,
                heightFactor: 0.20,
                child: SlidingContainer(
                  offset: 170,
                  child: Image.asset(
                    "assets/images/tutorial/s_2_2.png",
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-0.2, -0.27),
            child: FractionallySizedBox(
              widthFactor: 0.16,
              heightFactor: 0.07,
              child: SlidingContainer(
                offset: 50,
                child: Image.asset(
                  "assets/images/tutorial/s_1_8.png",
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0.3, -0.35),
            child: FractionallySizedBox(
              widthFactor: 0.14,
              heightFactor: 0.07,
              child: SlidingContainer(
                offset: 150,
                child: Image.asset(
                  "assets/images/tutorial/s_2_6.png",
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0.8, -0.3),
            child: FractionallySizedBox(
              widthFactor: 0.15,
              heightFactor: 0.10,
              child: SlidingContainer(
                offset: 50,
                child: Image.asset(
                  "assets/images/tutorial/s_2_5.png",
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0.7, 0.1),
            child: FractionallySizedBox(
              widthFactor: 0.25,
              heightFactor: 0.15,
              child: SlidingContainer(
                offset: 200,
                child: Image.asset(
                  "assets/images/tutorial/s_2_7.png",
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SlidingContainer(
              offset: 250,
              child: Padding(
                padding: const EdgeInsets.only(top: 40.0),
                child: Text(
                  localizations.tutorialSlide3Title,
                  textAlign: TextAlign.center,
                  style: titleStyle.copyWith(
                    fontSize: 40,
                    color: AppColors.headerBgColor,
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
                  'assets/lottiefiles/pencil_write.json',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.1),
            child: SlidingContainer(
              offset: 250,
              child: Container(
                padding: const EdgeInsets.only(bottom: 80),
                width: textBodyWidth(context),
                child: Lottie.asset(
                  'assets/lottiefiles/gears.json',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(3, -0.5),
            child: SlidingContainer(
              offset: 250,
              child: Container(
                padding: const EdgeInsets.only(bottom: 80),
                width: textBodyWidth(context),
                child: Lottie.asset(
                  'assets/lottiefiles/a_mountain.json',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-3.6, 0.5),
            child: SlidingContainer(
              offset: 250,
              child: Container(
                padding: const EdgeInsets.only(bottom: 80),
                width: textBodyWidth(context),
                child: Lottie.asset(
                  'assets/lottiefiles/animated_laptop_.json',
                  width: 160,
                  height: 160,
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
                  localizations.tutorialSlide3Body,
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
