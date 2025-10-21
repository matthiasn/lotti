import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/animated_settings_cards.dart';
import 'package:lotti/features/sync/ui/matrix_settings_modal.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class MatrixSyncSettingsPage extends StatelessWidget {
  const MatrixSyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SyncFeatureGate(
      child: SliverBoxAdapterPage(
        title: context.messages.settingsMatrixTitle,
        showBackButton: true,
        child: Column(
          children: [
            const MatrixSettingsCard(),
            AnimatedModernSettingsCardWithIcon(
              title: context.messages.settingsMatrixMaintenanceTitle,
              subtitle: context.messages.settingsMatrixMaintenanceSubtitle,
              icon: Icons.build_outlined,
              onTap: () =>
                  context.beamToNamed('/settings/sync/matrix/maintenance'),
            ),
          ],
        ),
      ),
    );
  }
}
