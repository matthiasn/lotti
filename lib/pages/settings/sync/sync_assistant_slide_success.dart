import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/pages/settings/sync/tutorial_utils.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/misc/buttons.dart';
import 'package:lottie/lottie.dart';

class SyncAssistantSuccessSlide extends StatelessWidget {
  final int page;
  final int pageCount;
  final ValueNotifier<double> notifier;

  const SyncAssistantSuccessSlide(
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
              offset: 300,
              child: Container(
                padding: const EdgeInsets.only(bottom: 180),
                width: textBodyWidth(context),
                child: Lottie.asset('assets/lottiefiles/angel.zip'),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: Button(
                localizations.settingsSyncSuccessCloseButton,
                onPressed: () {
                  persistNamedRoute('/settings/advanced');
                  context.router.pop();
                },
                primaryColor: AppColors.outboxSuccessColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
