import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/pages/settings/sync/tutorial_utils.dart';

class SyncAssistantIntroSlide1 extends StatelessWidget {
  const SyncAssistantIntroSlide1(
    this.page,
    this.pageCount,
    this.notifier, {
    super.key,
  });

  final int page;
  final int pageCount;
  final ValueNotifier<double> notifier;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

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
          AlignedText(localizations.syncAssistantPage1),
        ],
      ),
    );
  }
}
