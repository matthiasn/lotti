import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/theme.dart';

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
                  child: Image.asset(
                    "assets/images/tutorial/s_1_1.png",
                  ),
                  offset: 300),
            ),
          ),
          Align(
            alignment: const Alignment(0.0, -0.5),
            child: FractionallySizedBox(
              widthFactor: 0.25,
              heightFactor: 0.10,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_1_8.png",
                  ),
                  offset: 170),
            ),
          ),
          Align(
            alignment: const Alignment(0.0, -0.30),
            child: FractionallySizedBox(
              widthFactor: 0.15,
              heightFactor: 0.1,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_1_5.png",
                  ),
                  offset: 50),
            ),
          ),
          Align(
            alignment: const Alignment(0.05, -0.45),
            child: FractionallySizedBox(
              widthFactor: 0.15,
              heightFactor: 0.8,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_1_3.png",
                  ),
                  offset: 150),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.15),
            child: FractionallySizedBox(
              widthFactor: 0.13,
              heightFactor: 0.1,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_1_4.png",
                  ),
                  offset: 50),
            ),
          ),
          Align(
            alignment: const Alignment(-0.5, 0),
            child: FractionallySizedBox(
              widthFactor: 0.20,
              heightFactor: 0.07,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_1_6.png",
                  ),
                  offset: 100),
            ),
          ),
          Align(
            alignment: const Alignment(-0.5, -0.25),
            child: FractionallySizedBox(
              widthFactor: 0.17,
              heightFactor: 0.08,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_1_7.png",
                  ),
                  offset: 240),
            ),
          ),
          Align(
            alignment: const Alignment(0.65, -0.35),
            child: FractionallySizedBox(
              widthFactor: 0.19,
              heightFactor: 0.06,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_1_2.png",
                  ),
                  offset: 850),
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
            alignment: Alignment.bottomCenter,
            child: SlidingContainer(
              offset: 250,
              child: Container(
                padding: const EdgeInsets.only(bottom: 64),
                width: 350,
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
