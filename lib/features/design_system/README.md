# Design system

The design system is where Lotti's visual decisions live: colors, spacing,
typography, corner radii, and the reusable controls built from them.

Its job is to make those decisions explicit and shared, so features stop nudging
spacing and color in random files and the app looks like one product rather than
several.

## What it does for the product

- **One source of visual truth.** Colors, spacing, type and radii come from a
  token file exported from design, generated into typed Dart, and consumed
  everywhere. Changing a token changes the app, not fifty files.
- **A component library.** Buttons, inputs, search fields, dropdowns, chips,
  badges, avatars, tooltips, lists, filters, pickers, navigation, toasts,
  spinners and progress bars — all token-backed and consistent.
- **Accessibility built in, not bolted on.** Components refuse to be created
  without accessible names, announce validation errors, expose disabled state
  honestly, and hold text and fills to WCAG contrast floors that are checked by
  tests.
- **Light and dark that both actually work.** Surfaces adapt to what they sit on
  rather than assuming a fixed background, so a field looks right in a modal and
  on a page.
- **A place to see and try components.** Widgetbook renders every component in
  isolation with adjustable knobs, so a control can be reviewed without running
  the whole app.

## What it owns

The token import pipeline and generated token classes; the standalone
design-system theme and the extension that injects tokens into the app theme; the
component library; and the Widgetbook preview surface.

It is also a **policy seam**: features are expected to use tokens and components
rather than one-off values, and to improve the token source when something is
genuinely missing.

## Where the code lives

```text
lib/features/design_system/
├── theme/
│   └── generated/       # design_tokens.g.dart — do not hand-edit
├── components/          # the component library
├── utils/
└── widgetbook/
```

The generator lives at `tool/design_system/generate_tokens.dart`, the token source
at `assets/design_system/tokens.json`, and regeneration runs through
`make design_system_import`.

## How it works

The token pipeline, the two runtime theme paths, the alert ramp's contrast
contract, and the component patterns that are contract rather than coincidence
are documented in the knowledge bundle:

**→ [knowledge/features/design_system/](../../../knowledge/features/design_system/)**
