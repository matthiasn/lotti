import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/pages/tutorial/sliding_intro/tutorial_utils.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/sync/qr_widget.dart';
import 'package:lottie/lottie.dart';

class SyncAssistantSlide3 extends StatelessWidget {
  final int page;
  final ValueNotifier<double> notifier;

  const SyncAssistantSlide3(
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
          Align(
            alignment: Alignment.topCenter,
            child: SlidingContainer(
              offset: 250,
              child: Padding(
                padding: const EdgeInsets.only(top: 32.0),
                child: Text(
                  localizations.syncAssistantHeadline3,
                  textAlign: TextAlign.center,
                  style: titleStyle.copyWith(fontSize: 40),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: SlidingContainer(
              offset: 250,
              child: Container(
                padding: const EdgeInsets.only(bottom: 80),
                width: textBodyWidth(context),
                child: Lottie.asset(
                  'assets/lottiefiles/6650-sparkles-burst.json',
                  width: 160,
                  height: 160,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.4),
            child: SlidingContainer(
              offset: 100,
              child: const EncryptionQrWidget(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SlidingContainer(
              offset: 250,
              child: Container(
                padding: const EdgeInsets.only(bottom: 90),
                width: textBodyWidth(context),
                child: Text(
                  localizations.syncAssistantPage3,
                  textAlign: TextAlign.justify,
                  style: titleStyle.copyWith(fontSize: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
