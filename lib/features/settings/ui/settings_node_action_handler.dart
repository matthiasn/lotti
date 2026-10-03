import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/domain/settings_node.dart';
import 'package:lotti/features/settings/state/manual_language_controller.dart';
import 'package:lotti/features/whats_new/ui/whats_new_modal.dart';

/// Performs [SettingsNode.action] and reports whether an action was handled.
///
/// The Settings tree is shared by desktop and mobile, so both surfaces route
/// a tap through here first: the Manual opens the locale-aware manual URL and
/// What's New opens its modal, on either platform, instead of being treated
/// as a settings page.
bool handleSettingsNodeAction(
  BuildContext context,
  WidgetRef ref,
  SettingsNode node,
) {
  switch (node.action) {
    case SettingsNodeAction.openManual:
      unawaited(openManualForCurrentLocale(ref));
      return true;
    case SettingsNodeAction.openWhatsNew:
      unawaited(WhatsNewModal.show(context, ref));
      return true;
    case null:
      return false;
  }
}
