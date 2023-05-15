import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      child: Opacity(
        opacity: 0.3,
        child: Lottie.asset(
          // from https://lottiefiles.com/27-loading
          'assets/lottiefiles/27-loading.json',
          width: 80,
          height: 80,
          fit: BoxFit.contain,
          frameRate: FrameRate(60),
          reverse: true,
        ),
      ),
    );
  }
}
