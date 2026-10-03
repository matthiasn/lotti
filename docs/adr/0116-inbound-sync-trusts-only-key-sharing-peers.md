# ADR 0116: Inbound Sync Trusts Only the Devices It Shares Keys With

- Status: Accepted — implemented
- Date: 2026-10-03

## Context

Outbound sync shares Megolm keys only with directly verified devices
(`ShareKeysWith.directlyVerifiedOnly`, ADR 0045). Inbound sync had no
counterpart. The queue admitted any event whose `msgtype` looked like a sync
payload, and the Matrix SDK neither rejects plaintext in an encrypted room nor
checks which device a Megolm session came from. An assessment on 2026-10-03
found that anyone able to post into the sync room — whoever holds the account
password, or the homeserver's operator, including the operator of a paid
provisioned bundle — could inject sync payloads. A synced `AiConfig` is saved
as received, so one injected event could point a provider's `baseUrl` at an
attacker and send journal, task and audio content there, defeating the
end-to-end-encryption threat model. The same door admitted attachment
descriptors, which name the JSON a payload resolves to.

The Matrix SDK (12.0.1) facts that shape the check:

- A decrypted event keeps its ciphertext as `originalSource`; an event that
  arrived in plaintext never has one.
- The decrypted event carries no device information. The cryptographically
  bound sender is the Curve25519 key the Megolm session was received under
  (`SessionKey.senderKey`), found through `KeyManager`. The event's own
  `sender_key` and `device_id` fields are plaintext claims.
- A forwarded session records the forwarder's key, not the creator's, and an
  imported session's key is whatever the importer wrote. Lotti never requests
  or forwards room keys and does not use key backup.
- The SDK deletes a device's keys once that device logs out.

## Decision

1. **One policy, `SyncEventTrust`, decides every inbound door.** An event is
   trusted only when it was decrypted from a Megolm session that was not
   forwarded and whose sender key belongs to a device of the event's sender
   that this device would encrypt to (`DeviceKeys.encryptToDevice` under the
   client's `shareKeysWith`). Inbound acceptance therefore mirrors outbound
   key sharing exactly, and follows it if that policy ever changes. This
   device's own sessions (the server echo of what it sent) are trusted for its
   own user only.

2. **Every door checks it.**
   - Payloads: `InboundQueue.enqueueBatch` (rule F8), which every producer —
     live, bootstrap, gap recovery — reaches. The queue takes the policy as a
     required argument, so no construction can skip it.
   - Attachment descriptors from the timeline and from bootstrap pages: the
     coordinator's attachment hook, before the descriptor is indexed or
     downloaded.
   - Descriptors fetched by event id during exact-id recovery: before
     indexing. A malicious server can answer an id lookup with anything.
     Without a policy, the processor does not attempt the lookup at all.

3. **Rejected events are dropped, not retried.** A rejected payload counts
   as `rejectedUntrusted` and never enters the queue, so the marker may pass
   it like any non-payload event. A legitimate device never produces one: the
   room is created encrypted, and a sender shares its session keys only with
   devices it verified, which under SAS verification have verified it too.

4. **Trust outlives a logout.** Each sender found trusted is recorded in
   `trusted_sync_senders` (sync DB v34), device-local and never written by
   sync. The record is consulted only for a sender the SDK no longer lists,
   so history from a device that logged out while this one was offline still
   applies. A listed device is always judged by its current state, and one
   found untrusted is removed from the record, so blocking a device before it
   is deleted still revokes it.

## Consequences

- Injected plaintext, events from unverified or blocked devices, forwarded
  sessions and descriptors served for them are refused, with a
  `sync.trust.rejected` warning naming the verdict.
- A synced `AiConfig` can now only come from the user's own verified device,
  which closes the redirection path without a separate confirmation step.
- The uncapped gzip decode of attachments is reachable only from trusted
  devices.
- A device whose keys the SDK has not downloaded yet and that was never
  trusted here is rejected. Verification requires those keys, so a verified
  peer is always listed.
- Rows admitted before this change stay in the queue and apply as before.

## Related

- ADR 0045 — exclude unverified devices from key sharing (the outbound half).
- [Sync receive path](../../knowledge/features/sync/receive-path.md#inbound-trust)
