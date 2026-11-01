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
/// but never published — while the outbox failed — is published once on
/// load, so it reaches the other devices without a re-edit.
class CompanionCustomizationController
    extends Notifier<CompanionCustomization> {
  /// Whether what she was set to is known: read from storage (nothing
  /// stored counts — she is the default) or set here. False while the read
  /// is out, and after it failed unless a change made meanwhile was then
  /// stored — so a host that must not guess (her voice, muted or not) can
  /// wait.
  bool get loaded => _loaded;
  bool _loaded = false;

  /// Whether the first read is out: set as [build] starts it.
  bool _loading = false;

  /// The change made while the read was out, and every part any change
  /// then touched — kept apart from [state], which a reload may replace.
  /// Only those parts are laid over what the read finds, so a part stored
  /// there and never touched — a mute — is not overwritten by the default
  /// shown before; a part switched and switched back still counts as set.
  CompanionCustomization? _pendingTo;
  final Set<String> _touched = {};

  /// Saves not yet committed. A reload while one is pending would read the
  /// value it is about to replace, so it waits until the last one lands.
  var _saving = 0;
  var _reloadPending = false;

  /// What is stored, as last read or written here. A change is laid over it,
  /// so the parts it leaves alone keep what a newer version wrote there.
  Map<String, dynamic>? _stored;

  StreamSubscription<Set<String>>? _synced;
  final _debounceKey =
      'companion.customization.sync.${identityHashCode(Object())}';

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
    _loading = true;
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
      if (!ref.mounted) return;
      _loading = false;
      final raw = json == null ? null : _parse(json);
      final found = raw == null ? null : CompanionCustomization.fromJson(raw);
      _stored = raw;
      final pending = _pendingTo;
      if (pending != null) {
        // A change made while this read was out: laid over what it found.
        final merged = (found ?? const CompanionCustomization()).adopting(
          pending,
          {..._touched},
        );
        _pendingTo = null;
        _touched.clear();
        _write(merged);
        return;
      }
      _loaded = true;
      _reloadIfAsked();
      if (found == null || json == null) return;
      state = found;
      // Every write stores its stamp with the value, so one without a stamp
      // has nothing to win with and is not sent.
      final updatedAt = int.tryParse(
        stored[companionCustomizationUpdatedAtKey] ?? '',
      );
      if (updatedAt != null &&
          int.tryParse(stored[companionCustomizationSyncedAtKey] ?? '') !=
              updatedAt) {
        _publish(json, updatedAt);
      }
    } catch (error, stackTrace) {
      // Storage unreadable, or JSON it cannot parse: she stays as she is.
      _logError(error, stackTrace, 'Could not load her customization');
      _loading = false;
      // A change made meanwhile is all there is to keep: stored as it is.
      final pending = _pendingTo;
      if (pending != null && ref.mounted) {
        _pendingTo = null;
        _touched.clear();
        _write(pending);
      } else if (ref.mounted) {
        _reloadIfAsked();
      }
    }
  }

  /// Makes her [customization], stores it, and sends it to the other
  /// devices.
  void set(CompanionCustomization customization) {
    if (_loading) {
      // Shown at once, stored once the read lands (see [_load]).
      _touched.addAll(
        CompanionCustomization.changedParts(state, customization),
      );
      _pendingTo = customization;
      state = customization;
      return;
    }
    _write(customization);
  }

  void _write(CompanionCustomization customization) {
    _loaded = true;
    state = customization;
    final stored = _stored;
    final json = stored == null
        ? customization.toJson()
        : customization.toJsonOver(stored);
    _stored = json;
    _save(jsonEncode(json)).ignore();
  }

  Future<void> _save(String json) async {
    _saving++;
    try {
      // The value and a fresh stamp together, so what is sent and what is
      // stored agree on which change wins.
      final saved = await ref
          .read(settingsDbProvider)
          .saveLocalSettingsGroup(
            {companionCustomizationKey: json},
            stampKey: companionCustomizationUpdatedAtKey,
            timestamp: clock.now().millisecondsSinceEpoch,
          );
      if (!ref.mounted) return;
      _publish(saved.values[companionCustomizationKey]!, saved.updatedAt);
    } catch (error, stackTrace) {
      _logError(error, stackTrace, 'Could not store her customization');
    } finally {
      _saving--;
      if (ref.mounted) _reloadIfAsked();
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

  /// Runs a reload asked for while one could not run, once it can.
  void _reloadIfAsked() {
    if (_saving == 0 && !_loading && _reloadPending) {
      _reloadPending = false;
      _reload().ignore();
    }
  }

  Future<void> _reload() async {
    if (_saving > 0 || _loading) {
      // What is stored is about to change, or the first read — and a change
      // made during it — has not landed yet: read it once it has.
      _reloadPending = true;
      return;
    }
    try {
      // Sync resolved last-write-wins before it stored the value, so the
      // stored one is the winner, even over a change made here. A reload
      // never sends, so it cannot echo back.
      final json = await ref
          .read(settingsDbProvider)
          .itemByKey(companionCustomizationKey);
      if (!ref.mounted || json == null) return;
      final raw = _parse(json);
      final synced = CompanionCustomization.fromJson(raw);
      _stored = raw;
      if (synced != state) state = synced;
    } catch (error, stackTrace) {
      _logError(error, stackTrace, 'Could not reload her customization');
    }
  }

  static Map<String, dynamic> _parse(String json) =>
      jsonDecode(json) as Map<String, dynamic>;

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
