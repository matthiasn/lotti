# Security Policy

## Reporting a Vulnerability

**Please do not report vulnerabilities in public issues.** Lotti holds people's
personal data on their own devices, so a public report exposes users before
there is a fix.

Use GitHub's private vulnerability reporting instead:
[**Report a vulnerability**](https://github.com/matthiasn/lotti/security/advisories/new).
It is enabled on this repository, the report is visible only to me, and it
gives us a private thread to work in.

What helps in a report:

- what an attacker can achieve, and what access they need to start
- affected platform and app version
- reproduction steps, or a proof of concept
- your assessment of the severity, and whether you plan to disclose publicly

I will acknowledge a report as soon as I have seen it, and keep you updated as I
work through it. This is a single-maintainer project, so please allow time for a
fix before publishing. Credit in the advisory and the release notes is yours
unless you prefer otherwise.

## Scope

In scope: the Lotti application on any supported platform, the sync protocol and
its encryption, the provisioning and pairing flow, and the handling of API keys
and other secrets.

Out of scope: vulnerabilities in third-party AI providers or Matrix homeservers
themselves — report those to their operators. Note also that Lotti does **not**
encrypt its local databases at rest, and that a homeserver operator can observe
sync metadata. Both are documented limitations rather than vulnerabilities; see
[PRIVACY.md](PRIVACY.md).
