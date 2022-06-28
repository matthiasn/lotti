import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/sync/tutorial_utils.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/theme/theme.dart';
import 'package:lotti/widgets/misc/buttons.dart';
import 'package:lottie/lottie.dart';

class SyncAssistantSuccessSlide extends StatelessWidget {
  const SyncAssistantSuccessSlide(
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
          Align(
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
              padding: const EdgeInsets.only(bottom: 80),
              child: Button(
                localizations.settingsSyncSuccessCloseButton,
                onPressed: () {
                  persistNamedRoute('/settings/advanced');
                  getIt<AppRouter>().pop();
                },
                primaryColor: getIt<ThemeService>().colors.outboxSuccessColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
