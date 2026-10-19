import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';

/// Pins what she wears in a test: the session's [outfit], drawn at random in
/// the app, and her [customization], loaded from the settings database in
/// the app — so a test neither draws nor reads storage.
List<Override> companionLookOverrides({
  CompanionLook outfit = CompanionLook.grandma,
  CompanionCustomization customization = const CompanionCustomization(),
}) => [
  companionOutfitProvider.overrideWithBuild((ref, notifier) => outfit),
  companionCustomizationProvider.overrideWithBuild(
    (ref, notifier) => customization,
  ),
];
