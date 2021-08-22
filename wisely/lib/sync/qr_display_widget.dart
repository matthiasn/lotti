import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrDisplayWidget extends StatefulWidget {
  const QrDisplayWidget({Key? key}) : super(key: key);

  @override
  State<QrDisplayWidget> createState() => _QrDisplayWidgetState();
}

class _QrDisplayWidgetState extends State<QrDisplayWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(
          Radius.circular(8.0),
        ),
      ),
      child: QrImage(
        data:
            '1234567890123456789012345678901234567890123456789012345678901234567890',
        version: QrVersions.auto,
        size: 200.0,
      ),
    );
  }
}
