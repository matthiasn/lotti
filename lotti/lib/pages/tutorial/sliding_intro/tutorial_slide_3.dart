import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/theme.dart';

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
                  child: Image.asset(
                    "assets/images/tutorial/s_2_3.png",
                  ),
                  offset: 300),
            ),
          ),
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.55,
              heightFactor: 0.18,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_2_1.png",
                  ),
                  offset: 100),
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
                    child: Image.asset(
                      "assets/images/tutorial/s_2_2.png",
                    ),
                    offset: 170),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-0.2, -0.27),
            child: FractionallySizedBox(
              widthFactor: 0.16,
              heightFactor: 0.07,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_1_8.png",
                  ),
                  offset: 50),
            ),
          ),
          Align(
            alignment: const Alignment(0.3, -0.35),
            child: FractionallySizedBox(
              widthFactor: 0.14,
              heightFactor: 0.07,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_2_6.png",
                  ),
                  offset: 150),
            ),
          ),
          Align(
            alignment: const Alignment(0.8, -0.3),
            child: FractionallySizedBox(
              widthFactor: 0.15,
              heightFactor: 0.10,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_2_5.png",
                  ),
                  offset: 50),
            ),
          ),
          Align(
            alignment: const Alignment(0.7, 0.1),
            child: FractionallySizedBox(
              widthFactor: 0.25,
              heightFactor: 0.15,
              child: SlidingContainer(
                  child: Image.asset(
                    "assets/images/tutorial/s_2_7.png",
                  ),
                  offset: 200),
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
            alignment: Alignment.bottomCenter,
            child: SlidingContainer(
              offset: 250,
              child: Container(
                padding: const EdgeInsets.only(bottom: 64),
                width: 350,
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
