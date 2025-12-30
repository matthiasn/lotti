import 'package:flutter/cupertino.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

Future<void> showDueDatePicker({
  required BuildContext context,
  required DateTime? initialDate,
  required Future<void> Function(DateTime? newDate) onDueDateChanged,
}) async {
  var selectedDate = initialDate ?? DateTime.now();

  await ModalUtils.showSinglePageModal<void>(
    context: context,
    builder: (modalContext) {
      return _DueDatePicker(
        initialDate: selectedDate,
        onDateChanged: (date) {
          selectedDate = date;
        },
      );
    },
    title: context.messages.taskDueDateLabel,
    stickyActionBar: _DueDateStickyActionBar(
      onCancel: () => Navigator.of(context).pop(),
      onClear: () async {
        Navigator.of(context).pop();
        await onDueDateChanged(null);
      },
      onDone: () async {
        Navigator.of(context).pop();
        if (selectedDate != initialDate) {
          await onDueDateChanged(selectedDate);
        }
      },
    ),
    padding: const EdgeInsets.only(bottom: 40),
  );
}

/// The date picker widget for selecting due date
class _DueDatePicker extends StatefulWidget {
  const _DueDatePicker({
    required this.initialDate,
    required this.onDateChanged,
  });

  final DateTime initialDate;
  final void Function(DateTime) onDateChanged;

  @override
  State<_DueDatePicker> createState() => _DueDatePickerState();
}

class _DueDatePickerState extends State<_DueDatePicker> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    // Pass initial value to callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDateChanged(_selectedDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: CupertinoThemeData(
        textTheme: CupertinoTextThemeData(
          dateTimePickerTextStyle:
              context.textTheme.titleLarge?.withTabularFigures,
        ),
      ),
      child: SizedBox(
        height: 265,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: _selectedDate,
          onDateTimeChanged: (date) {
            _selectedDate = date;
            widget.onDateChanged(date);
          },
        ),
      ),
    );
  }
}

/// Sticky action bar for the due date selection modal
class _DueDateStickyActionBar extends StatelessWidget {
  const _DueDateStickyActionBar({
    required this.onCancel,
    required this.onClear,
    required this.onDone,
  });

  final VoidCallback onCancel;
  final VoidCallback onClear;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: LottiSecondaryButton(
              label: context.messages.cancelButton,
              onPressed: onCancel,
              fullWidth: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LottiSecondaryButton(
              label: context.messages.clearButton,
              onPressed: onClear,
              fullWidth: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LottiPrimaryButton(
              onPressed: onDone,
              label: context.messages.doneButton,
            ),
          ),
        ],
      ),
    );
  }
}
