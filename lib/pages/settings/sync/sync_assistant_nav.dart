import 'package:flutter/material.dart';
import 'package:lotti/theme.dart';

class SyncNavPrevious extends StatelessWidget {
  const SyncNavPrevious({
    super.key,
    required this.pageCtrl,
  });

  final PageController pageCtrl;

  @override
  Widget build(BuildContext context) {
    return AlignedNavIcon(
      alignment: Alignment.centerLeft,
      iconData: Icons.arrow_back_ios_rounded,
      onPressed: () {
        pageCtrl.previousPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.linear,
        );
      },
    );
  }
}

class SyncNavNext extends StatelessWidget {
  const SyncNavNext({
    super.key,
    required this.pageCtrl,
  });

  final PageController pageCtrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: AlignedNavIcon(
        alignment: Alignment.centerRight,
        iconData: Icons.arrow_forward_ios_rounded,
        onPressed: () {
          pageCtrl.nextPage(
            duration: const Duration(milliseconds: 600),
            curve: Curves.linear,
          );
        },
      ),
    );
  }
}

class AlignedNavIcon extends StatelessWidget {
  const AlignedNavIcon({
    super.key,
    required this.onPressed,
    required this.iconData,
    required this.alignment,
  });

  final void Function() onPressed;
  final IconData iconData;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IconButton(
        padding: const EdgeInsets.all(12),
        icon: Icon(
          iconData,
          color: AppColors.entryTextColor,
          size: 32,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
