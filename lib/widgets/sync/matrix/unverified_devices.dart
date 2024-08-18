import 'package:flutter/material.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
      _unverifiedDevices = _matrixService.getUnverifiedDevices();
    });
  }

  void refreshList() {
    setState(() {
      _unverifiedDevices = _matrixService.getUnverifiedDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_unverifiedDevices.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(context.messages.settingsMatrixNoUnverifiedLabel),
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
              context.messages.settingsMatrixListUnverifiedLabel,
              semanticsLabel:
                  context.messages.settingsMatrixListUnverifiedLabel,
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
