import 'package:flutter/material.dart';
import 'package:flutter_fadein/flutter_fadein.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:lotti/pages/settings/settings_icon.dart';
import 'package:lotti/widgets/app_bar/app_bar_version.dart';

import 'dart:math';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:lotti/pages/ask_me_card.dart';

class AskMePage extends StatelessWidget {
  const AskMePage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colorConfig().bodyBgColor,
      appBar: VersionAppBar(title: localizations.navTabTitleAskMe),
      body: Container(
        margin: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 8,
        ),
        child: ListView(
          children: [
            AskMeCard(
              icon: const SettingsIcon(MdiIcons.pillMultiple),
              title: 'Did you take your pill today?',
              onTap: () {
                
              },
            )
          ],
        ),
      ),
    );
  }
  }
