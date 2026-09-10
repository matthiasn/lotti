import 'package:lotti/features/plaza/ui/plaza_palette.dart';

/// Decides when a change of sky needs a new set of painted wall textures.
///
/// The window and shopfront tiles are opaque — the texture *is* the wall — so
/// each hour has its own set and a switch has to paint and upload one. That
/// takes long enough for the walker to change their mind twice, which is the
/// whole reason this is a type rather than two fields: the state is "what is
/// on the walls, what is on its way, and is the set that just landed still
/// wanted", and getting it wrong leaves the district wearing the other sky's
/// windows with nothing scheduled to correct it.
///
/// Kept out of the renderer so it can be tested without a GPU.
class PlazaWallSwap {
  PlazaSkyMode? _inFlight;

  /// The set being painted right now, if any.
  PlazaSkyMode? get inFlight => _inFlight;

  /// The set to load so the world can wear [wanted], or null when there is
  /// nothing to do — the walls already show it, or it is already on its way.
  ///
  /// A request for the sky already on the walls does **not** cancel a load in
  /// flight for the other one: that load will settle on its own, and only
  /// then is its mode free to be asked for again.
  PlazaSkyMode? request({
    required PlazaSkyMode wanted,
    required PlazaSkyMode? attached,
  }) {
    if (wanted == attached || wanted == _inFlight) return null;
    return _inFlight = wanted;
  }

  /// Marks the load for [mode] as finished, however it ended — attached,
  /// dropped as no longer wanted, or failed.
  ///
  /// Every one of those has to clear the marker. A load that failed or was
  /// dropped and left it standing would make [request] believe that set is
  /// still coming, and the sky it belongs to could never be loaded again.
  void settled(PlazaSkyMode mode) {
    if (_inFlight == mode) _inFlight = null;
  }
}
