import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/date_time/datetime_bottom_sheet.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class DateTimeField extends StatefulWidget {
  const DateTimeField({
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
  final void Function()? clear;
  final CupertinoDatePickerMode mode;

  @override
  State<DateTimeField> createState() => _DateTimeFieldState();
}

class _DateTimeFieldState extends State<DateTimeField> {
  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.titleMedium;

    final df = widget.mode == CupertinoDatePickerMode.date
        ? dfYmd
        : widget.mode == CupertinoDatePickerMode.time
        ? hhMmFormat
        : dfShorter;

    return TextField(
      decoration:
          createDialogInputDecoration(
            labelText: widget.labelText,
            style: style,
            themeData: Theme.of(context),
          ).copyWith(
            suffixIcon: widget.clear != null
                ? IconButton(
                    onPressed: widget.clear,
                    icon: const Icon(LottiIcons.close),
                  )
                : null,
          ),
      style: style,
      readOnly: true,
      controller: TextEditingController(
        text: widget.dateTime != null ? df.format(widget.dateTime!) : '',
      ),
      onTap: () => showDateTimePickerModal(
        context,
        dateTime: widget.dateTime,
        labelText: widget.labelText,
        setDateTime: widget.setDateTime,
        mode: widget.mode,
      ),
    );
  }
}

/// Opens the shared date/time picker modal (Cupertino wheel plus the
/// Cancel / Now / Done sticky bar) and applies the picked value through
/// [setDateTime]. Shared by [DateTimeField] and the settings editors'
/// `SettingsDateTimeField` so both field styles drive the exact same
/// picking flow.
///
/// Thin wrapper over [pickDateTimeModal]: the value is applied *after* the
/// sheet has closed, so no caller state is mutated while a route is being
/// torn down. Dismissing the sheet — Cancel, the close button or the
/// barrier — leaves [setDateTime] uncalled.
Future<void> showDateTimePickerModal(
  BuildContext context, {
  required DateTime? dateTime,
  required String labelText,
  required void Function(DateTime) setDateTime,
  CupertinoDatePickerMode mode = CupertinoDatePickerMode.dateAndTime,
}) async {
  final picked = await pickDateTimeModal(
    context,
    dateTime: dateTime,
    labelText: labelText,
    mode: mode,
  );
  if (picked != null) {
    setDateTime(picked);
  }
}

/// Shows the date/time picker sheet and completes with the picked value, or
/// `null` when the user dismissed it without choosing.
///
/// The action bar is built from the **modal's own** context
/// (`stickyActionBarBuilder`, not a pre-built `stickyActionBar`) and pops
/// that context. This is load-bearing, not style: on mobile
/// [ModalUtils.showSinglePageModal] pushes onto the *root* navigator, while
/// the calling field sits inside a tab's nested `Beamer` navigator. A
/// `Navigator.of(callerContext).pop()` would therefore pop the *page behind
/// the sheet* — tearing down the settings editor and every unsaved edit in
/// it — instead of the sheet. Popping the builder context always resolves to
/// the navigator that actually hosts the sheet, on both layouts.
Future<DateTime?> pickDateTimeModal(
  BuildContext context, {
  required DateTime? dateTime,
  required String labelText,
  CupertinoDatePickerMode mode = CupertinoDatePickerMode.dateAndTime,
}) {
  var selectedDateTime = dateTime ?? clock.now();

  return ModalUtils.showSinglePageModal<DateTime>(
    context: context,
    builder: (modalContext) {
      return DateTimeBottomSheet(
        selectedDateTime,
        mode: mode,
        onDateTimeSelected: (dateTime) {
          if (dateTime != null) {
            selectedDateTime = dateTime;
          }
        },
      );
    },
    title: labelText,
    stickyActionBarBuilder: (modalContext) => DateTimeStickyActionBar(
      onCancel: () => Navigator.of(modalContext).pop(),
      onNow: () => Navigator.of(modalContext).pop(clock.now()),
      onDone: () => Navigator.of(modalContext).pop(selectedDateTime),
    ),
    navBarHeight: 65,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
  );
}
