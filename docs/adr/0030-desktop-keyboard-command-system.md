# ADR 0030: Desktop Keyboard Command System

## Status

Accepted (2026-07-15)

## Context

Lotti's desktop keyboard behavior grew through several unrelated mechanisms:
macOS `PlatformMenuBar` items, widget-local Flutter `Shortcuts`, raw key-event
handlers, and lifecycle-sensitive `hotkey_manager` registrations in controllers
and dialogs. Bindings, labels, availability, and help text therefore have no
shared source of truth. A shortcut can outlive the surface that registered it,
macOS receives a richer command set than Windows and Linux, punctuation
shortcuts assume a US keyboard layout, and keyboard-only activity is invisible
to the sync idle gate.

The desktop application needs one architecture that supports global commands,
focused-surface commands, control-local interactions, native menu adapters, a
command palette, and fully localized help without broadcasting every key event
to unrelated features.

## Decision

1. **Commands, not raw keyboard events, are the application boundary.** Lotti
   uses Flutter `Shortcuts`, `Actions`, `Intent`, and `ContextAction` for
   in-application commands. It does not introduce a broadcast keyboard event
   bus or OS-global shortcuts.
2. **One typed catalog is authoritative.** Stable `AppCommandId` values map to
   immutable definitions containing category/context metadata, default
   platform bindings, palette/help visibility, repeat policy, and destructive
   status. Execution, macOS menus, the command palette, and shortcut help all
   consume this catalog. Localized text is resolved outside the pure catalog.
3. **Handlers follow focus and widget lifetime.** `AppCommandScope` contributes
   handlers for the focused page, editor, list, or modal. Resolution starts at
   the focused scope, falls through parent scopes, and ends at the app-global
   scope. Scope disposal removes its handlers; no controller registers process-
   global hotkeys. The last active scope is retained for native-menu invocation
   while focus temporarily leaves Flutter.
4. **Bindings respect keyboard layouts.** Generated characters such as `?`,
   `+`, and `-` use `CharacterActivator`; letters, digits, function keys,
   arrows, and other special keys use `SingleActivator`. Command on macOS and
   Control on Windows/Linux are represented as one product-level "Primary"
   modifier. Help labels are formatted for the active platform and locale.
5. **Bindings are fixed in v1.** Stable command IDs and a replaceable catalog
   boundary leave room for future remapping, but v1 adds no persistence,
   conflict editor, or unused override API.
6. **The palette preserves its invocation context.** Opening the palette
   captures the active scope before the search field takes focus. Executing a
   result closes the palette, restores focus, and invokes the captured handler
   only while its scope remains mounted and enabled. Unavailable commands are
   omitted; destructive commands retain their normal confirmation flow.
7. **Focus regions are first-class desktop navigation.** The sidebar and each
   visible list/detail pane register as `KeyboardFocusRegion`s. F6 and Shift+F6
   cycle regions and restore the last focused descendant. Inactive
   `IndexedStack` destinations are excluded from focus and command resolution.
8. **Command execution is guarded.** Creation, save, and other one-shot
   commands ignore key repeats and concurrent re-entry. Continuous commands
   such as zoom, pan, and resize may opt into repeats. Failures are logged at
   the dispatcher boundary; feature handlers remain responsible for user-
   facing validation and feedback.
9. **Keyboard input counts as user activity.** Key-down and key-repeat events
   update `UserActivityService` without consuming the event, so keyboard-only
   editing cannot be mistaken for idle time by sync gating.
10. **Native menus are adapters.** macOS File, View, Go, and Help menus use the
    same definitions and dispatcher as in-app shortcuts. Windows and Linux use
    the in-app bindings, palette, and help surfaces. Once the existing
    registrations are migrated, `hotkey_manager` is removed.

The fixed navigation map is semantic rather than dependent on feature flags:
Primary+1 through Primary+8 always mean Tasks, Daily OS, Projects, Habits,
Dashboards, Journal, Events, and Settings. Disabled destinations leave gaps.

## Consequences

- Behavior, native-menu accelerators, palette results, and localized help
  cannot drift independently.
- Contextual commands become ordinary widget lifecycle state instead of
  controller or plugin state.
- Feature surfaces must expose handlers and meaningful focus structure; adding
  a catalog entry alone never makes a pointer-only workflow keyboard usable.
- The migration crosses the app shell, design-system primitives, and every
  major desktop destination. Each slice must ship with focused tests so an
  incomplete registration cannot silently shadow another scope.
- Mobile keeps its existing interaction model. Shared widgets must not regress,
  but mobile hardware-keyboard navigation is not part of this decision.

## Related

- Implementation plan:
  [`2026-07-15_desktop_keyboard_command_system.md`](../implementation_plans/2026-07-15_desktop_keyboard_command_system.md)
- Flutter focus and shortcut primitives are pinned by the repository's FVM
  Flutter SDK.
- Existing native menu adapter: `lib/widgets/misc/desktop_menu.dart`.
- Existing activity gate: `lib/features/user_activity/state/`.
