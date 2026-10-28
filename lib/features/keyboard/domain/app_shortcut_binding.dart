import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum _AppShortcutTriggerKind { logicalKey, character }

/// One default shortcut that resolves the product-level "Primary" modifier
/// for the active desktop platform.
///
/// The binding stores a const trigger specification rather than prebuilding
/// Flutter activators. That keeps the catalog const while allowing
/// [CharacterActivator] to be constructed with the runtime-selected platform
/// modifier.
@immutable
class AppShortcutBinding {
  const AppShortcutBinding.primaryKey(
    this.key, {
    this.shift = false,
    this.alt = false,
    this.includeRepeats = false,
    this.platforms,
  }) : _kind = _AppShortcutTriggerKind.logicalKey,
       character = null,
       usesPrimaryModifier = true;

  const AppShortcutBinding.primaryCharacter(
    this.character, {
    this.alt = false,
    this.includeRepeats = false,
  }) : _kind = _AppShortcutTriggerKind.character,
       key = null,
       usesPrimaryModifier = true,
       shift = false,
       platforms = null;

  const AppShortcutBinding.allKey(
    this.key, {
    this.shift = false,
    this.alt = false,
    this.includeRepeats = false,
  }) : _kind = _AppShortcutTriggerKind.logicalKey,
       character = null,
       usesPrimaryModifier = false,
       platforms = null;

  final _AppShortcutTriggerKind _kind;
  final LogicalKeyboardKey? key;
  final String? character;
  final bool usesPrimaryModifier;
  final bool shift;
  final bool alt;
  final bool includeRepeats;

  /// The desktop platforms this binding exists on, or null for all of them.
  ///
  /// For a command whose conventional key differs by platform — History is
  /// ⌘Y on macOS, where ⌘H is the system's Hide, and Ctrl+H elsewhere — the
  /// definition lists one binding per platform group.
  final Set<TargetPlatform>? platforms;

  ShortcutActivator? resolve(TargetPlatform platform) {
    final desktop = switch (platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      TargetPlatform.android ||
      TargetPlatform.fuchsia ||
      TargetPlatform.iOS => false,
    };
    if (!desktop) return null;
    if (platforms case final only? when !only.contains(platform)) return null;

    final meta = usesPrimaryModifier && platform == TargetPlatform.macOS;
    final control = usesPrimaryModifier && platform != TargetPlatform.macOS;
    return switch (_kind) {
      _AppShortcutTriggerKind.logicalKey => SingleActivator(
        key!,
        meta: meta,
        control: control,
        shift: shift,
        alt: alt,
        includeRepeats: includeRepeats,
      ),
      _AppShortcutTriggerKind.character => CharacterActivator(
        character!,
        meta: meta,
        control: control,
        alt: alt,
        includeRepeats: includeRepeats,
      ),
    };
  }
}
