import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/providers/service_providers.dart';

/// Where the companion's card sits by a conversation, and how tall it is: one
/// placement for a phone, one for a desktop window, since a size that suits
/// one does not suit the other — and one for the card [docked] under a
/// desktop's list of conversations, which never moves and only grows.
enum CompanionCardForm {
  phone(
    settingsKey: 'COMPANION_CARD_PHONE',
    smallHeight: 172,
    largeHeight: 400,
  ),
  desktop(
    settingsKey: 'COMPANION_CARD_DESKTOP',
    smallHeight: 240,
    largeHeight: 480,
  ),

  /// Under the conversations beside a desktop's thread, as wide as they
  /// are: collapsed to her bust by default, expanded to all of her.
  docked(
    settingsKey: 'COMPANION_CARD_DOCKED',
    smallHeight: 160,
    largeHeight: 440,
  );

  const CompanionCardForm({
    required this.settingsKey,
    required this.smallHeight,
    required this.largeHeight,
  });

  /// The SettingsDb key the placement is kept under: device-local, never
  /// synced — a window on one machine says nothing about another's.
  final String settingsKey;

  /// The card's height when first shown — collapsed, where [docked] — and
  /// the size a double tap returns to from anything larger.
  final double smallHeight;

  /// The size a double tap grows the card to — expanded, where [docked]:
  /// big enough to watch her talk.
  final double largeHeight;

  /// The first placement: small, in the bottom-right corner.
  CompanionCardPlacement get initial =>
      CompanionCardPlacement(x: 1, y: 1, height: smallHeight);
}

/// The smallest the card may be pinched or dragged to: her face still reads.
const minCompanionCardHeight = 120.0;

/// Ceiling for a stored height; the card is further capped by the room it
/// has on screen.
const maxCompanionCardHeight = 2000.0;

/// How long after the last move or resize the placement is written.
@visibleForTesting
const companionCardPersistDebounce = Duration(milliseconds: 300);

/// The card's placement: [x] and [y] are shares (0–1) of the room it can
/// travel in — 0 the left or top edge, 1 the right or bottom — so a card in
/// a corner stays in it when the window or the phone turns; [height] is in
/// logical pixels.
@immutable
class CompanionCardPlacement {
  const CompanionCardPlacement({
    required this.x,
    required this.y,
    required this.height,
  });

  final double x;
  final double y;
  final double height;

  /// Whether the card sits in the lower half, so its resize grip goes on
  /// the top corner.
  bool get inLowerHalf => y >= 0.5;

  @override
  bool operator ==(Object other) =>
      other is CompanionCardPlacement &&
      other.x == x &&
      other.y == y &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, height);

  @override
  String toString() => 'CompanionCardPlacement($x, $y, $height)';
}

/// The placement of the companion's floating card for one
/// [CompanionCardForm], loaded from and saved to SettingsDb.
final NotifierProviderFamily<
  CompanionCardController,
  CompanionCardPlacement,
  CompanionCardForm
>
companionCardControllerProvider =
    NotifierProvider.family<
      CompanionCardController,
      CompanionCardPlacement,
      CompanionCardForm
    >(
      CompanionCardController.new,
      name: 'companionCardControllerProvider',
    );

class CompanionCardController extends Notifier<CompanionCardPlacement> {
  CompanionCardController(this.form);

  final CompanionCardForm form;

  bool _userAdjusted = false;
  Timer? _persist;

  @override
  CompanionCardPlacement build() {
    ref.onDispose(() => _persist?.cancel());
    // Catches its own failures: the first placement stands in for it.
    _load().ignore();
    return form.initial;
  }

  Future<void> _load() async {
    try {
      final stored = await ref
          .read(settingsDbProvider)
          .itemByKey(form.settingsKey);
      // A move made while the stored placement was read wins over it.
      if (_userAdjusted || stored == null) return;
      final json = jsonDecode(stored);
      if (json is! Map<String, dynamic>) return;
      double? read(String key) => switch (json[key]) {
        final num v when v.isFinite => v.toDouble(),
        _ => null,
      };
      final x = read('x');
      final y = read('y');
      final height = read('h');
      if (x == null || y == null || height == null) return;
      state = _clamped(x, y, height);
    } catch (error, stackTrace) {
      debugPrint('COMPANION_CARD load failed: $error\n$stackTrace');
    }
  }

  /// Moves the card by a share of its room on each axis.
  void moveBy(double dx, double dy) =>
      _set(_clamped(state.x + dx, state.y + dy, state.height));

  /// Gives the card [height], where it stands.
  void resizeTo(double height) => _set(_clamped(state.x, state.y, height));

  /// Switches between the small and the large card: anything above small
  /// goes back to small.
  void toggleSize() => resizeTo(
    state.height > form.smallHeight ? form.smallHeight : form.largeHeight,
  );

  /// Back to the first placement: small, bottom-right.
  void reset() => _set(form.initial);

  CompanionCardPlacement _clamped(double x, double y, double height) =>
      CompanionCardPlacement(
        x: x.clamp(0, 1),
        y: y.clamp(0, 1),
        height: height.clamp(minCompanionCardHeight, maxCompanionCardHeight),
      );

  void _set(CompanionCardPlacement placement) {
    _userAdjusted = true;
    if (placement == state) return;
    state = placement;
    _persist?.cancel();
    _persist = Timer(companionCardPersistDebounce, () {
      ref
          .read(settingsDbProvider)
          .saveSettingsItem(
            form.settingsKey,
            jsonEncode({'x': state.x, 'y': state.y, 'h': state.height}),
          )
          .ignore();
    });
  }
}
