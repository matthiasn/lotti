import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/plaza/ui/plaza_palette.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// SettingsDb key for the sky the plaza is entered under.
const plazaSkyModeSettingsKey = 'PLAZA_SKY_MODE';

/// Remembers whether the walker last left the district in daylight or at
/// night, so entering it again does not undo the choice.
///
/// Loads once from [SettingsDb], holds the mode in memory and persists every
/// change. SettingsDb writes emit no `UpdateNotifications` token, so the
/// world watches this provider rather than re-reading the database. A
/// missing, unreadable or unrecognised preference yields night — the hour
/// the district was designed in — a failed write keeps the in-memory choice,
/// and a still-in-flight initial load never clobbers a choice just made.
class PlazaSkyModeController extends Notifier<PlazaSkyMode> {
  bool _chosen = false;

  @override
  PlazaSkyMode build() {
    unawaited(_load());
    return PlazaSkyMode.night;
  }

  Future<void> _load() async {
    if (!getIt.isRegistered<SettingsDb>()) return;
    final String? raw;
    try {
      raw = await getIt<SettingsDb>().itemByKey(plazaSkyModeSettingsKey);
    } catch (error, stackTrace) {
      _report('load', error, stackTrace);
      return;
    }
    if (!ref.mounted || _chosen || raw == null) return;
    state = PlazaSkyMode.fromName(raw);
  }

  /// Switches the sky and remembers it in the background. A failed write is
  /// logged and swallowed: the choice stands for this session.
  void set(PlazaSkyMode mode) {
    _chosen = true;
    if (state == mode) return;
    state = mode;
    unawaited(_persist(mode));
  }

  Future<void> _persist(PlazaSkyMode mode) async {
    if (!getIt.isRegistered<SettingsDb>()) return;
    try {
      await getIt<SettingsDb>().saveSettingsItem(
        plazaSkyModeSettingsKey,
        mode.name,
      );
    } catch (error, stackTrace) {
      _report('persist', error, stackTrace);
    }
  }

  /// Both database paths run fire-and-forget, so a thrown error would
  /// surface as an unhandled asynchronous error; it is logged instead.
  void _report(String operation, Object error, StackTrace stackTrace) {
    if (!getIt.isRegistered<DomainLogger>()) return;
    getIt<DomainLogger>().error(
      LogDomain.settings,
      error,
      stackTrace: stackTrace,
      subDomain: 'plazaSkyMode.$operation',
    );
  }
}

/// The remembered sky for every plaza world.
final NotifierProvider<PlazaSkyModeController, PlazaSkyMode>
plazaSkyModeProvider = NotifierProvider<PlazaSkyModeController, PlazaSkyMode>(
  PlazaSkyModeController.new,
  name: 'plazaSkyModeProvider',
);
