import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../widgets/sync/matrix_settings.dart';
import '../sliver_box_adapter_page.dart';

class MatrixSettingsPage extends StatelessWidget {
  const MatrixSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      body: SliverBoxAdapterPage(
        title: localizations.settingsMatrixTitle,
        showBackButton: true,
        child: const Padding(
          padding: EdgeInsets.symmetric(
            vertical: 64,
            horizontal: 32,
          ),
          child: MatrixSettingsWidget(),
        ),
      ),
    );
  }
}
