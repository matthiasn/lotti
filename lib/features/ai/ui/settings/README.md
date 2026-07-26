# AI settings UI

The screens where a user connects AI providers, installs models, and builds
inference profiles.

## What it does for the user

- **One page for all AI configuration**, split into Providers, Models and
  Profiles tabs with a shared search field.
- **Guides a first-time setup.** With no provider connected, the page shows a
  getting-started path instead of three empty lists.
- **Installs models from the provider.** Providers that publish a catalog list
  their available models for one-tap install, with the already-installed ones
  shown first.
- **Builds profiles from installed models.** A profile assigns models to
  capabilities — thinking, transcription, vision, image generation — so the rest
  of the app never names a model directly.
- **Sets device-local limits**, such as how many agents may think at once.

## Where the code lives

```text
lib/features/ai/ui/settings/
├── widgets/
│   ├── form_components/   # shared AI form controls
│   └── v2/
└── ...
```

## How it works

The single-scroll sliver layout with nothing pinned, the three tabs over one
filter model, and the first-run path are documented in the knowledge bundle:

**→ [knowledge/features/ai/settings-ui.md](../../../../../knowledge/features/ai/settings-ui.md)**
