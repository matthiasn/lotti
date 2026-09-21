import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';

/// A call or message the user started from Lotti and has not yet logged
/// (plan v2 phase 7 items 4–5, ADR 0041 D4).
typedef PendingInteraction = ({
  String relationshipId,
  CheckInInteractionType interactionType,
  DateTime startedAt,
});

/// Settings key holding the single outstanding marker.
///
/// Device-local by construction: this lives in `settings.sqlite`, which does
/// not sync. A call placed from a phone is not an event the desktop should
/// prompt about, and the marker describes a device's own behavior rather than
/// anything about the person — so it must never enter the journal or the
/// sync outbox.
const pendingInteractionKey = 'RELATIONSHIP_PENDING_INTERACTION';

/// How long a marker stays worth asking about.
///
/// Long enough to survive a real conversation plus the app being backgrounded
/// for a while; short enough that a call placed yesterday, after which the
/// user simply never returned, does not greet them with a stale prompt the
/// next morning. Declining and forgetting must look the same to the user.
const pendingInteractionTtl = Duration(hours: 6);

/// Remembers that the user left Lotti to contact someone, so the next resume
/// can offer to log it.
///
/// Exactly one marker is kept. Someone who calls Anna and then messages Bo
/// before returning is asked about Bo — the most recent departure is the one
/// they just came back from, and a queue of prompts would be worse than
/// missing one. Nothing here auto-creates a check-in; the marker only decides
/// whether to *offer* one (ADR 0041 D4: the check-in stays user-authored).
class PendingInteractionStore {
  PendingInteractionStore({SettingsDb? settingsDb})
    : _settingsDb = settingsDb ?? getIt<SettingsDb>();

  final SettingsDb _settingsDb;

  /// Records that [interactionType] with [relationshipId] just started,
  /// replacing any previous marker.
  Future<void> remember({
    required String relationshipId,
    required CheckInInteractionType interactionType,
  }) => put((
    relationshipId: relationshipId,
    interactionType: interactionType,
    startedAt: clock.now(),
  ));

  /// Writes [pending] as the marker exactly as given — its original start
  /// included, so a marker handed back keeps its age and its expiry.
  Future<void> put(PendingInteraction pending) => _settingsDb.saveSettingsItem(
    pendingInteractionKey,
    jsonEncode({
      'relationshipId': pending.relationshipId,
      'interactionType': pending.interactionType.name,
      'startedAt': pending.startedAt.toIso8601String(),
    }),
  );

  /// The outstanding marker, or null when there is none, when it has expired,
  /// or when the stored value cannot be read.
  ///
  /// An expired or unreadable marker is cleared as a side effect, so a value
  /// that can never produce a prompt does not sit in settings forever.
  /// Corrupt JSON is treated as absence rather than an error: this is a
  /// convenience prompt, and no part of it is worth failing a resume over.
  Future<PendingInteraction?> read() async {
    final raw = await _settingsDb.itemByKey(pendingInteractionKey);
    if (raw == null || raw.isEmpty) return null;

    PendingInteraction? parsed;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final relationshipId = json['relationshipId'] as String?;
      final startedAt = DateTime.tryParse(json['startedAt'] as String? ?? '');
      final interactionType = CheckInInteractionType.values
          .asNameMap()[json['interactionType']];

      parsed =
          (relationshipId == null ||
              relationshipId.isEmpty ||
              startedAt == null ||
              interactionType == null)
          ? null
          : (
              relationshipId: relationshipId,
              interactionType: interactionType,
              startedAt: startedAt,
            );
    } on Object {
      parsed = null;
    }

    if (parsed == null) {
      await clear();
      return null;
    }

    if (clock.now().difference(parsed.startedAt) >= pendingInteractionTtl) {
      await clear();
      return null;
    }

    return parsed;
  }

  /// Drops the marker — after the user logs the check-in, declines the
  /// prompt, or the person is deleted. Declining must leave no trace.
  Future<void> clear() => _settingsDb.removeSettingsItem(pendingInteractionKey);
}

final pendingInteractionStoreProvider = Provider<PendingInteractionStore>(
  (ref) => PendingInteractionStore(),
  name: 'pendingInteractionStoreProvider',
);

/// Claims the marker on behalf of a door other than the offer that shows
/// it, and counts the claims. The store is plain settings with nothing to
/// listen to, so the count is how the offer learns that the question it is
/// asking has already been answered elsewhere.
class PendingInteractionClaims extends Notifier<int> {
  @override
  int build() => 0;

  /// Takes the outstanding marker when it is about [relationshipId]: returns
  /// it and clears it, so the caller can open the composer describing that
  /// call and the offer stops asking. Null — and nothing cleared — when
  /// there is no marker or it is about someone else: logging a check-in with
  /// Bo must not swallow the call just placed to Anna.
  ///
  /// Claims are exclusive. Each one runs after the previous has cleared, so
  /// two taps landing together — Log check-in and Dictate — cannot both read
  /// the marker before either clears it and open two prefilled composers for
  /// one call.
  Future<PendingInteraction?> claimFor(String relationshipId) {
    final claim = _previous.then((_) => _claim(relationshipId));
    // The chain waits on completion, not success: a failed claim must not
    // wedge every later one.
    _previous = claim.then<void>((_) {}, onError: (Object _) {});
    return claim;
  }

  Future<void> _previous = Future<void>.value();

  final Set<String> _opening = {};

  /// Marks a composer for [relationshipId] as opening. False when one
  /// already is: a second tap while the first is still claiming would get no
  /// marker and stack a generic composer on the first. Held here rather than
  /// in a global so it lives exactly as long as the claims it guards.
  bool beginOpening(String relationshipId) => _opening.add(relationshipId);

  /// Ends what [beginOpening] started — once the composer has closed.
  void endOpening(String relationshipId) => _opening.remove(relationshipId);

  /// Hands back a claim that came to nothing — the composer it opened was
  /// closed without saving. The marker returns as it was, and the count
  /// moves so the offer reads it again: a stray swipe on a sheet prefilled
  /// with a call must not lose the call. [PendingInteractionStore.read]
  /// still drops it once it expires.
  Future<void> release(PendingInteraction pending) async {
    await ref.read(pendingInteractionStoreProvider).put(pending);
    if (ref.mounted) state++;
  }

  Future<PendingInteraction?> _claim(String relationshipId) async {
    final store = ref.read(pendingInteractionStoreProvider);
    final pending = await store.read();
    if (pending == null || pending.relationshipId != relationshipId) {
      return null;
    }
    await store.clear();
    if (ref.mounted) state++;
    return pending;
  }
}

final pendingInteractionClaimsProvider =
    NotifierProvider<PendingInteractionClaims, int>(
      PendingInteractionClaims.new,
      name: 'pendingInteractionClaimsProvider',
    );
