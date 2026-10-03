# ADR 0115: The GitHub Token Syncs Like an Inference Key

- Status: Accepted — implemented
- Date: 2026-10-03

## Context

GitHub pull request tracking (#4605) kept the user's personal access token on
the device that entered it: "It is never synced, logged or exported." In use,
that meant entering the token again on every device, and a device whose page
already showed "Connected as" offered no way to hand the token on. Lotti
already syncs inference providers' API keys between the user's devices — end
to end encrypted, kept in the receiver's keychain — and the GitHub token is
read-only, so the reason to treat it more strictly than those keys did not
hold.

## Decision

1. **The token syncs, on the channel inference keys use.** A `gitHubAccount`
   sync message carries the token and its login, end-to-end encrypted; the
   receiver keeps it in its keychain, never in a database. The token is a
   `SyncSecret` in the message, whose `toString` is redacted, so no log line
   or debug print shows it.
2. **One keychain record, the later version winning.** The token, its login
   and the stamp of the change are one keystore value, written in one step. A
   received version replaces the held one if its stamp is later, an equal
   stamp decided by content. A change made on a device is stamped past the
   version it was made over, whatever that device's clock says.
3. **A disconnection syncs too.** Disconnecting forgets the token on every
   device, as deleting an inference provider removes its key everywhere.
4. **A received token is checked before it shows.** A device asks GitHub
   (`GET /user`) about a token it received before showing it as connected;
   one GitHub rejects is reported, and the device asks for a token instead.
5. **Syncing is not tied to the settings page.** Connecting and disconnecting
   send; the page has one small action, "send to my other devices" or "check
   my other devices", rather than syncing every time it opens.

`specs/tla/GitHubAccountSync.tla` models the record across devices; turning
off the stamp bump, the content tie-break or the check each has a
counterexample.

## Consequences

- One token entered once reaches every device of the user's; guest and demo
  worlds, which have no sync stack, still never receive it.
- The token is now as exposed as an inference key: in transit only inside the
  end-to-end encrypted sync channel, and in an outbox row until it is sent.
  It is still sent only to `api.github.com`, and never logged or exported.
- Revoking the token on github.com stops every device at its next check, and
  each says so; disconnecting on one device disconnects all of them.
