---
name: Lotti
description: A private logbook for the work you actually did — quiet neutral pages, colour only where it means something.
colors:
  interactive-light: "#1F7963"
  interactive-dark: "#5ED4B7"
  interactive-hover-light: "#165042"
  interactive-hover-dark: "#86DFC9"
  interactive-pressed-light: "#103A30"
  interactive-pressed-dark: "#AFEAD8"
  ai-accent-light: "#5A4BD1"
  ai-accent-dark: "#A99BFF"
  ai-card-light: "#ECE9FB"
  ai-card-dark: "#15132A"
  background-01-light: "#FFFFFF"
  background-01-dark: "#181818"
  background-02-light: "#F1F4F3"
  background-02-dark: "#222222"
  background-03-light: "#E3E8E7"
  background-03-dark: "#535353"
  background-alternative-light: "#EEF7FF"
  background-alternative-dark: "#122029"
  text-high-light: "#000000E0"
  text-high-dark: "#FFFFFF"
  text-medium-light: "#000000A3"
  text-medium-dark: "#FFFFFFCC"
  text-low-light: "#00000094"
  text-low-dark: "#FFFFFFA3"
  on-interactive-light: "#FFFFFF"
  on-interactive-dark: "#0D0D0D"
  decorative-01-light: "#0000001F"
  decorative-01-dark: "#FFFFFF1F"
  decorative-02-light: "#0000003D"
  decorative-02-dark: "#FFFFFF3D"
  error-light: "#CC3633"
  error-dark: "#D65E5C"
  success-light: "#478556"
  success-dark: "#7AB889"
  warning-light: "#C87005"
  warning-dark: "#FBA336"
  info-light: "#1783B5"
  info-dark: "#4AB6E8"
typography:
  display:
    fontFamily: "Inter"
    fontSize: "62px"
    fontWeight: 700
    lineHeight: "72px"
    letterSpacing: "-1px"
  headline:
    fontFamily: "Inter"
    fontSize: "35px"
    fontWeight: 700
    lineHeight: "44px"
    letterSpacing: "-0.25px"
  heading-2:
    fontFamily: "Inter"
    fontSize: "25px"
    fontWeight: 700
    lineHeight: "32px"
    letterSpacing: "0px"
  title:
    fontFamily: "Inter"
    fontSize: "20px"
    fontWeight: 700
    lineHeight: "28px"
    letterSpacing: "0.25px"
  subtitle-1:
    fontFamily: "Inter"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: "24px"
    letterSpacing: "0.5px"
  subtitle-2:
    fontFamily: "Inter"
    fontSize: "14px"
    fontWeight: 600
    lineHeight: "20px"
    letterSpacing: "0.25px"
  body:
    fontFamily: "Inter"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: "24px"
    letterSpacing: "0px"
  body-small:
    fontFamily: "Inter"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: "20px"
    letterSpacing: "0px"
  label:
    fontFamily: "Inter"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: "16px"
    letterSpacing: "0.25px"
rounded:
  xs: "4px"
  s: "8px"
  m: "12px"
  l: "16px"
  xl: "24px"
spacing:
  step1: "2px"
  step2: "4px"
  step3: "8px"
  step4: "12px"
  step5: "16px"
  step6: "24px"
  step7: "32px"
  step8: "40px"
  step9: "48px"
  step10: "64px"
  step11: "80px"
  step12: "96px"
  step13: "160px"
components:
  button-primary:
    backgroundColor: "{colors.interactive-dark}"
    textColor: "{colors.on-interactive-dark}"
    typography: "{typography.subtitle-2}"
    rounded: "{rounded.xl}"
    padding: "12px"
  button-primary-hover:
    backgroundColor: "{colors.interactive-hover-dark}"
  button-primary-pressed:
    backgroundColor: "{colors.interactive-pressed-dark}"
  button-dense:
    textColor: "{colors.interactive-dark}"
    typography: "{typography.label}"
    rounded: "{rounded.s}"
    padding: "4px"
  card:
    backgroundColor: "{colors.background-02-dark}"
    rounded: "{rounded.l}"
    padding: "16px"
  ai-card:
    backgroundColor: "{colors.ai-card-dark}"
    textColor: "{colors.text-high-dark}"
    rounded: "{rounded.l}"
    padding: "16px"
  pill:
    textColor: "{colors.text-high-dark}"
    typography: "{typography.body-small}"
    rounded: "{rounded.xl}"
    padding: "4px 12px"
  tag:
    textColor: "{colors.text-high-dark}"
    typography: "{typography.body-small}"
    rounded: "{rounded.xs}"
    padding: "4px 8px"
  text-input:
    backgroundColor: "{colors.background-02-dark}"
    textColor: "{colors.text-high-dark}"
    typography: "{typography.body}"
    rounded: "{rounded.l}"
    padding: "12px 16px"
---

# Design System: Lotti

## Overview

**Creative North Star: "The Honest Logbook"**

Lotti looks like a working record, not a showroom. Pages are quiet neutral
greys, and facts are set plainly, the way entries in a well-kept ledger are.
Colour is a signal rather than decoration: teal means *you can act here*,
violet means *an agent is speaking*, and the four alert hues mean exactly
what they say. Everything else stays in the ink ramp of the neutral greys. The one
indulgence is imagery. A task's or entry's cover art can be lush and
full-bleed, because it is the user's own picture of the work, and the chrome
around it stays out of its way.

The system is dark-first and equally finished in light. Density is that of a
tool people keep open all day: compact rows, clear type steps, and
generous reading measures for prose. Its ambition shows as precision and
restraint, in the gap between a fact and a choice, the exact type tier of a
caption button, and a footer that measures its translated labels before
deciding whether they fit on one line.

It rejects two looks by name. One is the **generic SaaS dashboard**: gradient
hero cards, KPI tiles as wallpaper, purple-blue gradients. The other is the
**Material default look**: stock Material 3 components and tonal palettes
showing through unstyled.

The source of truth is Figma → `assets/design_system/tokens.json` →
generated Dart (`tokens.colors.background.level02` and so on). This file
mirrors those tokens. If they disagree, the token export wins and this file is
the defect.

**Key Characteristics:**
- Neutral canvas, with meaning-bearing colour only: teal for action, violet for agent voice, alert hues for state.
- One typeface (Inter) and a strict tiered scale, always in sentence case.
- Depth comes from tonal layers, and frosted glass is used only for floating chrome.
- Fully rounded pills mean a choice or an action. Near-square tags mean a fact.
- Cover art is the only rich imagery, and everything around it stays quiet.
- Light and dark are both first-class, and every colour token is paired.

## Colors

Two meaning-bearing hues on a neutral, paired light/dark ramp.

### Primary
- **Logbook Teal** (`interactive-light` / `interactive-dark`): the one interactive accent. It is used for primary buttons (Track time), the focused input border, selected and active surface tints (at 16% and 24%), toggles, links and "Update now"-style text actions. Hover darkens it in light mode and lightens it in dark mode, and press goes one step further.

### Secondary
- **Agent Violet** (`ai-accent-*`, with the `ai-card-*` fill): the voice of an agent. It appears only on surfaces an agent authored or owns, such as AI summary cards, proposal rows, agent internals and companion surfaces. The `aiCard` token family (raised background, rows, borders, soft accent, wash) stays in its own namespace and is never borrowed elsewhere.

### Tertiary
- **Alert hues**: Ember Red (`error-*`), Field Green (`success-*`), Amber (`warning-*`) and Harbour Blue (`info-*`). Each has default, hover, pressed, an `ink` step for text on tinted fills, and `glyphOnLevel03` for glyphs on the darkest neutral. They always describe a state and are never decoration.
- **Proposal kinds** (`proposalKind.*`: add, update, remove, priority, estimate, status, label, due): a pastel glyph colour plus an 18% wash. They colour-code what an agent proposes to change, and appear only inside proposal UI.

### Neutral
- **Canvas levels** (`background-01/02/03`): 01 is the base, 02 is one tonal step, and 03 is the deepest fill and the track behind progress. In dark mode the steps get lighter (#181818 → #222222 → #535353). In light mode, 02 and 03 get *darker* than white 01. `dsPageSurface` / `dsCardSurface` swap them by brightness so cards always sit lighter than the page.
- **Cool Paper** (`background-alternative-*`): a faint blue page variant for distinguished regions.
- **Ink ramp** (`text-high/medium/low`): the only way type fades. Each step already carries its alpha, so never fade text again on top of it.
- **Hairlines** (`decorative-01/02`, plus `03` at 38%): dividers, idle outlines and dashed empty-slot borders.
- **State overlays** (`surface.enabled/hover/focus-pressed`): black or white at 6%, 12% and 16%, used as the hover and press fill on neutral controls.

### Named Rules
**The Two Voices Rule.** Teal is the user's hand and violet is the agent's voice. A teal control on an agent card is the user's decision (confirm). A violet glyph outside agent-owned UI is a bug.

**The Meaning-Only Rule.** Every non-neutral pixel must answer "what does this colour tell me?" If the answer is "it looks nice", use the neutral ramp.

## Typography

**Display Font:** Inter
**Body Font:** Inter

**Character:** one neutral grotesque carries every tier. Hierarchy comes from real size and weight steps, never from a second family, all-caps or tracking tricks.

### Hierarchy
- **Display** (700, 62/72, −1): rare hero numbers and celebration moments. The larger Display 0/1/3 steps exist in the export for the same narrow use.
- **Headline / Heading 1** (700, 35/44): the page title of a detail page (a task's title).
- **Heading 2** (700, 25/32): section heads within a page.
- **Title / Heading 3** (700, 20/28): card titles and sheet titles.
- **Subtitle 1** (600, 16/24) and **Subtitle 2** (600, 14/20): row titles, labels on medium and large buttons, and section labels in lists.
- **Body** (400, 16/24): running prose, notes and agent report text, set at a ~70-character measure (`kProseMeasureWidth` 600px). **Body Large** (18/24) is for spacious reading and **Body Small** (14/20) for dense rows and metadata.
- **Label / Caption** (400, 12/16, +0.25): meta lines, timestamps, and the `dense` button tier. **Overline** (700, 12/16, +0.96) exists in the export but is set in sentence case like everything else.

### Named Rules
**The Sentence Case Rule.** No uppercase labels, ever. No `toUpperCase`, no all-caps ARB values, and no small-caps headers, including on Overline.

**The Tabular Live Value Rule.** Any label whose digits change while visible (timers, countdowns) uses tabular figures, so the layout never jitters.

## Layout

The shell is a persistent left sidebar from 960px up (`kDesktopBreakpoint`) and a bottom navigation bar below that. On desktop, a list pane sits beside a detail pane, joined by a draggable `ResizableDivider`. A docked day-view column appears only from 1200px. Detail content caps at 960px (`kDetailContentMaxWidth`), prose inside it at 600px, worded action lists at 520px, and the goals surfaces at 760px. Page headers fold their tools beneath the title below 520px. Agent conversations slide in as a 400px overlay sheet, never as a column the page reflows around. A task's cover art is 16:9 of its column but never taller than 320px (`kTaskCoverMaxHeight`). Above that it becomes a banner, so the title, metadata and agent summary sit on the first screen of a laptop window.

Spacing uses the 13-step gap scale (2 → 160px). The common rhythm is `cardPadding` 16 (step5), `cardItemSpacing` 12 (step4) and `sectionGap` 24 (step6). Control, icon and stroke sizes come from the separate sizing set (`ControlSizes`, `TapTargets`, `IconSizes`, `BorderWidths`), never from the gap scale. Above a 1.3 text scale, components re-flow (an avatar steps aside, an action bar stacks) rather than clip. Footers that hold translated actions measure their real content instead of trusting a width breakpoint.

### Named Rules
**The Measured Fit Rule.** Whether something fits is decided by measuring rendered content, never by a width threshold. German and Romanian labels are the test.

## Elevation & Depth

Depth is tonal by default. Cards sit one background level lighter than the page in both themes, and that step is the whole elevation language for content. Frosted glass (a 20σ backdrop blur under a 72–94% scrim) is reserved for **floating chrome over scrolling content**: the bottom task action bar, top bars and icon containers over a cover photo, and the modal surfaces that host glass footers. Shadows exist in a few places but are rare and never decorative. A new surface earns depth by tone first, and adds glass only when content genuinely scrolls beneath it.

### Named Rules
**The Tone-Before-Shadow Rule.** Before reaching for a shadow, step the background level. Before reaching for blur, check whether anything actually scrolls underneath.

**The Calm Refresh Rule.** Depth never flickers. Background sync and database refreshes keep the last rendered surface, and full loading shells are only for initial loads and deliberate navigation.

## Shapes

Corners follow a five-step scale (4 / 8 / 12 / 16 / 24). Section cards, inputs and picker fields use `l` (16). Buttons from `medium` up, pills and badges use `xl` (24), which makes them fully rounded at their height. The `small` button uses `l`, the `dense` button and small chips use `s` (8), and informational tags use `xs` (4). Corner radius carries grammar:

- **Pill (fully rounded):** something to choose or press, such as filters, levers, pickers and actions.
- **Tag (4px):** a fact, such as a status, a priority, a due date or a tracked duration. It can never be mistaken for a button.
- **Dashed outline:** an empty slot (a value not set yet), or a lane's single lever ("Details", "How did it feel?").

Circular icon buttons (back, overflow, mic) are 48dp targets. Rows inside a card are separated by hairline dividers, not by their own borders.

## Components

### Buttons
- **Character:** confident and few. One primary per surface, everything else recedes.
- **Variants:** `primary` (teal fill), `secondary`, `tertiary`, `quiet`, `outlined`, `constructiveOutlined`, and the `danger` family. There are five sizes: `dense` (caption type, `s` radius, for actions inside metadata rows), then `small`, `medium`, `large` and `jumbo` (Subtitle 2 or Subtitle 1 labels, fully rounded).
- **States:** hover and keyboard focus share one fill, and pressed steps further. Fill-less variants (tertiary, the outlined family) set inside prose can use `suppressHoverFill`, which lets the ink carry the state so no phantom pill appears mid-paragraph. A `null` handler in a footer disables the button rather than hiding it.
- **Edges:** `alignsLabelToLeadingEdge` / `alignsLabelToTrailingEdge` put the *label*, not the box, on a column edge.

### Chips and Pills
- **`DesignSystemChip`** is the one interactive filter. `selected` owns both the teal-tinted activated surface and the selected semantics, and feature code never repaints a selected chip. A count travels in the chip's trailing slot as a `DsPill`.
- **`DsPill`** comes in two shapes. `pill` is interactive. `tag` is informational and comes in three styles: `filled` and bordered for a set fact, `tinted` (in its own state colour, always with a glyph) for a state such as "5 days overdue", and `muted` (dashed) for an empty slot.

### Cards / Containers
- **Corner Style:** gently curved (16px).
- **Background:** one tonal step above the page (`dsCardSurface`). There is no border, and rows inside are split by `DesignSystemDivider`.
- **Internal Padding:** 16 (`cardPadding`), with a 12 gap between items.

### Inputs / Fields
- **Style:** a filled neutral field with a 16px radius, Body type, and a placeholder in low-emphasis ink.
- **Focus:** the border turns teal (`interactive.enabled`). Hover gets medium ink, and error uses the error hue. One function decides the border colour, so focus can never look two ways.
- **Chat input:** `DesignSystemChatInput` is the single field for typing *and* talking. While recording, it shows the take as a full-width row of thin live bars (`DesignSystemVoiceWaveform`).

### Navigation
- **Desktop:** a persistent left sidebar from 960px, with the list and detail panes side by side and a resizable divider.
- **Mobile:** a bottom navigation bar, a floating glass action bar on detail pages, and circular glass back and overflow buttons over cover art.

### Task Row (reference)
Three tiers, so one thing leads: the title (Subtitle 1, 600), the agent one-liner on one line in Agent Violet (caption), then one caption-tier meta line in medium ink (status glyph and word, priority glyph and word, dates, the category as a colour swatch and name, tracked time once there is any). There are no filled colour blocks and no "0h 0m". A cover thumbnail (64, `ControlSizes.mediaThumbnail`) leads the row and steps aside on large text. The row is one button to assistive tech.

**The One Vocabulary Rule.** A fact reads the same wherever it appears. Priority is its word (*High*) on the row, the header chip and the filter, and the P-code is only a sort key. Its mark is always `DesignSystemPriorityGlyph`: a badge for Urgent and one to three bars below it, coloured only for Urgent and High. A due date within a day of today reads as the list's own section words (*Due Today*) in the header too.

### Task Metadata Lane
Status, priority, due date, estimate and labels are read-out tags (4px), followed by a dashed *Details* lever. Below 520 wide, the lane is two lines rather than one wrapped lane: the decision facts (status, blocked-by, priority, due) come first, then the rest, with several labels shown as their count.

### People Row
The task row's two tiers with the persona avatar leading (40, centred on the text). The name in Subtitle 1 has its line to itself and wraps to two lines rather than truncating. Under it, one caption line in medium ink: the person's state, when the band heading has not already said it, then the last contact (*Call · Sat 1 Aug 12:44 · Weekly*). Overdue is the warning glyph and *5 days overdue* in `alert.warning.ink`; *Due Wed*, *Dormant* and *Archived* are plain words. The state never rides the name's line as a tag. The two parts wrap rather than clip when they do not share a line, and at large text the status line takes a second line. Each band (*Due*, *On track*, *No reminders*) is one rows card (`background.level02`, `radii.l`, a divider between rows, no border) drawn row by row so the list stays lazy, under its heading in the calm eyebrow style. The row is a `GroupedCardRowSurface`, one button to assistive tech whose label is the name, the state and the status line in one sentence. A full-width search field sits under the page title with nothing beside it; while it holds a query the summary card steps aside.

### States (reference)
**The Honest State Rule.** An empty, failed or missing surface says which it is and offers the way out. A list empty because of a search offers *Clear search*, one empty because of filters offers *Clear filters*, and a genuinely empty one says so. A failed load names the failure and offers *Try again*. A missing record says it no longer exists. Loading is the design-system spinner. No surface vanishes silently or waits behind a blank shell once its load has finished.

### Goal Row
The People row's two tiers with the goal's face leading (its persona monogram, or the companion's bust, on the status wash). The title in Subtitle 1 has its line to itself. Under it, one caption line: the status as a glyph and a word, then the trend and a pending proposal. *Behind* is the warning glyph and its words in `alert.warning.ink`, semibold, with the recovery hint folded in (*Behind · 1 day to recover*); *At risk* is the clock in the warning ink, *On track* the circled check in the success hue, *No data* the word alone in low ink. The status is never a filled block and never on the title's line. The templated summary follows in Body Small, and the 7-day strip sits beside the words when the row is wide, under them when it is narrow or the text is large. The goals are one rows card on `dsCardSurface` (the Goals page is on `dsPageSurface`), and each row is a `GroupedCardRowSurface` whose label is the title, the status and the summary in one sentence. The same status mark heads a goal's page, its chat and the day's briefing.

### AI Summary Card (signature)
The agent's voice made visible. It is a violet-washed card (`aiCard.*`) with a sparkle tile, a title and the agent's name, report prose in body type, then a quiet footer: freshness ("4 min ago") and a teal "Update now". **Proposed changes** sit inside it as white or raised rows, each with a dismiss (neutral circle ×) and a confirm (violet-tinted circle ✓), plus a pending count tag and an outlined "Confirm all". Resolved proposals hold for 200ms, then collapse (250ms, emphasised decelerate). Structured agent output renders as A2UI components here, not as Markdown.

### Glass Action Bar (signature)
The floating chrome at the bottom of a detail page. It is a frosted strip (blur 20, under a gradient scrim) that content scrolls beneath. It holds the primary pill (Track time) and circular icon actions (mic, checklist, image, Add ▾). While an AI job runs, an animated band rides above it, carrying a small capsule that names the job in agent violet (*Transcribing audio*) and opens its progress. It reserves 88px of scroll clearance so the last row stays reachable.

### Motion
Motion is short and functional: 100–500ms, standard curve `cubic(0.2, 0, 0, 1)`, and emphasised decelerate for things settling. Proposal rows stagger by 55ms. Tickers animate only while on screen (`OnScreenTickerMode`).

## Do's and Don'ts

**The Search Row Rule.** A search field keeps its row to itself: no control in or beside it takes its width. A list's filter entry is a *Filters* chip leading the chip lane beneath the field, selected while filters narrow the list.

### Do:
- **Do** read every visual value from the tokens: `tokens.spacing.stepN`, `tokens.typography.styles.*`, `tokens.colors.*` and `tokens.radii.*`. `make token_check` ratchets raw values down per file.
- **Do** keep teal for the user's actions and violet for agent-authored surfaces (The Two Voices Rule).
- **Do** use a 4px tag for a fact and a full pill for a choice, and a dashed outline for a slot not yet filled.
- **Do** put cards one tonal step lighter than the page, via `dsPageSurface` / `dsCardSurface`.
- **Do** cap prose at ~600px and detail pages at 960px. Measure translated footers instead of trusting breakpoints.
- **Do** design every surface in both light and dark before calling it done.

### Don't:
- **Don't** let it read like a generic SaaS dashboard: no gradient hero cards, no KPI-tile wallpaper, no purple-blue gradients.
- **Don't** let stock Material 3 components or tonal palettes show through. Use the `DesignSystem*` / `Ds*` component instead.
- **Don't** uppercase any label, including Overline.
- **Don't** fade text with extra alpha. Pick the high, medium or low ink step.
- **Don't** borrow `spacing.stepN` for icon, control or stroke sizes.
- **Don't** flash a loading or empty shell when sync or the database refreshes underneath an established surface.
- **Don't** add a shadow or a blur where a tonal step does the job.
