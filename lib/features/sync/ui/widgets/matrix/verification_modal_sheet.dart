import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

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
