import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/pages/settings/sync/tutorial_utils.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/platform.dart';

class SyncAssistantIntroSlide1 extends StatelessWidget {
  final int page;
  final int pageCount;
  final ValueNotifier<double> notifier;

  const SyncAssistantIntroSlide1(
    this.page,
    this.pageCount,
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
          SyncAssistantHeaderWidget(
            index: page,
            pageCount: pageCount,
          ),
          Align(
            alignment: Alignment.center,
            child: SlidingContainer(
              offset: 250,
              child: SizedBox(
                width: textBodyWidth(context),
                child: Text(
                  localizations.syncAssistantPage1,
                  textAlign: TextAlign.justify,
                  style: titleStyle.copyWith(fontSize: isMobile ? 32 : 28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
