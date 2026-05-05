import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Shows a transient confirmation that the named filter was saved.
///
/// Renders via the shared design-system toast (`context.showToast`) — same
/// rounded pill, palette, and queue behavior used by the label-detail
/// page when a label is created — instead of the ad-hoc themed
/// [SnackBar] this helper used previously.
void showSavedTaskFilterSavedToast(
  BuildContext context, {
  required String name,
}) {
  context.showToast(
    tone: DesignSystemToastTone.success,
    title: context.messages.tasksSavedFilterToastSaved(name),
  );
}

/// Shows a transient confirmation that an existing saved filter was updated.
void showSavedTaskFilterUpdatedToast(
  BuildContext context, {
  required String name,
}) {
  context.showToast(
    tone: DesignSystemToastTone.success,
    title: context.messages.tasksSavedFilterToastUpdated(name),
  );
}

/// Shows a transient confirmation that a saved filter was deleted.
void showSavedTaskFilterDeletedToast(BuildContext context) {
  context.showToast(
    tone: DesignSystemToastTone.success,
    title: context.messages.tasksSavedFilterToastDeleted,
  );
}
