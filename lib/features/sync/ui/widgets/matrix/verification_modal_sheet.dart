import 'package:flutter/material.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

Future<void> showVerificationModalSheet({
  required BuildContext context,
  required String title,
  required Widget child,
}) async {
  await ModalUtils.showSinglePageModal<void>(
    context: context,
    title: title,
    builder: (_) => child,
  );
}
