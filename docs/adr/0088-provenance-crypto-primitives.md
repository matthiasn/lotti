# ADR 0088: Provenance Crypto Primitives

- Status: Accepted
- Date: 2026-09-26

## Context

Record provenance (the spec mapped in
[the Phase 0 document](../implementation_plans/2026-09-25_record_provenance_phase0_mapping.md))
signs every journal entry and hash-links it into its device's history. Phase 1
builds the primitives, and the spec left three of them open: the canonical
encoding (RFC 8785 JCS or deterministic CBOR), the hash (SHA-256 or BLAKE3), and,
implicitly, where Ed25519 comes from. It set a budget of under 1 ms to sign and
hash an envelope on a mid-range Android phone, and required that verification on
ingest not noticeably slow initial sync.

The app already depends on `crypto` (SHA-256) and `pointycastle`, which has no
Ed25519. Measured on a desktop x86 CPU with an envelope-sized message:

| Implementation | Sign | Verify |
|---|---:|---:|
| `cryptography` (pure Dart), JIT and AOT | ~1.25 ms | ~1.3 ms |
| libsodium over FFI | ~30 µs | ~57 µs |

A mid-range phone is several times slower than the desktop, which puts pure-Dart
signing at roughly 5–10 ms and verifying a 50,000-envelope catch-up at minutes.

## Decision

1. **Canonical encoding: RFC 8785 (JCS), restricted.** Only `null`, booleans,
   integers within ±(2^53 − 1), strings, lists and string-keyed maps; floats are
   rejected. The restriction makes the output byte-identical to full JCS without
   ECMAScript number formatting, the one hard part of JCS. Decoding is strict:
   input is accepted only if it re-encodes to the same bytes. JSON over CBOR for
   debuggability, as the spec suggested; envelope size does not warrant CBOR.
2. **Hash: SHA-256**, from the `crypto` package the app already uses.
3. **Domain separation by framing:** every hash and signature is over
   `tag ‖ 0x00 ‖ payload`, one tag per purpose (`lotti/envelope-signature/v1`,
   `lotti/envelope/v1`, `lotti/content/v1`, `lotti/device-id/v1`). This adds a NUL
   separator to the spec's `tag ‖ salt ‖ plaintext` commitment, so every domain
   frames the same way.
4. **Ed25519 from libsodium**, through the `sodium` package, behind one
   `Ed25519` interface. `sodium` 4 compiles libsodium from a source archive it
   bundles, in a Dart build hook, for each target platform; no network access and
   no system library are involved, so the offline Flathub build and `flutter test`
   both work without extra setup.
5. **Device id = SHA-256 fingerprint of the public key** under its own domain
   tag, and a signer can only sign envelopes carrying its own device id.

## Consequences

- Every build now compiles libsodium once per target: `configure` and `make` on
  Linux (including inside the Flatpak SDK), the NDK on Android, Xcode on Apple
  platforms, MSBuild on Windows. The native-hook cache keeps it to the first
  build.
- Secret keys stay in libsodium's protected memory; the signer never hands them
  out as bytes. Storing them in the platform keystore is Phase 2, which will add
  seed export and import.
- The known-answer tests are computed with Python's `hashlib` and `cryptography`
  packages, so the wire format is already checked against a second
  implementation — the basis for the standalone verifier (spec §12.4).
