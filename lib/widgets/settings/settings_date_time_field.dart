import 'package:flutter/cupertino.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

/// Date/time picker for settings editors, rendered as a
/// [SettingsPickerField] (label above, design-system field silhouette).
/// Opens the same Cupertino wheel modal as the journal's `DateTimeField`
/// via [showDateTimePickerModal].
class SettingsDateTimeField extends StatelessWidget {
  const SettingsDateTimeField({
    required this.dateTime,
    required this.labelText,
    required this.setDateTime,
    this.clear,
    this.mode = CupertinoDatePickerMode.dateAndTime,
    super.key,
  });

  final DateTime? dateTime;
  final String labelText;
  final void Function(DateTime) setDateTime;

  /// When provided, an inline clear affordance resets the value.
  final void Function()? clear;

  final CupertinoDatePickerMode mode;

  @override
  Widget build(BuildContext context) {
    final df = mode == CupertinoDatePickerMode.date
        ? dfYmd
        : mode == CupertinoDatePickerMode.time
        ? hhMmFormat
        : dfShorter;

    return SettingsPickerField(
      label: labelText,
      valueText: dateTime != null ? df.format(dateTime!) : null,
      onClear: clear,
      onTap: () => showDateTimePickerModal(
        context,
        dateTime: dateTime,
        labelText: labelText,
        setDateTime: setDateTime,
        mode: mode,
      ),
    );
  }
}
