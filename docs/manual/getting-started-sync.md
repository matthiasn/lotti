# Sync Between Your Devices — Matrix Provisioner Walkthrough

Lotti syncs your logbook *and* your agents' state between *your own* devices over end‑to‑end encrypted Matrix. There's no Lotti backend in the middle; a homeserver only relays ciphertext.

This guide takes you from "I have Lotti on one device" to "the same logbook and the same agents are live on a second device, with everything keyed end‑to‑end with Vodozemac."

> **What sync is, and what it isn't.** This is **single‑user, multi‑device** sync. It is *not* a collaboration layer. There is no "share a task with your colleague" feature here. Every device that joins a sync room sees everything that user has logged.

---

## What you'll need

- A **Synapse Matrix homeserver** that you (or a sysadmin you trust) administer. Public homeservers like matrix.org generally won't work because the provisioner uses the Synapse Admin API to create the sync user.
- An **admin account** on that homeserver.
- Python 3.10+ on a machine with network access to the homeserver.
- A first device running Lotti (desktop is recommended for first import; mobile works too).

> **Don't have a homeserver?** Self‑hosting Synapse is a one‑evening project on a small VPS — see [matrix.org/docs/guides/installing-synapse](https://matrix.org/docs/guides/installing-synapse). Hosted Lotti sync infrastructure is **not** something the project provides.

---

## Step 1 — Run the provisioner

The provisioner is a small Python CLI in this repository at [`tools/matrix_provisioner/`](../../tools/matrix_provisioner/). It creates a dedicated Matrix user, a private end‑to‑end encrypted room, and a Base64url‑encoded **provisioning bundle** that the Lotti client knows how to import.

```bash
cd tools/matrix_provisioner
make setup-env
source .venv/bin/activate
make install-dev
```

Then run it (the password‑via‑env‑var form is the safe one):

```bash
export MATRIX_ADMIN_PASSWORD='<your homeserver admin password>'
python provision.py \
  --homeserver https://matrix.example.com \
  --admin-user admin \
  --username lotti_sync_user42 \
  --output-file bundle.txt
```

This produces a single‑line file `bundle.txt` containing the bundle. Behind the scenes, the provisioner:

1. Logs in as your admin and obtains a token.
2. Generates a long random password for the new user.
3. Creates the user via the Synapse Admin API.
4. Creates a private E2EE room with a `m.lotti.sync_room` state marker (federation off).
5. Writes the provisioning bundle to `--output-file`.

Nothing sensitive is printed to stdout. Use `--verbose` for a redacted JSON summary on stderr if you need to debug.

See [`tools/matrix_provisioner/README.md`](../../tools/matrix_provisioner/README.md) for the full argument list and security notes.

---

## Step 2 — Import the bundle on your first device

1. Open Lotti on the device you want to make the **first peer** (desktop is easiest for paste‑in).
2. Navigate to **Settings → Sync → Provisioned Sync**.
3. Paste the contents of `bundle.txt` into the import field and confirm.

The client will:

1. Decode the bundle and validate it (MXID, room ID, homeserver URL, schema version).
2. Log in as the new sync user.
3. Join the sync room.
4. **Rotate the password** immediately — the password from the original bundle is consumed and replaced with a new one that only this device knows.
5. Display a **handover bundle** (Base64 string and/or QR code) for use on your other devices.

> ![Placeholder: 2026-05-07 - Provisioned Sync import screen with bundle paste field - Linux desktop](path/to/lotti-assets/repo)
>
> ![Placeholder: 2026-05-07 - Handover code shown after successful first import — QR + Base64 string - Linux desktop](path/to/lotti-assets/repo)

> **Why password rotation matters.** The provisioning bundle exists in plaintext on the machine that ran the CLI and on the device that imports it. Rotation means that as soon as your first device finishes setting up, the original credential is dead — anyone who had a copy of `bundle.txt` can no longer log in. After this point, the only credential that works is the one your first device knows, plus the handover bundle it shows you.

---

## Step 3 — Add your other devices via handover

For each additional device — phone, tablet, laptop — repeat:

1. On the **first** device: open the handover bundle (the QR / Base64 from step 2).
2. On the **new** device: open Lotti → **Settings → Sync → Provisioned Sync** → paste the handover bundle (or scan the QR).
3. The new device logs in, joins the same sync room, and starts catching up.

Handover bundles are different from the original provisioning bundle: they carry the **rotated** password and don't trigger another rotation. Every peer joined this way shares the same live credential.

> ![Placeholder: 2026-05-07 - Scanning the handover QR code on a phone - Android](path/to/lotti-assets/repo)
>
> ![Placeholder: 2026-05-07 - Sync status showing both devices online with recent activity - Linux desktop](path/to/lotti-assets/repo)

### What syncs

Both databases sync end‑to‑end encrypted:

- **User database** — tasks, journal entries, audio recordings, transcripts, time entries, habits, measurables, dashboards.
- **Agentic database** — agent definitions, soul/mission/report directive, wake history, memories, pending suggestions, evolving personalities.

This means the relationship you've built up with an agent on your laptop follows you to your phone. The phone doesn't have to re‑learn anything.

---

## Step 4 — Verifying things are healthy

After a few minutes:

- Open **Settings → Sync → Sync Stats** on both devices. Counters should be advancing.
- Open **Settings → Sync → Maintenance** if you suspect drift; this surface includes diagnostic tools, sequence‑log inspection, and re‑sync controls if you ever need them.
- Create a tiny test entry on one device (a journal note or a one‑checkbox task) and watch it appear on the other.

If something looks stuck, [`lib/features/sync/README.md`](../../lib/features/sync/README.md) has the deeper architecture description (queue, outbox, sequence log, backfill) that the diagnostic UIs are surfacing.

---

## A note for weekend Android testers

If you're trying Lotti on Android specifically to help test sync, the smoothest path is:

1. Use a friendly homeserver admin (or self‑host briefly on a VPS).
2. Run the provisioner once.
3. Import on desktop first; then scan the handover into the Android build.

Bug reports on this flow are particularly welcome — open an issue with the steps you took and the device pair you used.
