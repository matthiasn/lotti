import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/pages/tutorial/sliding_intro/tutorial_utils.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/sync/imap_config.dart';
import 'package:lottie/lottie.dart';

class SyncAssistantSlide2 extends StatelessWidget {
  final int page;
  final ValueNotifier<double> notifier;

  const SyncAssistantSlide2(
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
                  localizations.syncAssistantHeadline2,
                  textAlign: TextAlign.center,
                  style: titleStyle.copyWith(fontSize: 40),
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.2),
            child: SlidingContainer(
              offset: 100,
              child: const EmailConfigForm(),
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: SlidingContainer(
              offset: 250,
              child: Container(
                padding: const EdgeInsets.only(top: 100),
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
            alignment: Alignment.bottomCenter,
            child: SlidingContainer(
              offset: 250,
              child: Container(
                padding: const EdgeInsets.only(bottom: 90),
                width: textBodyWidth(context),
                child: Text(
                  localizations.syncAssistantPage2,
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
