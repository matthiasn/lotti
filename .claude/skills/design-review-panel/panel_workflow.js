export const meta = {
  name: 'design-review-panel',
  description: 'Rate a UI surface with a design-expert panel and an optional user-persona panel, grounded in real screenshots; returns per-reviewer scores, averages, and a synthesized must-fix list',
  phases: [
    { title: 'Experts', detail: 'one agent per craft dimension scores the screenshots' },
    { title: 'Personas', detail: 'optional — cognitive-style users stress the surface' },
    { title: 'Synthesis', detail: 'merge into a verdict + ranked must-fix list' },
  ],
}

// ---------------------------------------------------------------------------
// args (all optional except `surface` + `screenshots`):
//   surface:    string  — what the reviewers are looking at + how to read it.
//   screenshots:string[] — absolute PNG paths every agent MUST Read.
//   files:      string[] — source files reviewers may Read for code-level claims.
//   ignore:     string[] — test-rig artifacts to NOT score (stand-in nav, tofu…).
//   grounding:  string   — extra grounding notes appended to the rules.
//   experts:    [{key,title,lens,files?}]  — overrides the default 6 lenses.
//   personas:   [{key,persona}]            — overrides the default 5 personas.
//   includePersonas: bool (default true)   — run the persona panel too.
//   target:     number (default 8)         — the avg bar both panels must clear.
//   round:      number|string              — label for this rating pass.
// ---------------------------------------------------------------------------
const A = args || {}
const SURFACE = A.surface || 'the UI surface under review'
const SHOTS = (A.screenshots || []).filter(Boolean)
const FILES = (A.files || []).filter(Boolean)
const IGNORE = (A.ignore || []).filter(Boolean)
const INCLUDE_PERSONAS = A.includePersonas !== false
const TARGET = typeof A.target === 'number' ? A.target : 8
const ROUND = A.round != null ? String(A.round) : 'baseline'

const DEFAULT_EXPERTS = [
  { key: 'hierarchy-ia', title: 'Visual Hierarchy & Information Architecture',
    lens: 'What reads as primary/secondary/tertiary? Is information scent strong — can a user predict what a tap does before tapping? Is the most important action the most prominent? Grouping, ordering, focal anchor.' },
  { key: 'design-system', title: 'Design-System Consistency',
    lens: 'Spacing rhythm, component reuse, token discipline. Does this feel like ONE system or bolted-together parts? Cite real token/spacing/type/color violations only after Reading the file (file:line).' },
  { key: 'color-contrast', title: 'Color, Contrast & Semantics',
    lens: 'Palette restraint, semantic color use, status conveyed by more than color alone, contrast legibility on the dark surface. Describe contrast qualitatively from the pixels — do not invent ratios.' },
  { key: 'typography', title: 'Typography',
    lens: 'Type ramp, weight contrast, measure/line-length, vertical rhythm, truncation risk. Do labels/subtitles/metadata sit at the right level?' },
  { key: 'spacing-density', title: 'Spacing, Density & Rhythm',
    lens: 'Padding, alignment, optical balance, breathing room vs wasted space, row heights, divider treatment. Is density right for the content?' },
  { key: 'interaction-flow', title: 'Interaction & Task-Flow UX',
    lens: 'Taps-to-goal for the common case, affordances, dead-ends, mode errors, and whether the "1-tap to the default/common case" promise holds. Map the real journey and find the friction.' },
]

const DEFAULT_PERSONAS = [
  { key: 'adhd', persona: 'Theo, 29, ADHD: short working memory, abandons cluttered screens, needs "what now" to be instant and the common path to be obvious.' },
  { key: 'power-user', persona: 'Sam, 35, staff engineer, keyboard-first, counts seconds, allergic to wasted space and extra steps. Judges efficiency and density.' },
  { key: 'low-vision', persona: 'Margit, 68, macular degeneration, large accessibility text, needs strong contrast and big tap targets, fears irreversible taps, misses things below the fold.' },
  { key: 'minimalist', persona: 'Jonas, 34, minimalist aesthete: wants calm, uniform, restrained surfaces; recoils at visual noise, badges, and competing accents.' },
  { key: 'novice', persona: 'Renate, 61, non-technical, second-language English, reads UI copy literally, wary of jargon and of taps whose outcome is unclear.' },
]

const EXPERTS = (A.experts && A.experts.length ? A.experts : DEFAULT_EXPERTS)
const PERSONAS = (A.personas && A.personas.length ? A.personas : DEFAULT_PERSONAS)

const GROUNDING = [
  'GROUNDING RULES (panels have hallucinated failures before — do not):',
  '- Use the Read tool on EACH screenshot path listed; base every visual claim on the actual rendered pixels (real fonts, icons, design-system tokens, dark theme).',
  '- Do NOT invent numeric measurements (px gaps, contrast ratios). If you cannot measure it, describe it qualitatively and tie it to something visible.',
  '- Every issue must carry concrete evidence: a named screenshot ("…_desktop: …") or a file:line. A code claim ("hardcodes spacing") requires Reading the file and citing the line.',
  '- Scoring is GRUMPY and calibrated: 10 = ship-grade, nothing to fix; 8 = good, only polish left; 6 = usable but rough; 4 = several real problems; <=3 = broken/confusing. Do not be generous.',
  IGNORE.length ? '- IGNORE these test-rig artifacts (do NOT score them): ' + IGNORE.join('; ') + '.' : '',
  A.grounding ? '- ' + A.grounding : '',
].filter(Boolean).join('\n')

const SHOT_BLOCK = 'SCREENSHOTS TO READ (all required):\n  - ' + SHOTS.join('\n  - ')
const FILE_BLOCK = FILES.length
  ? '\n\nSOURCE FILES you may Read for code-level claims:\n  - ' + FILES.join('\n  - ')
  : ''

const EXPERT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['expert', 'score', 'strengths', 'issues', 'topPriorities'],
  properties: {
    expert: { type: 'string' },
    score: { type: 'number', minimum: 1, maximum: 10 },
    strengths: { type: 'array', items: { type: 'string' } },
    issues: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['severity', 'title', 'evidence', 'recommendation'],
        properties: {
          severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low'] },
          title: { type: 'string' },
          evidence: { type: 'string' },
          recommendation: { type: 'string' },
        },
      },
    },
    topPriorities: { type: 'array', items: { type: 'string' } },
  },
}

const PERSONA_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['persona', 'verdict', 'score', 'blockers', 'frictions', 'delights'],
  properties: {
    persona: { type: 'string' },
    verdict: { type: 'string', enum: ['would-use', 'would-struggle', 'would-abandon'] },
    score: { type: 'number', minimum: 1, maximum: 10 },
    blockers: { type: 'array', items: { type: 'string' } },
    frictions: { type: 'array', items: { type: 'string' } },
    delights: { type: 'array', items: { type: 'string' } },
    narrative: { type: 'string' },
  },
}

function expertPrompt(e) {
  return [
    'You are a senior, grumpy, specific expert on a design-review panel. Your lens: ' + e.title + '.',
    '',
    'SURFACE UNDER REVIEW:\n' + SURFACE,
    '',
    'YOUR LENS:\n' + e.lens,
    '',
    GROUNDING,
    '',
    SHOT_BLOCK + FILE_BLOCK,
    '',
    'TASK: Critique the surface through your lens. Give a grumpy 1-10 score, the genuine strengths, and concrete issues (severity + evidence + a specific, actionable, design-system-token-respecting fix). Then your top priorities — the few changes that would move the needle most. Return ONLY the structured object; be concrete, cite screenshots/files, do not pad.',
  ].join('\n')
}

function personaPrompt(p) {
  return [
    'You are ' + p.persona,
    '',
    'SURFACE YOU ARE TRYING TO USE:\n' + SURFACE,
    '',
    GROUNDING,
    '',
    SHOT_BLOCK,
    '',
    'TASK: As this person, try to accomplish the core job on this surface. Where do you succeed, hesitate, or give up? Give a verdict (would-use / would-struggle / would-abandon), a 1-10 score for how well this serves YOU specifically, and your blockers / frictions / delights with a short first-person narrative grounded in what you actually see. Return ONLY the structured object.',
  ].join('\n')
}

// ---------------------------------------------------------------------------
phase('Experts')
log('Round ' + ROUND + ': ' + EXPERTS.length + ' design experts rating ' + SHOTS.length + ' screenshots...')
const expertResults = (
  await parallel(
    EXPERTS.map((e) => () =>
      agent(expertPrompt(e), { label: 'expert:' + e.key, phase: 'Experts', schema: EXPERT_SCHEMA, effort: 'high' })
        .then((r) => (r ? { key: e.key, ...r } : null))
    )
  )
).filter(Boolean)

let personaResults = []
if (INCLUDE_PERSONAS) {
  phase('Personas')
  log('Round ' + ROUND + ': ' + PERSONAS.length + ' user personas stress-testing the surface...')
  personaResults = (
    await parallel(
      PERSONAS.map((p) => () =>
        agent(personaPrompt(p), { label: 'persona:' + p.key, phase: 'Personas', schema: PERSONA_SCHEMA, effort: 'high' })
          .then((r) => (r ? { key: p.key, ...r } : null))
      )
    )
  ).filter(Boolean)
}

function avg(nums) {
  return nums.length ? Math.round((nums.reduce((a, b) => a + b, 0) / nums.length) * 100) / 100 : 0
}
const expertScores = expertResults.map((r) => r.score)
const personaScores = personaResults.map((r) => r.score)
const expertAvg = avg(expertScores)
const personaAvg = avg(personaScores)
const expertMin = expertScores.length ? Math.min(...expertScores) : 0
const personaMin = personaScores.length ? Math.min(...personaScores) : 0
const cleared = expertAvg >= TARGET && (!INCLUDE_PERSONAS || personaAvg >= TARGET)

log('Experts avg=' + expertAvg + ' (min ' + expertMin + ') scores=[' + expertScores.join(', ') + ']')
if (INCLUDE_PERSONAS) log('Personas avg=' + personaAvg + ' (min ' + personaMin + ') scores=[' + personaScores.join(', ') + ']')
log(cleared ? ('CLEARED the bar (both panels avg >= ' + TARGET + ')') : ('NOT cleared — target avg ' + TARGET))

// ---------------------------------------------------------------------------
phase('Synthesis')
const synthPrompt = [
  'You are the head of design+product delivering the verdict for round ' + ROUND + ' on this surface:',
  SURFACE,
  '',
  'EXPERT PANEL (JSON):\n' + JSON.stringify(expertResults, null, 2),
  INCLUDE_PERSONAS ? ('\nPERSONA PANEL (JSON):\n' + JSON.stringify(personaResults, null, 2)) : '',
  '',
  'Computed: expert avg=' + expertAvg + ' (min ' + expertMin + '), persona avg=' + personaAvg + ' (min ' + personaMin + '), target=' + TARGET + '.',
  '',
  'Produce concise markdown: (1) a scorecard table (reviewer | score | one-line verdict) for both panels; (2) a RANKED consensus must-fix list — issues flagged by 2+ experts OR any persona blocker that stops the core job — each with ONE concrete, design-system-token-respecting widget-level fix; (3) a short "quick wins / both-sides fixes" list (single changes that satisfy two opposed reviewers); (4) a defer list; (5) a final line exactly "VERDICT: CLEARED" if both panel averages are >= ' + TARGET + ', else "VERDICT: ITERATE", with one sentence on the single biggest lever. Be opinionated and tight; no fluff.',
].join('\n')
const synthesis = await agent(synthPrompt, { label: 'synthesis', phase: 'Synthesis', effort: 'high' })

return {
  round: ROUND,
  target: TARGET,
  expertAvg,
  expertMin,
  personaAvg: INCLUDE_PERSONAS ? personaAvg : null,
  personaMin: INCLUDE_PERSONAS ? personaMin : null,
  cleared,
  expertScores: expertResults.map((r) => ({ key: r.key, expert: r.expert, score: r.score, topPriorities: r.topPriorities })),
  personaVerdicts: personaResults.map((r) => ({ key: r.key, verdict: r.verdict, score: r.score, blockers: r.blockers })),
  expertResults,
  personaResults,
  synthesis,
}
