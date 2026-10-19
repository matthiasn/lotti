import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/companion_settings_keys.dart';

export 'package:lotti/utils/companion_settings_keys.dart';

/// How the person has made her their own, from Settings › Preferences ›
/// Companion: stored in [SettingsDb] and synced across their devices.
///
/// Starts as the default — Lotti as the pitch videos draw her — and refines
/// from storage once it has loaded; a change made before that never loses
/// to the late load.
final companionCustomizationProvider =
    NotifierProvider<CompanionCustomizationController, CompanionCustomization>(
      CompanionCustomizationController.new,
      name: 'companionCustomizationProvider',
    );

/// Syncs her customization as the Daily OS greeting name syncs: [set] stores
/// it with a last-write stamp and enqueues a debounced
/// `SyncMessage.companionCustomization`; an inbound change, applied by sync
/// under last-write-wins and surfaced as a `settingsNotification`, reloads
/// her here and is never sent back. A customization stored on this device
/// but never published — made before sync, or while the outbox failed — is
/// published once on load, so it reaches the other devices without a
/// re-edit.
class CompanionCustomizationController
    extends Notifier<CompanionCustomization> {
  /// Set by [set], so a late-resolving [_load] never clobbers it.
  bool _changed = false;

  StreamSubscription<Set<String>>? _synced;
  final _debounceKey =
      'companion.customization.sync.${identityHashCode(Object())}';

  /// The stamp a customization from before sync is published with: older
  /// than any real change on any device, so it never overrides one.
  static const _bootstrapUpdatedAt = 1;

  @override
  CompanionCustomization build() {
    ref.onDispose(() {
      _synced?.cancel().ignore();
      EasyDebounce.cancel(_debounceKey);
    });
    // Before the load, so a change synced in during it is not missed.
    _watchSynced();
    // Nothing waits on the load: she is drawn in the default until it lands,
    // and [_load] handles its own failure.
    _load().ignore();
    return const CompanionCustomization();
  }

  Future<void> _load() async {
    try {
      final stored = await ref.read(settingsDbProvider).itemsByKeys(const [
        companionCustomizationKey,
        companionCustomizationUpdatedAtKey,
        companionCustomizationSyncedAtKey,
      ]);
      final json = stored[companionCustomizationKey];
      if (!ref.mounted || _changed || json == null) return;
      state = _decode(json);
      final updatedAt =
          int.tryParse(stored[companionCustomizationUpdatedAtKey] ?? '') ??
          _bootstrapUpdatedAt;
      if (int.tryParse(stored[companionCustomizationSyncedAtKey] ?? '') !=
          updatedAt) {
        _publish(json, updatedAt);
      }
    } catch (error, stackTrace) {
      // Storage unreadable, or JSON it cannot parse: she stays as she is.
      _logError(error, stackTrace, 'Could not load her customization');
    }
  }

  /// Makes her [customization], stores it, and sends it to the other
  /// devices.
  void set(CompanionCustomization customization) {
    _changed = true;
    state = customization;
    _save(customization).ignore();
  }

  Future<void> _save(CompanionCustomization customization) async {
    try {
      // The value and a fresh stamp together, so what is sent and what is
      // stored agree on which change wins.
      final saved = await ref
          .read(settingsDbProvider)
          .saveLocalSettingsGroup(
            {companionCustomizationKey: jsonEncode(customization.toJson())},
            stampKey: companionCustomizationUpdatedAtKey,
            timestamp: clock.now().millisecondsSinceEpoch,
          );
      if (!ref.mounted) return;
      _publish(saved.values[companionCustomizationKey]!, saved.updatedAt);
    } catch (error, stackTrace) {
      _logError(error, stackTrace, 'Could not store her customization');
    }
  }

  /// Sends [json] to the other devices, a quarter second after the last
  /// change, so a run of taps in settings goes out as one message.
  void _publish(String json, int updatedAt) {
    EasyDebounce.debounce(
      _debounceKey,
      const Duration(milliseconds: 250),
      () => _enqueue(json, updatedAt).ignore(),
    );
  }

  Future<void> _enqueue(String json, int updatedAt) async {
    try {
      await ref
          .read(outboxServiceProvider)
          .enqueueMessage(
            SyncMessage.companionCustomization(
              customization: json,
              updatedAt: updatedAt,
              status: SyncEntryStatus.update,
            ),
          );
      if (!ref.mounted) return;
      // Published: not to be published again on the next load.
      await ref
          .read(settingsDbProvider)
          .saveSettingsItem(
            companionCustomizationSyncedAtKey,
            updatedAt.toString(),
          );
    } catch (error, stackTrace) {
      _logError(error, stackTrace, 'Could not send her customization');
    }
  }

  /// Reloads her when sync has stored a change from another device, so an
  /// open screen shows it.
  void _watchSynced() {
    final notifications = ref.read(maybeUpdateNotificationsProvider);
    if (notifications == null) return;
    _synced = notifications.updateStream.listen((ids) {
      if (ids.contains(settingsNotification)) _reload().ignore();
    });
  }

  Future<void> _reload() async {
    try {
      // Sync resolved last-write-wins before it stored the value, so the
      // stored one is the winner, even over a change made here. A reload
      // never sends, so it cannot echo back.
      final json = await ref
          .read(settingsDbProvider)
          .itemByKey(companionCustomizationKey);
      if (!ref.mounted || json == null) return;
      final synced = _decode(json);
      if (synced != state) state = synced;
    } catch (error, stackTrace) {
      _logError(error, stackTrace, 'Could not reload her customization');
    }
  }

  static CompanionCustomization _decode(String json) =>
      CompanionCustomization.fromJson(jsonDecode(json) as Map<String, dynamic>);

  void _logError(Object error, StackTrace stackTrace, String message) {
    if (!ref.mounted) return;
    ref
        .read(domainLoggerProvider)
        .error(
          LogDomain.settings,
          error,
          stackTrace: stackTrace,
          subDomain: 'companionCustomization',
          message: message,
        );
  }
}
