import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/widgets/buttons/rounded_filled_button.dart';
import 'package:lotti/widgets/sync/matrix/verification_modal.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:matrix/matrix.dart';

class DeviceCard extends StatefulWidget {
  const DeviceCard(
    this.deviceKeys, {
    required this.refreshListCallback,
    super.key,
  });

  final DeviceKeys deviceKeys;
  final VoidCallback refreshListCallback;

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
            RoundedFilledButton(
              onPressed: () async {
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) {
                    return VerificationModal(widget.deviceKeys);
                  },
                );
                widget.refreshListCallback();
              },
              labelText: localizations.settingsMatrixVerifyLabel,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
