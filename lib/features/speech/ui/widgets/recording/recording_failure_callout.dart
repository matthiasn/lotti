import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recording_start_guard.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Why a recorder has nothing to hand back, and what to do about it: the
/// reason in plain words, *Open settings* where a refused microphone is the
/// reason, and *Stop that recording* where another take holds the recorder.
/// Trying again is the host's own record button beneath it.
///
/// One card for every surface that records — the recording strip's tray and
/// a goal's check-in — so a refused microphone reads the same wherever it
/// happens.
class RecordingFailureCallout extends StatelessWidget {
  const RecordingFailureCallout({
    required this.failure,
    required this.stopping,
    required this.onOpenSettings,
    required this.onStopRunning,
    this.bodyOf,
    this.leadingAction,
    super.key,
  });

  final InlineRecordingFailure failure;

  /// True while the running take is being stopped and saved.
  final bool stopping;
  final VoidCallback onOpenSettings;
  final VoidCallback onStopRunning;

  /// The host's own words for a failure, where it has a way forward of its
  /// own to name; the recorder's when it answers null.
  final String? Function(InlineRecordingFailure failure)? bodyOf;

  /// The host's own way forward, ahead of the recorder's — a goal's *Write
  /// instead*.
  final Widget? leadingAction;

  static const Key stopRunningKey = ValueKey('recording-failure-stop-running');
  static const Key openSettingsKey = ValueKey(
    'recording-failure-open-settings',
  );

  String _body(AppLocalizations messages) => switch (failure) {
    InlineRecordingFailure.microphoneDenied =>
      messages.chatInputRecordingNoMicPermission,
    InlineRecordingFailure.recorderBusy => messages.goalCheckInRecorderBusyBody,
    InlineRecordingFailure.startFailed ||
    InlineRecordingFailure.notSaved => messages.chatInputRecordingFailed,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final alert = tokens.colors.alert;
    final (tone, icon, title) = switch (failure) {
      InlineRecordingFailure.microphoneDenied => (
        alert.error.defaultColor,
        LottiIcons.micIdle,
        messages.checkInMicrophoneDeniedCalloutTitle,
      ),
      InlineRecordingFailure.startFailed => (
        alert.error.defaultColor,
        LottiIcons.micIdle,
        messages.checkInRecordingFailedTitle,
      ),
      InlineRecordingFailure.recorderBusy => (
        alert.warning.defaultColor,
        LottiIcons.mic,
        messages.checkInRecorderBusyTitle,
      ),
      InlineRecordingFailure.notSaved => (
        alert.error.defaultColor,
        LottiIcons.micIdle,
        messages.checkInRecordingNotSavedTitle,
      ),
    };
    return DesignSystemInlineCallout(
      key: ValueKey('recording-failure-${failure.name}'),
      icon: icon,
      tone: tone,
      title: title,
      text: bodyOf?.call(failure) ?? _body(messages),
      announce: true,
      actions: [
        ?leadingAction,
        if (failure == InlineRecordingFailure.recorderBusy)
          DesignSystemButton(
            key: stopRunningKey,
            label: messages.goalCheckInStopRunning,
            leadingIcon: LottiIcons.stop,
            variant: DesignSystemButtonVariant.secondary,
            size: DesignSystemButtonSize.medium,
            tapTargetSize: MaterialTapTargetSize.padded,
            isLoading: stopping,
            onPressed: onStopRunning,
          ),
        if (failure == InlineRecordingFailure.microphoneDenied)
          DesignSystemButton(
            key: openSettingsKey,
            label: messages.checkInOpenSettingsButton,
            leadingIcon: LottiIcons.settings,
            variant: DesignSystemButtonVariant.secondary,
            size: DesignSystemButtonSize.medium,
            tapTargetSize: MaterialTapTargetSize.padded,
            onPressed: onOpenSettings,
          ),
      ],
    );
  }
}
