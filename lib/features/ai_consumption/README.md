# AI consumption

AI consumption is the receipt for every piece of AI work Lotti does: who asked for
it, which model answered, what it used, and what it cost.

## What it does for the user

- **Shows what AI actually costs.** Per task, per area and per model — tokens,
  money where the provider reports it, and estimated energy and CO₂e.
- **Attributes work honestly.** A summary, a transcript or a generated image
  carries a record of the calls that produced it, so a cost can always be traced
  to an output.
- **Never invents numbers.** Where a provider reports no cost, none is shown —
  nothing is estimated into existence.
- **Adds up across devices.** Usage recorded on a laptop and a phone converges
  into one picture.

## What it owns

The consumption event and attribution model; the ledger database; the services
that open, record into and finalize an attribution; and the sync of consumption
events.

The features that *produce* AI work — [ai](../ai/README.md) and
[agents](../agents/README.md) — call into this feature rather than the reverse.

## Where the code lives

```text
lib/features/ai_consumption/
├── database/       # ai_consumption.sqlite
├── repository/ · service/ · sync/
└── ui/
```

## How it works

The deliberately small model — one attribution per output, one event per call,
linked by one id — and why the carrier is authoritative, are documented in the
knowledge bundle:

**→ [knowledge/features/ai_consumption.md](../../../knowledge/features/ai_consumption.md)**
