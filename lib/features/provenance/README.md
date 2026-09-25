# Provenance

Record provenance makes Lotti's journal tamper-evident and attributable: every
entry is signed by the device that wrote it and hash-linked into that device's
history, agent changes exist as signed proposals that take effect only through a
signed user approval, and derived material points verifiably at the entries it
came from. The promise it enables: not even the sync server can alter your
history without it being detected, and every AI change shows who proposed it and
who approved it.

## What exists today

Phase 1 of the rollout: the cryptographic core, as a pure library. Nothing in
the app calls it yet, so it changes no behaviour and needs no feature flag.

- **Canonical JSON** (`crypto/canonical_json.dart`) — RFC 8785 for the values
  envelopes carry, and a strict parser that accepts only canonical bytes, so one
  envelope has exactly one encoding.
- **Domain-separated SHA-256** (`crypto/domain_hash.dart`) — every hashed or
  signed structure is framed with its own tag, so a hash made for one purpose
  can never pass for another.
- **Content commitments** (`crypto/content_commitment.dart`) — a salted hash of
  an entry's plaintext. The envelope carries only the hash; deleting the content
  and its salt leaves nothing to match a guess against.
- **Ed25519** (`crypto/ed25519.dart`) — one signer interface, backed by
  libsodium, which the `sodium` package builds from source and bundles on every
  platform.
- **The envelope** (`model/envelope.dart`, `envelope_crypto.dart`) — the v1
  format with its structural rules, signing, verification, device ids and the
  envelope hash that chains envelopes together.

## What it does not do yet

Device and identity keys and the keystore, per-device chains in the write path,
verification on ingest, the agent approval choke point, deletion tombstones and
derivation envelopes are later phases. They are listed, with the decisions they
depend on, in the Phase 0 mapping
(`docs/implementation_plans/2026-09-25_record_provenance_phase0_mapping.md`).
Already decided for them: each device keeps **one chain per store**, not one
chain across all stores.

## Where the code sits

```
lib/features/provenance/
  crypto/            canonical JSON, hex, domain hashes, commitments, Ed25519
  model/envelope.dart
  envelope_crypto.dart
```

The architecture — the framing, the canonical form, the envelope rules and why
they are what they are — is in the
[provenance concept](../../../knowledge/features/provenance.md).
