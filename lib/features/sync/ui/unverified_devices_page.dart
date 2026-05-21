import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/device_card.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/status_indicator.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_flow_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class UnverifiedDevices extends ConsumerWidget {
  const UnverifiedDevices({super.key});

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final unverifiedDevices =
        ref.watch(matrixUnverifiedControllerProvider).value ?? [];

    void refreshList() {
      ref.invalidate(matrixUnverifiedControllerProvider);
    }

    if (unverifiedDevices.isEmpty) {
      return SyncFlowSection(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.messages.settingsMatrixNoUnverifiedLabel),
            StatusIndicator(
              Colors.greenAccent,
              semanticsLabel: context.messages.settingsMatrixNoUnverifiedLabel,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SyncFlowSection(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.messages.settingsMatrixListUnverifiedLabel,
                semanticsLabel:
                    context.messages.settingsMatrixListUnverifiedLabel,
              ),
              IconButton(
                key: const Key('matrix_list_unverified'),
                onPressed: refreshList,
                icon: const Icon(MdiIcons.refresh),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...unverifiedDevices.map(
          (deviceKeys) => DeviceCard(
            deviceKeys,
            refreshListCallback: refreshList,
          ),
        ),
      ],
    );
  }
}
