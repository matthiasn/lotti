# Conventions

Rules this repository holds itself to, and the reasoning behind them.

* [How this bundle is maintained](knowledge-bundle.md) - the README/knowledge split, the frontmatter every concept carries, and what the validator enforces.
* [Testing conventions](testing.md) - fake time, centralized mocks, teardown discipline, and tagged property tests.
* [Localization](localization.md) - ARB catalogs, the informal register, and where localization happens.
* [Code style and analysis](code-style.md) - the zero-warning gate, generated code, and mandatory design tokens.
* [Screenshots](screenshots.md) - why captured images live in `lotti-docs` and never here, and why a UI pull request carries a before/after pair.

One more set of rules binds every UI change but is documented with the code it
governs rather than here:

* [Design system](../features/design_system/) - tokens instead of literals, the component contracts, and what is enforced at construction. `AGENTS.md` treats it as mandatory for visual work.

# Related

* [Architecture](../architecture/) - what the conventions are protecting.
* [Features](../features/) - where they are applied.
