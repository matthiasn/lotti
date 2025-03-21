import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

class ShowcaseWithWidget extends StatelessWidget {
  const ShowcaseWithWidget({
    required this.showcaseKey,
    required this.description,
    required this.child,
    this.startNav = false,
    this.endNav = false,
    super.key,
  });

  final GlobalKey showcaseKey;
  final Widget child;
  final bool startNav;
  final bool endNav;
  final Widget description;

  @override
  Widget build(BuildContext context) {
    return Showcase.withWidget(
      tooltipPosition: TooltipPosition.bottom,
      disposeOnTap: false,
      onTargetClick: () {},
      disableDefaultTargetGestures: true,
      disableMovingAnimation: true,
      overlayOpacity: 0.7,
      tooltipActionConfig:
          const TooltipActionConfig(gapBetweenContentAndAction: 50),
      key: showcaseKey,
      width: 400,
      height: 80,
      container: SizedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              margin: const EdgeInsets.only(left: 5),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(0, 0, 0, 0.6),
                borderRadius: BorderRadius.circular(5),
              ),
              child: description,
            ),
            if (startNav)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      ShowCaseWidget.of(context).dismiss();
                    },
                    child: const Text(
                      'close',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  OutlinedButton(
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
                  OutlinedButton(
                    onPressed: () {
                      ShowCaseWidget.of(context).previous();
                    },
                    child: const Text(
                      'Previous',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      ShowCaseWidget.of(context).dismiss();
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
                  OutlinedButton(
                    onPressed: () {
                      ShowCaseWidget.of(context).previous();
                    },
                    child: const Text(
                      'Previous',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  OutlinedButton(
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
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: child,
      ),
    );
  }
}
