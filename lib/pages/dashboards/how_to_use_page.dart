import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:url_launcher/url_launcher.dart';

class HowToUsePage extends StatefulWidget {
  const HowToUsePage({
    super.key,
  });

  @override
  State<HowToUsePage> createState() => _HowToUsePageState();
}

class _HowToUsePageState extends State<HowToUsePage> {
  bool isHovering = false;

  void onPressed() {
    launchUrl(
      Uri.parse(
        'https://github.com/matthiasn/lotti/blob/main/docs/MANUAL.md',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: styleConfig().negspace,
      body: Stack(
        children: [
          Align(
            child: OutlinedButton(
              onHover: (hovering) => setState(() {
                isHovering = hovering;
              }),
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isHovering
                    ? styleConfig().primaryColor
                    : styleConfig().negspace,
                side: const BorderSide(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 20 : 30,
                  horizontal: isMobile ? 30 : 45,
                ),
              ),
              child: AutoSizeText(
                localizations.dashboardsHowToHint,
                style: TextStyle(
                  color: styleConfig().primaryTextColor,
                  fontSize: 25,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
