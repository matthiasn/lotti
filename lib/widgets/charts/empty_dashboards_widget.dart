// ignore_for_file: unused-code

import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/dashboards_app_bar.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

class EmptyDashboards extends StatelessWidget {
  const EmptyDashboards({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: styleConfig().negspace,
      appBar: const DashboardsAppBar(),
      body: Stack(
        children: [
          Align(
            child: SizedBox(
              width: min(MediaQuery.of(context).size.width * 0.8 - 64, 640),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutoSizeText(
                    localizations.dashboardsEmptyHint,
                    style: titleStyle(),
                    maxLines: 7,
                  ),
                  const SizedBox(height: 32),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        final uri = Uri.parse(
                          'https://github.com/matthiasn/lotti/blob/main/docs/MANUAL.md',
                        );
                        launchUrl(uri);
                      },
                      child: AutoSizeText(
                        localizations.manualLinkText,
                        style: titleStyle().copyWith(
                          decoration: TextDecoration.underline,
                          color: styleConfig().tagColor,
                        ),
                        maxLines: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 32),
              child: Opacity(
                opacity: 0.5,
                child: Lottie.asset(
                  // from https://lottiefiles.com/7834-seta-arrow
                  'assets/lottiefiles/7834-seta-arrow.json',
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                  frameRate: FrameRate(12),
                  reverse: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingDashboards extends StatelessWidget {
  const LoadingDashboards({
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
