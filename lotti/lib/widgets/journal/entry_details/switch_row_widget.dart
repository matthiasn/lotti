import 'package:flutter/cupertino.dart';
import 'package:lotti/theme.dart';

class SwitchRowWidget extends StatelessWidget {
  const SwitchRowWidget({
    Key? key,
    required this.label,
    required this.onChanged,
    required this.value,
    required this.activeColor,
  }) : super(key: key);

  final String label;
  final void Function(bool)? onChanged;
  final bool value;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(label, style: textStyle),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: activeColor,
          ),
        ],
      ),
    );
  }
}
