import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/widgets/create/suggest_measurement.dart';
import 'package:lotti/widgets/modal/full_height_wolt_dialog_type.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// Presents the complete measurement capture as one adaptive Wolt route.
///
/// The editor and observed-at picker are sibling pages in the same sheet. All
/// draft-bearing objects live for the route lifetime because Wolt disposes an
/// inactive page after pagination; returning from the picker therefore keeps
/// the entered value and comment without reopening the keyboard.
abstract final class MeasurementCaptureModal {
  static Future<void> show({
    required BuildContext context,
    required MeasurableDataType measurableDataType,
  }) async {
    final draft = _MeasurementCaptureDraft(
      dataType: measurableDataType,
      initialDateTime: clock.now(),
      routeClock: clock,
    );
    var attachedToRoute = false;

    Widget decorateFlow(Widget child) {
      attachedToRoute = true;
      return _MeasurementCaptureLifetime(
        draft: draft,
        child: _MeasurementCaptureBackHandler(
          draft: draft,
          child: child,
        ),
      );
    }

    try {
      await ModalUtils.showMultiPageModal<void>(
        context: context,
        pageIndexNotifier: draft.pageIndexNotifier,
        modalDecorator: decorateFlow,
        modalTypeBuilderOverride: _measurementModalTypeBuilder,
        pageListBuilder: (modalContext) {
          final spacing = modalContext.designTokens.spacing;
          return [
            ModalUtils.modalSheetPage(
              context: modalContext,
              titleWidget: _MeasurementModalTitle(
                dataType: measurableDataType,
              ),
              showCloseButton: true,
              padding: EdgeInsets.fromLTRB(
                spacing.step5,
                spacing.step3,
                spacing.step5,
                DesignSystemGlassActionFooter.reservedHeightFor(modalContext),
              ),
              stickyActionBar: _MeasurementSaveFooter(
                draft: draft,
              ),
              child: _MeasurementEditorPage(draft: draft),
            ),
            ModalUtils.modalSheetPage(
              context: modalContext,
              title: modalContext.messages.addMeasurementDateLabel,
              showCloseButton: true,
              onTapBack: draft.discardPickerChanges,
              padding: EdgeInsets.fromLTRB(
                spacing.step5,
                spacing.step5,
                spacing.step5,
                DesignSystemGlassActionFooter.reservedHeightFor(modalContext),
              ),
              stickyActionBar: DesignSystemGlassActionFooter(
                child: DesignSystemButton(
                  key: const ValueKey('measurement-date-time-done'),
                  label: modalContext.messages.doneButton,
                  leadingIcon: Icons.check_rounded,
                  size: DesignSystemButtonSize.large,
                  fullWidth: true,
                  onPressed: draft.commitPickerChanges,
                ),
              ),
              child: _MeasurementDateTimeEditor(draft: draft),
            ),
          ];
        },
      );
    } finally {
      // Wolt normally transfers ownership to [_MeasurementCaptureLifetime].
      // Dispose here only if route construction failed before the decorator
      // was attached.
      if (!attachedToRoute) draft.dispose();
    }
  }
}

WoltModalType _measurementModalTypeBuilder(BuildContext context) {
  if (ModalUtils.shouldUseRootNavigatorForBottomSheet(context)) {
    return WoltModalType.bottomSheet();
  }
  return const FullHeightWoltDialogType();
}

typedef _MeasurementSaveState = ({bool isSaving, String? error});

class _MeasurementCaptureDraft {
  _MeasurementCaptureDraft({
    required this.dataType,
    required DateTime initialDateTime,
    required this.routeClock,
  }) : measurementDateTime = ValueNotifier(initialDateTime),
       pickerDateTime = ValueNotifier(initialDateTime);

  final MeasurableDataType dataType;
  final Clock routeClock;
  final TextEditingController valueController = TextEditingController();
  final TextEditingController commentController = TextEditingController();
  final FocusNode valueFocusNode = FocusNode(
    debugLabel: 'measurement-value',
  );
  final FocusNode commentFocusNode = FocusNode(
    debugLabel: 'measurement-comment',
  );
  final FocusNode observedAtFocusNode = FocusNode(
    debugLabel: 'measurement-observed-at',
  );
  final ValueNotifier<DateTime> measurementDateTime;
  final ValueNotifier<DateTime> pickerDateTime;
  final ValueNotifier<int> pageIndexNotifier = ValueNotifier(0);
  final ValueNotifier<_MeasurementSaveState> saveState = ValueNotifier(
    (isSaving: false, error: null),
  );

  bool _autofocusValue = true;
  bool _restoreObservedAtFocus = false;
  bool _disposed = false;

  bool takeValueAutofocus() {
    final autofocus = _autofocusValue;
    _autofocusValue = false;
    return autofocus;
  }

  bool takeObservedAtFocusRestore() {
    final restore = _restoreObservedAtFocus;
    _restoreObservedAtFocus = false;
    return restore;
  }

  num? parseValue([String? raw]) {
    final normalized = (raw ?? valueController.text).trim().replaceAll(
      ',',
      '.',
    );
    if (normalized.isEmpty) return null;
    return num.tryParse(normalized);
  }

  bool get canSave =>
      parseValue() != null && !saveState.value.isSaving && !_disposed;

  DateTime now() => routeClock.now();

  void beginPickerChanges() {
    FocusManager.instance.primaryFocus?.unfocus();
    pickerDateTime.value = measurementDateTime.value;
    pageIndexNotifier.value = 1;
  }

  void commitPickerChanges() {
    measurementDateTime.value = pickerDateTime.value;
    _returnToEditor();
  }

  void discardPickerChanges() {
    pickerDateTime.value = measurementDateTime.value;
    _returnToEditor();
  }

  void _returnToEditor() {
    _restoreObservedAtFocus = true;
    pageIndexNotifier.value = 0;
  }

  Future<void> save(BuildContext modalContext, {num? value}) async {
    final resolved = value ?? parseValue();
    if (resolved == null || saveState.value.isSaving || _disposed) return;

    final errorMessage = modalContext.messages.measurementSaveError;
    saveState.value = (isSaving: true, error: null);
    final observedAt = measurementDateTime.value;
    try {
      await getIt<PersistenceLogic>().createMeasurementEntry(
        data: MeasurementData(
          dataTypeId: dataType.id,
          dateTo: observedAt,
          dateFrom: observedAt,
          value: resolved,
        ),
        comment: commentController.text,
        private: dataType.private ?? false,
      );
      if (modalContext.mounted) {
        Navigator.of(modalContext).pop('Saved');
      }
    } catch (error, stackTrace) {
      DevLogger.error(
        name: 'MeasurementCaptureModal',
        message: 'Failed to save measurement',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_disposed) {
        saveState.value = (isSaving: false, error: errorMessage);
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    valueController.dispose();
    commentController.dispose();
    valueFocusNode.dispose();
    commentFocusNode.dispose();
    observedAtFocusNode.dispose();
    measurementDateTime.dispose();
    pickerDateTime.dispose();
    pageIndexNotifier.dispose();
    saveState.dispose();
  }
}

class _MeasurementCaptureLifetime extends StatefulWidget {
  const _MeasurementCaptureLifetime({
    required this.draft,
    required this.child,
  });

  final _MeasurementCaptureDraft draft;
  final Widget child;

  @override
  State<_MeasurementCaptureLifetime> createState() =>
      _MeasurementCaptureLifetimeState();
}

class _MeasurementCaptureLifetimeState
    extends State<_MeasurementCaptureLifetime> {
  @override
  void dispose() {
    widget.draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _MeasurementCaptureBackHandler extends StatelessWidget {
  const _MeasurementCaptureBackHandler({
    required this.draft,
    required this.child,
  });

  final _MeasurementCaptureDraft draft;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: draft.pageIndexNotifier,
      child: child,
      builder: (context, pageIndex, child) {
        final popAware = PopScope<void>(
          canPop: pageIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && draft.pageIndexNotifier.value != 0) {
              draft.discardPickerChanges();
            }
          },
          child: child!,
        );
        if (pageIndex == 0) return popAware;
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape):
                draft.discardPickerChanges,
          },
          child: Focus(autofocus: true, child: popAware),
        );
      },
    );
  }
}

class _MeasurementModalTitle extends StatelessWidget {
  const _MeasurementModalTitle({required this.dataType});

  final MeasurableDataType dataType;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final hasLargeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Semantics(
      header: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dataType.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          if (dataType.description.isNotEmpty && !hasLargeText)
            Text(
              dataType.description,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
        ],
      ),
    );
  }
}

class _MeasurementEditorPage extends StatefulWidget {
  const _MeasurementEditorPage({required this.draft});

  final _MeasurementCaptureDraft draft;

  @override
  State<_MeasurementEditorPage> createState() => _MeasurementEditorPageState();
}

class _MeasurementEditorPageState extends State<_MeasurementEditorPage> {
  late final bool _autofocusValue = widget.draft.takeValueAutofocus();
  late final bool _autofocusObservedAt = widget.draft
      .takeObservedAtFocusRestore();
  late final Listenable _editorState = Listenable.merge([
    widget.draft.valueController,
    widget.draft.measurementDateTime,
    widget.draft.saveState,
  ]);

  @override
  void initState() {
    super.initState();
    if (_autofocusObservedAt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final focusNode = widget.draft.observedAtFocusNode;
          if (mounted && focusNode.canRequestFocus) {
            FocusScope.of(context).requestFocus(focusNode);
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _editorState,
      builder: (context, _) {
        final tokens = context.designTokens;
        final draft = widget.draft;
        final dataType = draft.dataType;
        final unit = dataType.unitName;
        final measurableLabel = unit.isEmpty
            ? dataType.displayName
            : '${dataType.displayName}, $unit';
        final saveState = draft.saveState.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ValueHeroField(
              controller: draft.valueController,
              focusNode: draft.valueFocusNode,
              unit: unit,
              autofocus: _autofocusValue,
              semanticsLabel: context.messages.measurementValueSemantic(
                measurableLabel,
              ),
              onSubmitted: () => unawaited(draft.save(context)),
            ),
            MeasurementSuggestions(
              measurableDataType: dataType,
              enabled: !saveState.isSaving,
              onSelect: (value) => draft.save(context, value: value),
            ),
            SizedBox(height: tokens.spacing.sectionGap),
            _LabeledField(
              label: context.messages.addMeasurementDateLabel,
              child: _ObservedAtField(
                key: const Key('measurement_observed_at'),
                dateTime: draft.measurementDateTime.value,
                focusNode: draft.observedAtFocusNode,
                autofocus: _autofocusObservedAt,
                onTap: draft.beginPickerChanges,
              ),
            ),
            SizedBox(height: tokens.spacing.step5),
            _LabeledField(
              label: context.messages.addMeasurementCommentLabel,
              child: _FieldShell(
                focusNode: draft.commentFocusNode,
                child: Semantics(
                  label: context.messages.measurementCommentSemantic,
                  child: TextField(
                    key: const Key('measurement_comment_field'),
                    controller: draft.commentController,
                    focusNode: draft.commentFocusNode,
                    minLines: 1,
                    maxLines: 3,
                    cursorColor: tokens.colors.interactive.enabled,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                    decoration: _bareInputDecoration(
                      hintText: context.messages.measurementCommentHint,
                      hintStyle: tokens.typography.styles.body.bodyMedium
                          .copyWith(color: tokens.colors.text.lowEmphasis),
                    ),
                  ),
                ),
              ),
            ),
            if (saveState.error != null) ...[
              SizedBox(height: tokens.spacing.step4),
              Semantics(
                liveRegion: true,
                child: Text(
                  saveState.error!,
                  key: const ValueKey('measurement-save-error'),
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.alert.error.defaultColor,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _MeasurementSaveFooter extends StatelessWidget {
  const _MeasurementSaveFooter({
    required this.draft,
  });

  final _MeasurementCaptureDraft draft;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([draft.valueController, draft.saveState]),
      builder: (context, _) {
        final state = draft.saveState.value;
        return DesignSystemGlassActionFooter(
          child: DesignSystemButton(
            key: const Key('measurement_save'),
            label: context.messages.addMeasurementSaveButton,
            size: DesignSystemButtonSize.large,
            leadingIcon: Icons.check_rounded,
            fullWidth: true,
            isLoading: state.isSaving,
            onPressed: draft.canSave
                ? () => unawaited(draft.save(context))
                : null,
          ),
        );
      },
    );
  }
}

class _MeasurementDateTimeEditor extends StatefulWidget {
  const _MeasurementDateTimeEditor({required this.draft});

  final _MeasurementCaptureDraft draft;

  @override
  State<_MeasurementDateTimeEditor> createState() =>
      _MeasurementDateTimeEditorState();
}

class _MeasurementDateTimeEditorState
    extends State<_MeasurementDateTimeEditor> {
  var _timeWheelSeed = 0;

  @override
  void initState() {
    super.initState();
    widget.draft.pickerDateTime.addListener(_onDateTimeChanged);
  }

  @override
  void dispose() {
    widget.draft.pickerDateTime.removeListener(_onDateTimeChanged);
    super.dispose();
  }

  void _onDateTimeChanged() => setState(() {});

  void _setNow() {
    setState(() => _timeWheelSeed += 1);
    widget.draft.pickerDateTime.value = widget.draft.now();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final selected = widget.draft.pickerDateTime.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignSystemCalendarPicker(
          selectedDate: selected,
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
          onDateChanged: (date) {
            widget.draft.pickerDateTime.value = _replaceCalendarDate(
              selected,
              date,
            );
          },
        ),
        SizedBox(height: tokens.spacing.sectionGap),
        DesignSystemPickerSection(
          key: const ValueKey('measurement-time-section'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.messages.measurementTimeLabel,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(color: tokens.colors.text.highEmphasis),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step2),
                  DesignSystemButton(
                    key: const ValueKey('measurement-observed-at-now'),
                    label: context.messages.journalDateNowButton,
                    semanticsLabel:
                        context.messages.measurementSetObservedAtNowSemantic,
                    variant: DesignSystemButtonVariant.tertiary,
                    size: DesignSystemButtonSize.medium,
                    onPressed: _setNow,
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.step2),
              DesignSystemTimeWheel(
                key: ValueKey('measurement-time-wheel-$_timeWheelSeed'),
                initialDateTime: selected,
                use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                semanticsLabel: context.messages.measurementTimeLabel,
                onDateTimeChanged: (dateTime) {
                  widget.draft.pickerDateTime.value = _replaceTime(
                    widget.draft.pickerDateTime.value,
                    dateTime,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

DateTime _replaceCalendarDate(DateTime current, DateTime date) {
  return current.isUtc
      ? DateTime.utc(
          date.year,
          date.month,
          date.day,
          current.hour,
          current.minute,
          current.second,
          current.millisecond,
          current.microsecond,
        )
      : DateTime(
          date.year,
          date.month,
          date.day,
          current.hour,
          current.minute,
          current.second,
          current.millisecond,
          current.microsecond,
        );
}

DateTime _replaceTime(DateTime current, DateTime time) {
  return current.isUtc
      ? DateTime.utc(
          current.year,
          current.month,
          current.day,
          time.hour,
          time.minute,
          current.second,
          current.millisecond,
          current.microsecond,
        )
      : DateTime(
          current.year,
          current.month,
          current.day,
          time.hour,
          time.minute,
          current.second,
          current.millisecond,
          current.microsecond,
        );
}

/// An [InputDecoration] with every border state nulled so the field draws no
/// box of its own — the surrounding [_FieldShell] owns the border and focus
/// ring. Nulling all six border slots (not just `border`) is required because
/// the app's `inputDecorationTheme` defines an outline border that would
/// otherwise bleed through `InputDecoration.collapsed` as a second box.
InputDecoration _bareInputDecoration({String? hintText, TextStyle? hintStyle}) {
  return InputDecoration(
    isDense: true,
    isCollapsed: true,
    filled: false,
    contentPadding: EdgeInsets.zero,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    hintText: hintText,
    hintStyle: hintStyle,
  );
}

/// Restricts input to a single optional leading minus, the digits, and at most
/// one decimal separator (`.` or `,`) — so malformed numbers like `1..2` can
/// never be entered and silently disable Save.
class _DecimalTextInputFormatter extends TextInputFormatter {
  const _DecimalTextInputFormatter();

  static final RegExp _pattern = RegExp(r'^-?\d*[.,]?\d*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return _pattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}

/// A field with a design-system label above the [child] box.
class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: tokens.typography.styles.subtitle.subtitle2.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        child,
      ],
    );
  }
}

/// Design-system field surface: a rounded box whose hairline ramps from a
/// faint idle border to `interactive.enabled` (teal, 2px) on focus and
/// `text.mediumEmphasis` on hover — matching `DesignSystemTextInput`.
class _FieldShell extends StatefulWidget {
  const _FieldShell({
    required this.focusNode,
    required this.child,
    this.padding,
  });

  final FocusNode focusNode;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  State<_FieldShell> createState() => _FieldShellState();
}

class _FieldShellState extends State<_FieldShell> {
  bool _focused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() =>
      setState(() => _focused = widget.focusNode.hasFocus);

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final Color borderColor;
    if (_focused) {
      borderColor = tokens.colors.interactive.enabled;
    } else if (_hovered) {
      borderColor = tokens.colors.text.mediumEmphasis;
    } else {
      borderColor = tokens.colors.decorative.level01;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          border: Border.all(color: borderColor, width: _focused ? 2 : 1),
        ),
        child: Padding(
          padding:
              widget.padding ??
              EdgeInsets.symmetric(
                horizontal: tokens.spacing.step4,
                vertical: tokens.spacing.step4,
              ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// The hero value input: a centered big-digit field with the unit rendered as
/// an adjacent inline suffix on the same baseline, so the number and unit read
/// as one measurement ("750 ml").
class _ValueHeroField extends StatelessWidget {
  const _ValueHeroField({
    required this.controller,
    required this.focusNode,
    required this.unit,
    required this.autofocus,
    required this.semanticsLabel,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String unit;
  final bool autofocus;
  final String semanticsLabel;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final valueStyle = tokens.typography.styles.heading.heading2.copyWith(
      color: tokens.colors.text.highEmphasis,
    );

    return _FieldShell(
      focusNode: focusNode,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: IntrinsicWidth(
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: tokens.spacing.step8),
                child: Semantics(
                  label: semanticsLabel,
                  child: TextField(
                    key: const Key('measurement_value_field'),
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: autofocus,
                    textAlign: TextAlign.center,
                    style: valueStyle,
                    cursorColor: tokens.colors.interactive.enabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onSubmitted(),
                    inputFormatters: const [_DecimalTextInputFormatter()],
                    decoration: _bareInputDecoration(),
                  ),
                ),
              ),
            ),
          ),
          if (unit.isNotEmpty) ...[
            SizedBox(width: tokens.spacing.step2),
            Text(
              unit,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A tappable, clearly-editable summary of the observed-at timestamp. Carries a
/// trailing edit-calendar glyph so it never reads as a locked, read-only value,
/// and opens the shared date/time picker on tap.
class _ObservedAtField extends StatelessWidget {
  const _ObservedAtField({
    required this.dateTime,
    required this.focusNode,
    required this.autofocus,
    required this.onTap,
    super.key,
  });

  final DateTime dateTime;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.m);
    final formatted = _formatDateTime(context, dateTime);

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: context.messages.measurementObservedAtChangeSemantic(formatted),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          focusNode: focusNode,
          autofocus: autofocus,
          borderRadius: radius,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: tokens.colors.decorative.level01),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step4,
                vertical: tokens.spacing.step4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatted,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit_calendar_outlined,
                    size: tokens.spacing.step6,
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(BuildContext context, DateTime dateTime) {
  final localizations = MaterialLocalizations.of(context);
  final date = localizations.formatFullDate(dateTime);
  final time = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(dateTime),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '$date, $time';
}
