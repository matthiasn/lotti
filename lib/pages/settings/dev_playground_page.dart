import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/pages/settings/settings_card.dart';
import 'package:lotti/pages/settings/settings_icon.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DevPlaygroundPage extends StatelessWidget {
  const DevPlaygroundPage({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.bodyBgColor,
      appBar: TitleAppBar(title: localizations.settingsPlaygroundTitle),
      body: Container(
        margin: const EdgeInsets.symmetric(
          vertical: 8.0,
          horizontal: 8.0,
        ),
        child: ListView(
          children: [
            SettingsCard(
              icon: const SettingsIcon(MdiIcons.slide),
              title: localizations.settingsPlaygroundTutorialTitle,
              onTap: () {
                pushNamedRoute('/settings/tutorial');
              },
            ),
          ],
        ),
      ),
    );
  }
}
