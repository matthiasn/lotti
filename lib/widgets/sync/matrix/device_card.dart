import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/widgets/sync/matrix/verification_modal.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:matrix/matrix.dart';

class DeviceCard extends StatefulWidget {
  const DeviceCard(
    this.deviceKeys, {
    super.key,
  });

  final DeviceKeys deviceKeys;

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  final _matrixService = getIt<MatrixService>();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Card(
      child: ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                widget.deviceKeys.deviceDisplayName ??
                    widget.deviceKeys.deviceId ??
                    '',
                softWrap: true,
              ),
            ),
            IconButton(
              padding: const EdgeInsets.all(10),
              icon: Semantics(
                label: 'Delete device',
                child: Icon(MdiIcons.trashCanOutline),
              ),
              onPressed: () => _matrixService.deleteDevice(widget.deviceKeys),
            ),
          ],
        ),
        subtitle: Column(
          children: [
            Opacity(
              opacity: 0.5,
              child: Text(
                widget.deviceKeys.userId,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () async {
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) {
                    return VerificationModal(widget.deviceKeys);
                  },
                );
              },
              child: Text(
                localizations.settingsMatrixVerifyLabel,
                semanticsLabel: localizations.settingsMatrixVerifyLabel,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
