# Long-Horizon LLM Day-Planner vs. the State of the Art

- **Date:** 2026-06-08
- **Subject:** The Daily OS long-lived planning agent ([ADR 0022](../adr/0022-long-lived-daily-os-planner.md), with memory mechanics from [ADR 0017](../adr/0017-deterministic-log-compaction.md) and convergence from [ADR 0018](../adr/0018-convergent-multi-device-execution.md))
- **Method:** Multi-agent deep-research sweep — 6 search angles, 24 sources fetched, 117 candidate claims extracted, 25 adversarially verified (3-vote, kill on 2/3 refute), 23 confirmed / 2 refuted, synthesized to 10 findings.
- **Question:** How does our agent↔LLM interaction design for a long-horizon (day-planner) setting compare to academic and production best practice — where does it align, lead, or diverge, and what should we consider changing?

> Scope note: this is a *comparison and critique*, not a design doc. "Our design" below is the eight-point characterization fed to the research; every "vs. literature" mapping is an analyst judgement the verifiers found defensible (the cited sources predate our system and do not know it).

---

## 1. Executive verdict

Measured against the academic and production state of the art, the planner is a **coherent, well-grounded instance of the dominant production memory pattern** — "working context + external store" (the agent-memory survey's *Pattern B*). Several of its less common choices are *explicitly endorsed* by current best-practice sources.

- **Conventional / aligned** on: memory substrate (immutable log), two-tier retrieval, summary-checkpoint compaction, staleness handling, and prefix-cache discipline.
- **Ahead of common practice** on: (1) deterministic, hysteresis-watermark, *engine-driven* compaction chosen for byte-stable prefixes, and (2) a CRDT / vector-clock *multi-device convergent* memory substrate — something the agent-memory canon barely addresses.
- **Deliberately divergent (with real risk)** on: it favors determinism + cacheability over the adaptive, self-reorganizing memory networks the academic frontier (A-MEM) argues are better for adaptability; and its summarize-and-fold loop inherits the well-documented **summarization-drift** failure mode, only partially mitigated.

One-line: *conventional-to-ahead on substrate, retrieval, compaction, and caching; ahead on determinism-for-cacheability and multi-device convergence; most exposed on information-loss and staleness — the failure modes inherent to any summarize-and-compact long-horizon agent.*

---

## 2. Annotated bibliography (what each key source says)

### Academic — memory architectures & cognitive frameworks

**Park et al. 2023 — "Generative Agents: Interactive Simulacra of Human Behavior"** ([arXiv:2304.03442](https://arxiv.org/pdf/2304.03442); [ACM](https://dl.acm.org/doi/fullHtml/10.1145/3586183.3606763))
Defines the **memory stream**: "a comprehensive record of the agent's experience… a list of memory objects, where each object contains a natural language description, a creation timestamp, and a most recent access timestamp," whose most basic element is an *observation*. Memory is served by **retrieval**, scored as `recency·importance·relevance` (exponential recency decay 0.995; importance an LLM 1–10 score; relevance via embedding cosine). **Reflection** synthesizes higher-level thoughts when the summed importance of recent events crosses a threshold (~150, i.e. a few times a day) and is *additive* — reflections coexist with raw observations, never replacing them. *Relevance to us:* this is the canonical episodic substrate; the key contrast is that they **retrieve** from the full stream while we **fold** it by compaction.

**Sumers et al. 2023 — "CoALA: Cognitive Architectures for Language Agents"** ([arXiv:2309.02427](https://arxiv.org/html/2309.02427v3))
The reference vocabulary for agent design. "Language models are stateless: they do not persist information across calls"; language agents therefore need persistent memory, and "working memory… persists across LLM calls." Organizes agents along **information storage** (working + long-term, the latter split into *episodic / semantic / procedural*), **action space** (internal vs external), and **decision loop**; retrieval is a first-class *internal* action (LTM→WM) and writing observations is a *learning* action. *Relevance:* our log = episodic, durable-knowledge tier = semantic, scoped hook-index pull = retrieval action — a textbook fit. (Caveat: a framework paper — it *characterizes*, doesn't empirically *validate*.)

**Packer et al. 2023 — "MemGPT: Towards LLMs as Operating Systems"** ([arXiv:2310.08560](https://arxiv.org/pdf/2310.08560))
**Virtual context management** "drawing inspiration from hierarchical memory systems in traditional operating systems which provide the illusion of an extended virtual memory via paging between physical memory and disk." Separates **main context** (RAM/prompt) from **external context** (disk/archival), demoting evicted detail via recursive summary; demonstrated on document analysis beyond the window and multi-session chat. *Relevance:* the canonical tiered-memory precedent for our fold + two-tier store. **Key difference:** MemGPT's tier movement is **LLM/agent-controlled** via function calls; ours is **deterministic / engine-driven**.

**Xu et al. 2025 — "A-MEM: Agentic Memory for LLM Agents"** ([arXiv:2502.12110](https://arxiv.org/abs/2502.12110), NeurIPS 2025)
The adaptivity frontier. Three **agent-driven** processes: note construction (structured attributes/keywords/tags), **dynamic link generation** to historical memories (Zettelkasten-style), and **memory evolution** — "as new memories are integrated, they can trigger updates to the contextual representations and attributes of existing historical memories." Central thesis: "fixed operations and structures limit their adaptability across diverse tasks," resolved by "interconnected knowledge networks through dynamic indexing and linking." *Relevance:* definitionally **not** append-only (it mutates old notes) and **not** fixed-format — the opposite axis from ours. This is the design's clearest "where the field is going that we deliberately are not."

### Academic — surveys & taxonomy

**Wu et al. 2025 — "From Human Memory to AI Memory" (Huawei Noah's Ark)** ([arXiv:2504.15965](https://arxiv.org/pdf/2504.15965))
A memory taxonomy. Places **KV Cache** and **Prompt Cache** in *Quadrant VII* (System / Parametric / Short-Term — "KV Management & Reuse"), distinct from non-parametric long-term summarization memory (Quadrant II). States "Major platforms such as DeepSeek, Anthropic, OpenAI, and Google employ prompt caching to reduce API-call costs and improve response speed." Frames long-term personal memory as a four-stage pipeline: **construction → management → retrieval → usage** (construction = consolidation into summaries; management = dedup/merge/conflict-resolution). *Relevance:* validates treating KV/prefix reuse as a *recognized memory mechanism*, and our fold as the textbook construction+management step. Our split — folded dayLog (non-parametric) vs KV-prefix reuse (parametric) — maps to two distinct quadrants.

**Du et al. 2026 — agent-memory survey** ([arXiv:2603.07670](https://arxiv.org/html/2603.07670v1))
Names the production patterns: **Pattern A** (stuff-the-window), **Pattern B** "Context + retrieval store… the workhorse pattern behind most production agents today," **Pattern C** (learned-control tiered memory). Recommends *starting at B*, graduating to C only with empirical evidence. **§4.1 "summarization drift":** "Each compression pass silently discards low-frequency details. After enough passes, the agent remembers a sanitized, generic version of history"; the illustrative example is "a rare but critical instruction from day one… tends to vanish by the third pass." **§7.3 "Staleness, contradictions, and drift":** long-lived stores "accumulate outdated information without mechanisms to identify which records are current," and recommends temporal versioning (prioritize newer), source attribution, contradiction detection, and periodic consolidation to retire stale entries. *Relevance:* our two-tier store *is* Pattern B; §4.1 is our primary risk; §7.3's mitigations are exactly what recency-wins + terminal retraction implement.

### Production engineering

**Anthropic — "Effective context engineering for AI agents"** ([blog](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents))
The closest external match to our memory shape. **Just-in-time retrieval:** "agents… maintain lightweight identifiers (file paths, stored queries, web links, etc.) and use these references to dynamically load data into context at runtime"; the recommended best agents are a **hybrid** of up-front + just-in-time — i.e. our always-on hook index (lightweight identifiers) + scope-filtered statement pull (runtime load). **Compaction caveat:** "can result in the loss of subtle but critical context whose importance only becomes apparent later"; "Start by maximizing recall… then iterate to improve precision." **Technique-to-task map:** *compaction* for back-and-forth flow; *structured note-taking* (agentic memory persisted outside the window — Claude-plays-Pokémon maintaining tallies/maps across thousands of steps) for milestone work; *multi-agent* for parallel research. *Relevance:* validates two-tier retrieval as Anthropic's *recommended hybrid*, and frames compaction as a tunable recall/precision tradeoff, not a free operation.

**Anthropic — "Building effective agents"** ([blog](https://www.anthropic.com/research/building-effective-agents)) and **"Writing tools for agents"** ([blog](https://www.anthropic.com/engineering/writing-tools-for-agents))
General agent design patterns and tool-design guidance — backdrop for our forced-tool-choice / bounded-turns control loop.

**Prefix/KV-cache mechanics (provider docs + practitioner notes):** [Anthropic prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching), [vLLM automatic prefix caching](https://docs.vllm.ai/en/stable/design/prefix_caching/), [KV-cache prompt-engineering notes](https://ankitbko.github.io/blog/2025/08/prompt-engineering-kv-cache/). Establish the mechanics our design optimizes for **and the caveats**: short cache TTLs (Anthropic ~5 min default), breakpoint rules, and automatic eviction.

**Context-engineering field reports:** [Manus](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus) and [LangChain](https://www.langchain.com/blog/context-engineering-for-agents) — practitioner corroboration of stable-prefix construction and external-memory patterns. **Vendor landscape:** [agent-memory vendors 2026 (Letta/Zep/Mem0/LangMem)](https://agentmarketcap.ai/blog/2026/04/10/agent-memory-vendor-landscape-2026-letta-zep-mem0-langmem).

### Corroborating / supporting (not independently re-verified here)

- **Wang et al. 2023** ([arXiv:2308.15022](https://arxiv.org/pdf/2308.15022)) — recursive-summarization per-pass error rates ~2.7–3.9% (drift corroboration).
- **STALE benchmark** (arXiv:2605.06527) — best model only ~55.2% at recognizing invalidated memories; staleness recognition is empirically hard even *with* mechanisms.
- **CRDT foundations** — conflict-free replicated data types / vector-clock literature ([1011.5808](https://arxiv.org/pdf/1011.5808), [0907.0929](https://arxiv.org/pdf/0907.0929), [1210.3368](https://arxiv.org/pdf/1210.3368); [CRDT deletion/tombstone notes](https://lars.hupel.info/topics/crdt/07-deletion/)) — the theoretical basis our convergence layer applies.

---

## 3. Design-choice-by-design-choice comparison

| # | Our design choice | Closest established technique | Verdict |
|---|---|---|---|
| 1 | Durable long-lived planner identity; day = workspace | CoALA persistent working memory across calls | **Conventional / principled** |
| 2 | Append-only event log folded into summary checkpoints | Generative-Agents memory stream; MemGPT recursive summary; survey construction+management | **Conventional substrate; deterministic-fold is a deliberate divergence** |
| 3 | Hysteresis-watermark (trigger + retain) compaction | Generative-Agents importance-threshold reflection; MemGPT paging | **Ahead in mechanism (deterministic, two-watermark, engine-driven)** |
| 4 | Two-tier durable knowledge (always-on hook index + scoped pull) | Anthropic just-in-time + lightweight identifiers (hybrid); survey Pattern B | **Conventional best-practice — Anthropic's *recommended* shape** |
| 5 | Prefix/KV-cache as first-class (stable→volatile order, snapshot ts, lazy load) | Huawei survey "KV management & reuse"; provider prefix caching | **Aligned, arguably ahead in discipline** |
| 6 | OpenAI-compatible tools, forced `tool_choice`, bounded turns | Anthropic tool-design + bounded-agent guidance | **Conventional** |
| 7 | Event-driven wakes + scheduled pre-warms; throttle/single-flight; fast-forward dormant | CoALA decision loop; OS-style scheduling | **Conventional control loop** |
| 8 | Multi-device convergence (append-only log, vector clocks, LWW + tiebreak, G-counters, terminal retraction) | CRDT / vector-clock distributed-systems theory | **Ahead of the agent-memory canon (which ignores it)** |

### Detail per finding (with confidence)

- **#2 substrate — aligned, deliberate divergence (high).** Same immutable-stream substrate as Generative Agents and CoALA episodic memory, but they *retrieve* by similarity scoring whereas we *fold* by deterministic compaction. Retrieve-from-full-log is the canonical alternative we consciously don't take for the episodic stream — trading similarity recall for cacheability.
- **#4 two-tier retrieval — best-practice (high).** Maps almost exactly onto Anthropic's *recommended hybrid* (up-front lightweight index + just-in-time scoped load) and the survey's production-workhorse Pattern B. ADR 0022 already cites "Claude Code's memory-index pattern." Well-chosen, not novel.
- **#1/#7 cognitive grounding (high).** Clean fit to CoALA's three dimensions; principled rather than ad hoc. (CoALA characterizes, doesn't benchmark.)
- **#2 summarization drift — primary risk (high).** Summarize-and-discard inherits progressive fidelity loss; Anthropic independently warns of losing "subtle but critical context." We *partially* mitigate by retaining the immutable log and promoting durable facts to the compaction-exempt tier — but the agent's *prompt* still sees only summary+tail per wake, so drift can still shape in-context behavior between folds, and ADR 0017 itself flags that "recursive summarization can amplify hallucination at depth."
- **#4 staleness — aligned mitigation (high).** Long-lived stores accumulate stale/contradictory records; recency-wins Head selection + terminal retraction are exactly the recommended temporal-versioning + retirement mechanisms. Residual: staleness recognition is empirically ~55%-ceiling hard (STALE), so user-gating stays load-bearing.
- **#5 cacheability — aligned/ahead (high).** KV/prompt caching is a recognized memory mechanism and deployed by all major providers; elevating byte-stable-prefix discipline to a first-class invariant is ahead of typical agent design. **Caveat (time-sensitive):** provider caches have short TTLs / breakpoint rules — see §5.
- **#2 fold step — conventional, divergent mechanism (high).** Textbook construction+management / MemGPT OS-paging; the differentiator is deterministic engine-driven movement vs MemGPT's LLM-self-managed paging.
- **#2/#3/#4 vs A-MEM — genuine divergence (high).** A-MEM argues fixed/deterministic structures cap adaptability and that self-evolving linked note networks are superior. Ours is the opposite axis — but justified: A-MEM's LLM-driven historical-note *rewriting* would be a convergence nightmare under our multi-writer sync model. A tradeoff, not a defect; it does cap adaptivity.
- **#8 multi-device convergence — ahead, medium confidence.** Unaddressed in the agent-memory canon (all single-replica); we import mature CRDT/vector-clock practice (terminal retraction and G-counters are textbook monotonic constructions). **Medium** because no *agent-systems* source explicitly endorses CRDTs for agent state — it rests on general CRDT theory + ADR 0018. ADR 0018/0022 themselves flag the unresolved cost (global single-flight serialization; unbounded projection-fold input).
- **#2 fast/slow split — aligned/ahead (high).** Combining compaction (episodic fold) *and* structured note-taking persisted outside the window (durable knowledge) maps onto Anthropic's technique-to-task buckets. The slow, user-gated promotion gate ("nothing becomes durable except through the weekly gate or explicit confirmation") directly attacks drift by moving anything worth keeping *out* of the lossy stream — a thoughtful, less-common design.

---

## 4. Where we lead vs. diverge (synthesis)

**Lead.** Two things the literature rarely combines: (a) deterministic, two-watermark, engine-driven compaction *explicitly chosen for byte-stable prefixes and KV reuse* (vs MemGPT's self-managed paging or Generative-Agents single-threshold importance gating); and (b) a CRDT/vector-clock convergent multi-device substrate with type-specific monotonic merge — multi-device convergence of agent memory is essentially absent from the canon.

**Diverge (with risk).** We favor determinism + cacheability over the adaptive, self-reorganizing memory the frontier (A-MEM; partly MemGPT self-editing) argues is better for adaptability. That choice is justified by our deployment constraints (multi-writer sync + on-device KV cache), but it caps adaptivity and inherits **summarization drift**.

---

## 5. Failure modes & open risks

1. **Summarization drift** (the big one). Mitigated by keeping the immutable log + the compaction-exempt knowledge tier, but the *prompt* still only sees summary+tail, and the agent currently has **no tool to reach back into folded detail**.
2. **Cache cadence mismatch.** Provider prefix caches have short TTLs (~5 min Anthropic; OpenAI auto-eviction). Our wakes are event-driven *minutes-to-hours* apart, so the byte-stable-prefix investment may be **cold between wakes** (it still pays off for rapid intra-session capture→draft→refine bursts). This is an unmeasured, genuinely time-sensitive gap.
3. **Unbounded fold input over a multi-year lifetime.** ADR 0022 flags that compaction bounds the *rendered tail* but not the *query/fold input* over the planner's lifetime. (The lazy-capture-load change already bounds the per-wake DB read; the conceptual O(all-history) fold input still needs an incremental-fold / projection-snapshot answer, and its interaction with re-folding a synced log is unspecified.)
4. **Staleness recognition ceiling.** Even with recency + retraction, models are ~55% at recognizing invalidated memories (STALE) — user-gating remains essential.

---

## 6. Evidence-backed recommendations

1. **Add an expand/recall tool over the immutable log.** We already retain the full append-only log, so a grep/expand tool lets the agent pull folded-away detail on demand — the "just-in-time + keep the original" pattern (Anthropic). This is the single highest value-to-effort move against summarization drift.
2. **Instrument the real prefix/KV-cache hit rate per wake** (cache-read tokens / wake). Settles whether the cross-wake cacheability benefit is real at our wake cadence before we keep paying for byte-stable discipline; informs whether to add explicit cache breakpoints or accept cold cross-wake caches.
3. **Bound the fold *input*, not just the tail** — incremental fold or projection snapshot, with a defined interaction with re-folding a synced log.
4. **Consider A-MEM-style dynamic linking *only* for the durable-knowledge tier.** The episodic stream must stay deterministic (cache + CRDT), but the user-gated knowledge store could tolerate richer link-based organization at low cache cost.
5. **Run a fold-quality evaluation** (OOLONG / LongMemEval-style) to settle whether determinism actually costs recall — currently unknown either way (see §7).

---

## 7. Caveats & refuted claims (research honesty)

- **Two claims that would have supported us were refuted (0/3 survived):** (a) that LCM-style "keep every message verbatim, recover losslessly via grep" is an established *superior* counter-pattern; and (b) that engine-managed deterministic compaction (Volt+LCM) measurably *outperformed* a frontier agent on OOLONG (+4.5, widening at long context). So there is **no verified head-to-head benchmark** showing deterministic compaction beats LLM-managed *on quality* — our "determinism is a strength" rests on convergence/cacheability *requirements*, not a quality win.
- **#8's "lead" is medium confidence** — no agent-systems source endorses CRDTs for agent state specifically; it leans on general distributed-systems theory + our own ADR.
- **The "details vanish by the third pass" figure is illustrative**, not a controlled measurement. Provider TTLs/pricing and MemGPT's threshold percentages are cloud-tuned and time-sensitive.
- **Source recency:** the anchor sources (Generative Agents, CoALA, MemGPT, A-MEM, the Huawei survey, Anthropic blogs, provider docs) are well-established. Several corroborating arXiv IDs (the Du survey 2603.07670, STALE 2605.06527, SSGM 2603.11768) are recent/post-cutoff and were not independently re-fetched while writing this report — treat their specific numbers as research-reported rather than first-hand verified.

---

## 8. Full source list

Primary:
1. Park et al. 2023, Generative Agents — https://arxiv.org/pdf/2304.03442 · https://dl.acm.org/doi/fullHtml/10.1145/3586183.3606763
2. Sumers et al. 2023, CoALA — https://arxiv.org/html/2309.02427v3
3. Packer et al. 2023, MemGPT — https://arxiv.org/pdf/2310.08560
4. Xu et al. 2025, A-MEM (NeurIPS 2025) — https://arxiv.org/abs/2502.12110
5. Wu et al. 2025, From Human Memory to AI Memory — https://arxiv.org/pdf/2504.15965
6. Du et al. 2026, agent-memory survey — https://arxiv.org/html/2603.07670v1
7. Anthropic, Effective context engineering for AI agents — https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
8. Anthropic, Building effective agents — https://www.anthropic.com/research/building-effective-agents
9. Anthropic, Writing tools for agents — https://www.anthropic.com/engineering/writing-tools-for-agents

Caching mechanics:
10. Anthropic prompt caching — https://platform.claude.com/docs/en/build-with-claude/prompt-caching
11. vLLM automatic prefix caching — https://docs.vllm.ai/en/stable/design/prefix_caching/
12. KV-cache prompt engineering — https://ankitbko.github.io/blog/2025/08/prompt-engineering-kv-cache/

Field reports / landscape:
13. Manus, Context engineering lessons — https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus
14. LangChain, Context engineering for agents — https://www.langchain.com/blog/context-engineering-for-agents
15. Agent-memory vendor landscape 2026 — https://agentmarketcap.ai/blog/2026/04/10/agent-memory-vendor-landscape-2026-letta-zep-mem0-langmem

Corroborating (research-reported, not re-verified here):
16. Wang et al. 2023, recursive summarization error — https://arxiv.org/pdf/2308.15022
17. CRDT foundations — https://arxiv.org/pdf/1011.5808 · https://arxiv.org/pdf/0907.0929 · https://arxiv.org/pdf/1210.3368 · https://lars.hupel.info/topics/crdt/07-deletion/

---

*Generated from a deep-research workflow (6 angles · 24 sources · 25 adversarially-verified claims) and cross-referenced against the local ADRs 0017/0018/0022.*
