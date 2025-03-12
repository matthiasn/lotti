import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

class NavbarShowcase extends StatelessWidget {
  const NavbarShowcase({
    required this.showcaseKey,
    required this.description,
    required this.icon,
    this.startNav = false,
    this.endNav = false,
    super.key,
  });

  final GlobalKey showcaseKey;
  final Widget description;
  final Widget icon;
  final bool startNav;
  final bool endNav;

  @override
  Widget build(BuildContext context) {
    return Showcase.withWidget(
      tooltipPosition: TooltipPosition.bottom,
      overlayOpacity: 0.7,
      key: showcaseKey,
      width: 300,
      height: 100,
      container: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            description,
            if (startNav)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      ShowCaseWidget.of(context).completed(showcaseKey);
                    },
                    child: const Text('close'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ShowCaseWidget.of(context).next();
                    },
                    child: const Text('Next'),
                  ),
                ],
              )
            else if (endNav)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      ShowCaseWidget.of(context).previous();
                    },
                    child: const Text('Previous'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ShowCaseWidget.of(context).completed(showcaseKey);
                    },
                    child: const Text('close'),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      ShowCaseWidget.of(context).previous();
                    },
                    child: const Text('Previous'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ShowCaseWidget.of(context).next();
                    },
                    child: const Text('Next'),
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
