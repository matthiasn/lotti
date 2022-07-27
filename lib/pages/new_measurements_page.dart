import 'package:flutter/material.dart';
import 'package:flutter_fadein/flutter_fadein.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

import 'dart:math';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

// class NewMeasurementsPage extends StatelessWidget {
//   const NewMeasurementsPage(
//     this.title, {
//     super.key,
//     this.body,
//   });

//   final String title;
//   final Widget? body;

//   @override
//   Widget build(BuildContext context) {
//     return FadeIn(
//       duration: const Duration(seconds: 2),
//       child: Scaffold(
//         backgroundColor: colorConfig().bodyBgColor,
//         appBar: TitleAppBar(
//           title: title,
//         ),
//         body: body,
//       ),
//     );
//   }
// }

class NewMeasurementsPage extends StatelessWidget {
  const NewMeasurementsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Stack(
      children: [
        Align(
          child: SizedBox(
            width: min(MediaQuery.of(context).size.width * 0.8 - 64, 640),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      'HELLO WORLD',
                      style: titleStyle().copyWith(
                        decoration: TextDecoration.underline,
                        color: colorConfig().tagColor,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}