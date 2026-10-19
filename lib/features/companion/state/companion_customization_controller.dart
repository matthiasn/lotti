import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';

/// The [SettingsDb] key her customization is stored under, as JSON.
const companionCustomizationKey = 'COMPANION_CUSTOMIZATION';

/// How the person has made her their own, from Settings › Preferences ›
/// Companion, persisted in [SettingsDb] on this device.
///
/// Starts as the default — Lotti as the pitch videos draw her — and refines
/// from storage once it has loaded; a change made before that never loses
/// to the late load. Not synced across devices yet.
final companionCustomizationProvider =
    NotifierProvider<CompanionCustomizationController, CompanionCustomization>(
      CompanionCustomizationController.new,
      name: 'companionCustomizationProvider',
    );

class CompanionCustomizationController
    extends Notifier<CompanionCustomization> {
  /// Set by [set], so a late-resolving [_load] never clobbers it.
  bool _changed = false;

  @override
  CompanionCustomization build() {
    // Nothing waits on the load: she is drawn in the default until it lands,
    // and [_load] handles its own failure.
    _load().ignore();
    return const CompanionCustomization();
  }

  Future<void> _load() async {
    try {
      final stored = await ref
          .read(settingsDbProvider)
          .itemByKey(companionCustomizationKey);
      if (_changed || stored == null) return;
      state = CompanionCustomization.fromJson(
        jsonDecode(stored) as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      // Storage unreadable, or JSON it cannot parse: she stays as she is.
      ref
          .read(domainLoggerProvider)
          .error(
            LogDomain.settings,
            error,
            stackTrace: stackTrace,
            subDomain: 'companionCustomization',
            message: 'Could not load her customization',
          );
    }
  }

  /// Makes her [customization] and stores it.
  void set(CompanionCustomization customization) {
    _changed = true;
    state = customization;
    _save(customization).ignore();
  }

  Future<void> _save(CompanionCustomization customization) async {
    try {
      await ref
          .read(settingsDbProvider)
          .saveSettingsItem(
            companionCustomizationKey,
            jsonEncode(customization.toJson()),
          );
    } catch (error, stackTrace) {
      ref
          .read(domainLoggerProvider)
          .error(
            LogDomain.settings,
            error,
            stackTrace: stackTrace,
            subDomain: 'companionCustomization',
            message: 'Could not store her customization',
          );
    }
  }
}
