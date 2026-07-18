import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/state/manual_language_controller.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';

/// Performs [SettingsNode.action] and reports whether an action was handled.
///
/// The Settings tree is shared by desktop and mobile. Keeping immediate
/// actions here ensures both surfaces use the same locale-aware Manual URL
/// instead of treating the row like an internal settings route.
bool handleSettingsNodeAction(WidgetRef ref, SettingsNode node) {
  switch (node.action) {
    case SettingsNodeAction.openManual:
      unawaited(
        openManualInBrowser(
          systemLocale: WidgetsBinding.instance.platformDispatcher.locale,
          override: ref.read(manualLanguageControllerProvider).value,
        ),
      );
      return true;
    case null:
      return false;
  }
}
