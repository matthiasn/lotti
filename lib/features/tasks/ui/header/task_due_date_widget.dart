import 'package:flutter/cupertino.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Opens a single-page modal with a Cupertino date wheel to set, change, or
/// clear a task's due date. Defaults the wheel to [initialDate] (or now when
/// null). Done invokes [onDueDateChanged] with the picked date only if the
/// user scrolled the wheel or no date existed yet; Clear invokes it with null;
/// Cancel closes without changes.
Future<void> showDueDatePicker({
  required BuildContext context,
  required DateTime? initialDate,
  required Future<void> Function(DateTime? newDate) onDueDateChanged,
}) async {
  final effectiveInitialDate = initialDate ?? DateTime.now();
  var selectedDate = effectiveInitialDate;
  var userHasChangedDate = false;

  await ModalUtils.showSinglePageModal<void>(
    context: context,
    builder: (modalContext) {
      return _DueDatePicker(
        initialDate: effectiveInitialDate,
        onDateChanged: (date) {
          selectedDate = date;
          userHasChangedDate = true;
        },
      );
    },
    title: context.messages.taskDueDateLabel,
    stickyActionBarBuilder: (modalContext) => _DueDateStickyActionBar(
      onCancel: () => Navigator.of(modalContext).pop(),
      onClear: () async {
        Navigator.of(modalContext).pop();
        await onDueDateChanged(null);
      },
      onDone: () async {
        Navigator.of(modalContext).pop();
        // Update if:
        // 1. User interacted with the picker (scrolled/selected), OR
        // 2. There was no initial date (user is explicitly setting a date for
        //    the first time by clicking Done).
        if (userHasChangedDate || initialDate == null) {
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
    // Note: We no longer call onDateChanged here to avoid triggering
    // userHasChangedDate when the widget initializes
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
    return DesignSystemModalActionBar(
      glass: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      secondary: [
        DesignSystemButton(
          label: context.messages.cancelButton,
          variant: DesignSystemButtonVariant.secondary,
          size: DesignSystemButtonSize.large,
          onPressed: onCancel,
        ),
        DesignSystemButton(
          label: context.messages.clearButton,
          variant: DesignSystemButtonVariant.secondary,
          size: DesignSystemButtonSize.large,
          onPressed: onClear,
        ),
      ],
      primary: DesignSystemButton(
        label: context.messages.doneButton,
        size: DesignSystemButtonSize.large,
        fullWidth: true,
        onPressed: onDone,
      ),
    );
  }
}
