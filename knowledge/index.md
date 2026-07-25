---
okf_version: "0.2"
---

# Lotti Knowledge Bundle

The architecture of the Lotti app, as it actually runs. Every concept here is
derived from the code it describes and carries the provenance to prove it.

Product-level descriptions of what each feature does for a user stay in the
feature's own `README.md` under `lib/`; those READMEs link here for the runtime
detail. See [How this bundle is maintained](conventions/knowledge-bundle.md)
before editing anything.

# Architecture

* [Architecture concepts](architecture/) - cross-cutting runtime structure: bootstrap, persistence, navigation, security, release.

# Domain

* [Domain concepts](domain/) - the entities the whole app is built on.

# Features

* [Feature concepts](features/) - one concept tree per module under `lib/features`.

# Conventions

* [Convention concepts](conventions/) - the rules this repository holds itself to.
