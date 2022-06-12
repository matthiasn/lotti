import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/theme.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

class EmptyDashboards extends StatelessWidget {
  const EmptyDashboards({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: min(MediaQuery.of(context).size.width * 0.8 - 64, 640),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoSizeText(
                  localizations.dashboardsEmptyHint,
                  style: titleStyle,
                  maxLines: 7,
                ),
                const SizedBox(height: 32),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      final uri = Uri.parse(
                          'https://github.com/matthiasn/lotti/blob/main/docs/MANUAL.md');
                      launchUrl(uri);
                    },
                    child: AutoSizeText(
                      localizations.manualLinkText,
                      style: titleStyle.copyWith(
                        decoration: TextDecoration.underline,
                        color: AppColors.tagColor,
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
            padding: const EdgeInsets.only(right: 32.0),
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
    );
  }
}
