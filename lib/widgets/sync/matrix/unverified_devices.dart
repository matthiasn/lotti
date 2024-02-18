import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/widgets/sync/imap_config_status.dart';
import 'package:lotti/widgets/sync/matrix/device_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:matrix/matrix.dart';

class UnverifiedDevices extends StatefulWidget {
  const UnverifiedDevices({super.key});

  @override
  State<UnverifiedDevices> createState() => _UnverifiedDevicesState();
}

class _UnverifiedDevicesState extends State<UnverifiedDevices> {
  final _matrixService = getIt<MatrixService>();
  List<DeviceKeys> _unverifiedDevices = [];

  @override
  void initState() {
    super.initState();
    setState(() {
      _unverifiedDevices = _matrixService.getUnverified();
    });
  }

  void refreshList() {
    setState(() {
      _unverifiedDevices = _matrixService.getUnverified();
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    if (_unverifiedDevices.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(localizations.settingsMatrixNoUnverifiedLabel),
          const StatusIndicator(
            Colors.greenAccent,
            semanticsLabel: 'No unverified devices',
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              localizations.settingsMatrixListUnverifiedLabel,
              semanticsLabel: localizations.settingsMatrixListUnverifiedLabel,
            ),
            IconButton(
              key: const Key('matrix_list_unverified'),
              onPressed: refreshList,
              icon: Icon(MdiIcons.refresh),
            ),
          ],
        ),
        ..._unverifiedDevices.map(
          (deviceKeys) => DeviceCard(
            deviceKeys,
            refreshListCallback: refreshList,
          ),
        ),
      ],
    );
  }
}
