import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

class ShowcaseWithWidget extends StatelessWidget {
  const ShowcaseWithWidget({
    required this.showcaseKey,
    required this.icon,
    this.startNav = false,
    this.endNav = false,
    super.key,
  });

  final GlobalKey showcaseKey;
  final Widget icon;
  final bool startNav;
  final bool endNav;

  @override
  Widget build(BuildContext context) {
    return Showcase.withWidget(
      tooltipPosition: TooltipPosition.bottom,
      disposeOnTap: false,
      onTargetClick: () {},
      disableDefaultTargetGestures: true,
      disableMovingAnimation: true,
      overlayOpacity: 0.7,
      key: showcaseKey,
      width: 300,
      height: 100,
      container: SizedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (startNav)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      ShowCaseWidget.of(context).completed(showcaseKey);
                    },
                    child: const Text(
                      'close',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ShowCaseWidget.of(context).next();
                    },
                    child: const Text(
                      'next',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              )
            else if (endNav)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      ShowCaseWidget.of(context).previous();
                    },
                    child: const Text(
                      'Previous',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ShowCaseWidget.of(context).completed(showcaseKey);
                    },
                    child: const Text(
                      'close',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      ShowCaseWidget.of(context).previous();
                    },
                    child: const Text(
                      'Previous',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ShowCaseWidget.of(context).next();
                    },
                    child: const Text(
                      'Next',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      child: icon,
    );
  }
}
