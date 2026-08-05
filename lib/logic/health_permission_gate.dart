import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:lotti/logic/health_data_types.dart';
import 'package:lotti/services/health_service.dart';

/// What the platform was willing to say about read access to a family of health
/// data types.
///
/// The third value is not hedging — it is the honest answer on iOS. Apple
/// refuses to disclose read authorization at all (knowing an app was denied
/// would itself leak health information), so `hasPermissions` returns `null` and
/// `requestAuthorization` reports only that a sheet was *shown*, never that it
/// was answered "allow".
enum HealthAuthorization {
  /// The platform confirmed read access. Health Connect only.
  granted,

  /// The platform confirmed read access is missing, or refused to raise its
  /// authorization sheet at all. Nothing will be read.
  denied,

  /// The platform will not say (iOS). Read anyway and let the result speak: an
  /// empty read means either "no samples" or "not allowed", and there is no API
  /// that distinguishes them.
  undisclosed,
}

/// Decides when Lotti may raise the system's health authorization sheet, and
/// for which types.
///
/// Two rules, both of which exist because of a bug rather than for tidiness:
///
/// **Ask for the whole family.** The blood-pressure dashboard card mounts one
/// controller per series, so it starts two independent background imports —
/// systolic and diastolic — and each used to raise its own authorization
/// request. What the user turned on or off as a single "Blood Pressure" switch
/// asked them twice, back to back, on every visit. [ensure] expands whatever it
/// is handed to [expandToPermissionFamilies] first, so one family means one
/// sheet.
///
/// **Ask once per session, unless the user asked for it.** Authorization was
/// requested unconditionally on *every* import, including the background deltas
/// a dashboard fires on open. Once the types are determined — allowed, or
/// switched off in Settings → Privacy & Security → Health — re-requesting
/// cannot change anything and the user is shown a sheet with nothing in it to
/// answer. The gate remembers what it has already asked for and stays quiet,
/// *except* when the request comes from a deliberate user action
/// (`userInitiated: true`, i.e. a tap on the Health Import page), which is
/// exactly when re-asking is what the user wants.
///
/// The memory is per-instance and per-session by design: it must not outlive a
/// launch, because a permission granted in system settings while Lotti was
/// backgrounded should be picked up on the next run without ceremony.
class HealthPermissionGate {
  HealthPermissionGate(this._health);

  final HealthService _health;

  /// Families this gate has already raised an authorization request for.
  final Set<HealthDataType> _requested = <HealthDataType>{};

  /// The types asked for so far — the session memory [ensure] consults.
  @visibleForTesting
  Set<HealthDataType> get requestedTypes => Set.unmodifiable(_requested);

  /// Ensures [types] — and everything in their permission families — is
  /// authorized, raising the system sheet only when doing so can accomplish
  /// something.
  ///
  /// [userInitiated] marks a request the user explicitly triggered. It bypasses
  /// the ask-once memory, so tapping a row on the Health Import page really
  /// does ask again; a background dashboard import never sets it.
  Future<HealthAuthorization> ensure(
    List<HealthDataType> types, {
    required bool userInitiated,
  }) async {
    if (types.isEmpty) {
      // Nothing to authorize. The caller's read will return nothing, which is
      // the truthful outcome — reporting a permission problem would not be.
      return HealthAuthorization.granted;
    }

    final family = expandToPermissionFamilies(types);

    // Health Connect answers this definitively; HealthKit returns null. When it
    // says yes, there is nothing to ask for and no sheet is raised at all.
    final known = await _health.hasPermissions(family);
    if (known ?? false) {
      _requested.addAll(family);
      return HealthAuthorization.granted;
    }

    if (!userInitiated && _requested.containsAll(family)) {
      return known == false
          ? HealthAuthorization.denied
          : HealthAuthorization.undisclosed;
    }

    _requested.addAll(family);

    // On iOS this returns true merely because the sheet was displayed without
    // error — never that access was granted. False means the platform refused
    // to raise it, which is a genuine refusal.
    final requestSucceeded =
        await _health.requestAuthorization(family) ?? false;
    if (!requestSucceeded) {
      return HealthAuthorization.denied;
    }

    // Only worth re-reading where the first read was informative. A `null`
    // first answer means the platform does not disclose read access, so asking
    // again would spend a channel round-trip to be told `null` a second time.
    if (known == null) {
      return HealthAuthorization.undisclosed;
    }

    final granted = await _health.hasPermissions(family) ?? false;
    return granted ? HealthAuthorization.granted : HealthAuthorization.denied;
  }
}
