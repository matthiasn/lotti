# Task agents and AI summaries

Task agents watch one task, produce an AI summary, and suggest changes that you
can accept or dismiss. They do not need to run after every edit. Automatic
updates are off by default, so a new agent keeps observing its task without
spending inference tokens until you choose to wake it.

## Before you start

The task needs an agent and an AI setup. The **Current setup** row identifies
the model and provider used for the next wake. Choose that row to change the
profile or model, or to turn AI off for this agent.

The report itself can retain historical attribution when its model route differs
from the current setup. This makes a model change explicit instead of silently
relabelling an older report.

## Read the card

On a phone, the card follows one vertical reading order:

1. agent identity and optional read-aloud control
2. automatic-update and wake controls
3. current AI setup
4. summary and its **Read more** disclosure
5. proposed changes and history

On desktop, the report and proposals form the reading column while automation
and setup stay in a compact control rail. **Read more** sits after the summary
it expands, so the control and its content stay together.

![Task-agent card on desktop](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_agents/0.9.1048/desktop_scheduled_dark.png)

## Choose when the agent wakes

**Automatic updates** are opt-in.

- **Off (default):** task changes do not run inference. The agent still listens
  and marks the visible report as out of date.
- **On:** a relevant task change starts the existing two-minute countdown.
  Changes during that window are bundled into one wake.
- **Wake agent:** runs a user-requested refresh immediately in either mode.
- **× beside a countdown:** cancels that scheduled automatic wake without
  disabling the toggle.

![Automatic updates enabled with a countdown](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_agents/0.9.1048/pro_scheduled_light.png)

Leaving automatic updates off is useful for active tasks that change often.
You keep freshness awareness without repeatedly sending nearly identical
context to a local or remote model.

## Refresh an outdated report

When a relevant edit arrives while automation is off, the existing summary
stays visible and receives a focused **This summary is out of date** notice.
No inference runs in the background. Choose **Wake agent** when the task is
ready for a new pass.

![Outdated task-agent summary with Wake agent CTA](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_agents/0.9.1048/pro_manual_dark.png)

The freshness check is conservative: if another task edit arrives after a wake
starts, that newer edit keeps the report stale even when the older wake finishes.
Wake it again after the changes settle to include the newest state.

![Outdated summary and controls on desktop](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/task_agents/0.9.1048/desktop_manual_light.png)

## Review proposed changes

The summary is informational. Proposed task mutations appear separately under
**Proposed changes** and still require your review. Expand **History** to inspect
earlier accepted and dismissed proposals. Open **Read more**, then **Open agent
internals**, when you need the full report or runtime detail.

## Try a deliberately weird task

For a memorable freshness check, create a task such as **Prepare the
zero-gravity fish feeder for the penguin migration window** and attach a task
agent. Keep automatic updates off, wake it once, then add checklist items for
**hedge sardine futures** and **inspect the ventilation-duct penguin**. The old
summary should remain readable, the card should mark it outdated, and only your
next **Wake agent** should spend inference on the new situation.

Your penguin situation may vary.
