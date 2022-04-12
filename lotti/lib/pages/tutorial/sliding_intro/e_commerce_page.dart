import 'package:flutter/material.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';

class ECommercePage extends StatelessWidget {
  final int page;
  final ValueNotifier<double> notifier;

  const ECommercePage(
    this.page,
    this.notifier, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                    "assets/images/tutorial/s_2_4.png",
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
            alignment: const Alignment(0, 0.78),
            child: SlidingContainer(
              offset: 250,
              child: const Text(
                "e-Commerce",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
