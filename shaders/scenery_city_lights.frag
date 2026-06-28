#include <flutter/runtime_effect.glsl>

precision highp float;

// Additive night-lights overlay for the painted plate, drawn with BlendMode.plus.
//   * City windows are read from a REGISTERED window field baked from the master
//     itself (`city_windows.png`, tools/scenery_art/bake_city_windows.py): each
//     pixel says "is there a painted window here, how strong". Because the field
//     IS the master's own painted window grid, every glow lands exactly on a real
//     window — no second skyline render to drift out of alignment. The shader
//     only chooses WHICH windows are lit, per whole floor, and tints/flickers
//     them. The field is already gated to building interiors (off sky, water,
//     deck, palms and the yacht), so no silhouette masking is needed here.
//   * Yacht windows are placed EXPLICITLY on the painted glass (an inverted
//     brightness detector would trace the deck-shadow lines instead), and
//     modulated by glass darkness so the warm glow only fills the actual dark
//     panes, never the bright white superstructure.
// Coordinates use the art's cover-fit space (uCoverOffset/uCoverDrawn), the SAME
// crop the master plate uses, so every glow pins to its window at any aspect.
// Uniform order MUST match CityLightsLayer.

uniform vec2 uResolution;
uniform float uTime;
uniform float uWindowAmount; // 0..1 how strongly lit windows glow
uniform float uFlicker;      // 0..1 flicker depth
uniform float uBeat;         // 0..1 musical pulse
uniform vec2 uCoverOffset;   // px: top-left of the cover-fit art in the viewport
uniform vec2 uCoverDrawn;    // px: cover-fit art size
uniform vec4 uWarm;          // sodium window
uniform vec4 uCool;          // LED window
uniform vec4 uYachtGlow;     // warm cabin
uniform sampler2D uWindowField; // baked registered window field (master-derived)
uniform sampler2D uYachtMask;
uniform sampler2D uMaster; // the painted plate itself (for cloud-belly relight)

out vec4 fragColor;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 3; i++) {
    v += a * noise(p);
    p *= 2.03;
    a *= 0.5;
  }
  return v;
}

float lum(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

// Normalized art-y of the far shoreline where the skyline meets the lagoon
// (matches the bake band bottom in bake_city_windows.py). City reflections live
// below it.
const float kWaterline = 0.515;

// Lit-window selection over the registered window field. Real skylines read as
// WHOLE FLOORS lit or dark (occupied vs. empty floors), not salt-and-pepper:
//   * art space is bucketed into building columns (bx) and floor rows (fy);
//   * each building gets a "mood" -> what fraction of its floors are occupied;
//   * a whole floor (bx, fy) switches on/off together (floorOn);
//   * only some buildings are "mixed", dropping a few windows within a lit floor;
//   * a rare lone window burns on an otherwise-dark floor (lived-in detail).
// Returns the glow strength for this pixel; [warmSel] picks sodium vs. LED.
float cityWindows(vec2 uv, float field, float amount, float time, float flicker,
    out float warmSel) {
  float pane = smoothstep(0.06, 0.42, field); // clean, evenly-bright panes
  if (pane <= 0.0) {
    warmSel = 1.0;
    return 0.0;
  }

  float bx = floor(uv.x * 16.0);  // building-ish column
  float fy = floor(uv.y * 150.0); // floor row
  float mood = hash(vec2(bx, 3.0));
  // Higher floor on every building (even quiet ones keep some lit floors) so the
  // highrises read as occupied at night instead of mostly dark.
  float litFrac = clamp(mix(0.24, 0.92, mood) * (0.6 + 0.7 * amount), 0.0, 0.97);
  // Low-frequency occupancy in y: adjacent floors sample nearby noise, so whole
  // RUNS of floors share a lit/dark state (occupied vs. empty blocks of a
  // building), instead of a per-floor salt-and-pepper checkerboard.
  float floorH = noise(vec2(bx * 13.0, fy * 0.28));
  float floorOn = step(1.0 - litFrac, floorH); // whole floor run lit or dark

  vec2 wcell = floor(uv * vec2(360.0, 200.0));
  float winH = hash(wcell + 4.2);
  float mixed = step(0.55, hash(vec2(bx, 9.0))); // ~45% of buildings speckled
  float speckle = mix(1.0, step(0.22, winH), mixed);
  float lit = floorOn * speckle;
  lit = max(lit, (1.0 - floorOn) * step(0.992, winH)); // lone late-night window
  // Occupancy churn: a SMALL fraction (~7%) of windows ignore the static floor
  // pattern and switch on/off on their own LONG cycle (16-36 s, ~50% duty), so
  // the skyline gently breathes — a light flicks on here, another goes dark there,
  // as people come and go — without the city-wide strobing that reads as a
  // malfunction. uTime advances with playback and freezes when paused.
  float churnSel = step(0.93, hash(wcell + 8.3)); // ~7% of windows churn
  float period = 16.0 + 20.0 * hash(wcell + 2.1); // 16-36 s cycles (calm)
  float churnOn = step(0.5, fract(time / period + hash(wcell + 6.4)));
  lit = mix(lit, churnOn, churnSel);

  warmSel = step(hash(wcell + 1.7), 0.82);
  float bright = 0.6 + 0.4 * hash(wcell + 3.1);
  float flick = 1.0 -
      flicker * 0.45 *
          (0.5 + 0.5 * sin(time * (0.6 + 1.4 * hash(wcell + 5.0)) + winH * 21.0));
  return pane * lit * bright * flick;
}

// Yacht: warm glow that follows the SHAPE of the painted glass, derived from the
// yacht art itself (uYachtMask) instead of hand-placed boxes — boxes paint amber
// rectangles that ignore the yacht's angled sheer and curved windows. The tinted
// saloon/deck windows and hull portholes are recessed DARK panes set into the
// bright white superstructure, so a high-pass (this pixel vs. its local
// neighbourhood) isolates exactly those panes, and the glow lands on their real
// outlines. Confined to the yacht alpha and the window decks so the white roof,
// mast and the dark waterline shadow never light.
float yachtWindow(vec2 uv) {
  vec4 t = texture(uYachtMask, uv);
  if (t.a < 0.3) {
    return 0.0;
  }
  float l = lum(t.rgb);
  // High-pass vs. a small neighbourhood: a recessed pane reads darker than the
  // bright frame/hull around it. The threshold is high so only STRONG contrast
  // (the saloon / sky-lounge window edges, set under the white deck eyebrows, and
  // the portholes punched in the bright hull) lights — the weaker, finer dark
  // gaps between rail balusters and panel lines fall below it and stay dark, so
  // the superstructure does not speckle warm.
  float o = 0.006;
  float avg = 0.25 * (lum(texture(uYachtMask, uv + vec2(o, 0.0)).rgb) +
      lum(texture(uYachtMask, uv + vec2(-o, 0.0)).rgb) +
      lum(texture(uYachtMask, uv + vec2(0.0, o)).rgb) +
      lum(texture(uYachtMask, uv + vec2(0.0, -o)).rgb));
  float recess = smoothstep(0.09, 0.22, avg - l);
  // Glass is mid-dark: drop the near-black hull-bottom shadow and the bright
  // white superstructure / sky-reflective panels.
  float glass = smoothstep(0.05, 0.12, l) * (1.0 - smoothstep(0.30, 0.48, l));
  // Window decks only (saloon + sky-lounge + porthole row); excludes the roof /
  // mast above and the lower hull / waterline below.
  float deck =
      smoothstep(0.43, 0.45, uv.y) * (1.0 - smoothstep(0.59, 0.62, uv.y));
  return recess * glass * deck * t.a;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 muv = (frag - uCoverOffset) / uCoverDrawn;
  if (muv.x < 0.0 || muv.x > 1.0 || muv.y < 0.0 || muv.y > 1.0) {
    fragColor = vec4(0.0);
    return;
  }

  float beat = 0.85 + 0.3 * uBeat;
  vec3 lights = vec3(0.0);
  float intensity = 0.0;

  // --- Aerial-perspective haze: a cool, low-saturation veil over the skyline
  // band that THICKENS WITH DISTANCE (toward the top of the band = the far
  // towers), so the far city sits behind air and reads dimmer / lower-contrast
  // than the near bridge. On a flat painted plate this depth grade is the single
  // strongest cue separating the far skyline from the near structures. ---
  vec3 hazeCol = vec3(0.227, 0.259, 0.322); // hazeSmog #3A4252
  // 1 at the top of the building band (far) -> 0 at the waterline (near).
  float depthFar = 1.0 - clamp((muv.y - 0.15) / (kWaterline - 0.15), 0.0, 1.0);
  float band = smoothstep(0.12, 0.19, muv.y) *
      (1.0 - smoothstep(0.49, kWaterline + 0.02, muv.y));
  // Stronger grade with distance so the FAR (upper) towers wash into the air and
  // the skyline stops reading as one flat-contrast cut-out band.
  float haze = band * (0.10 + 0.42 * depthFar);
  lights += hazeCol * haze;
  intensity += haze * 0.6;

  // --- High cirrus: faint, slowly drifting wisps across the empty mid-sky,
  // breaking the flat gradient and giving the sky gentle motion. Cool (lit by
  // sky + moon) and very low alpha; domain-warped fbm for soft cloud edges. The
  // painted cumulus stay the hero; this is just atmosphere/parallax. ---
  float skyMask = (1.0 - smoothstep(0.22, 0.38, muv.y)) *
      smoothstep(0.02, 0.10, muv.y);
  if (skyMask > 0.0) {
    vec2 cuv = vec2(muv.x * 2.3 + uTime * 0.004, muv.y * 3.2 + 4.0);
    float wisp = fbm(cuv + fbm(cuv * 0.5));
    wisp = smoothstep(0.50, 0.86, wisp);
    float cir = wisp * skyMask * 0.06;
    // Silver lining: the cirrus catches the warm sunset key on the right and
    // stays cool moon-lit on the left, giving the whole sky one coherent light
    // direction instead of flat, evenly-cool wisps.
    vec3 cirCol = mix(vec3(0.55, 0.64, 0.84), vec3(0.86, 0.73, 0.60),
        smoothstep(0.45, 0.96, muv.x));
    lights += cirCol * cir;
    intensity += cir * 0.5;
  }

  // --- Warm sunset afterglow on the right horizon, bleeding up and inward to
  // warm the low cloud bellies above the city and unify the sky's light
  // direction (the painted plate already warms the right; this lifts that key
  // into the cloud band so the sky reads lit from one source). ---
  float glowX = smoothstep(0.34, 1.0, muv.x);
  float glowY =
      smoothstep(0.04, 0.20, muv.y) * (1.0 - smoothstep(0.20, 0.40, muv.y));
  float after = glowX * glowY * 0.05;
  lights += vec3(0.82, 0.56, 0.40) * after; // warm residual ember
  intensity += after * 0.5;

  // --- Cloud-belly underlight: the lit city and the warm horizon throw light UP
  // onto the undersides of the painted clouds. We detect cloud BOTTOMS in the
  // master (a locally bright pixel sitting above a darker one = an underside
  // facing the city) and tint them warm — strongest low in the sky and toward
  // the warm right horizon — so the clouds sit in the same light as the skyline
  // instead of floating as flat, separately-lit shapes. ---
  if (muv.y < 0.42) {
    float lHere = lum(texture(uMaster, muv).rgb);
    float lBelow = lum(texture(uMaster, muv + vec2(0.0, 0.013)).rgb);
    float lAbove = lum(texture(uMaster, muv - vec2(0.0, 0.013)).rgb);
    // Cloud BOTTOM edge (bright over darker) catches a warm bounce from the lit
    // city + horizon; whole cloud band, biased toward the right afterglow.
    float belly =
        smoothstep(0.15, 0.34, lHere) * smoothstep(0.0, 0.06, lHere - lBelow);
    float key = (1.0 - smoothstep(0.05, 0.40, muv.y)) *
        (0.60 + 0.40 * smoothstep(0.25, 0.95, muv.x));
    float glow = belly * key * 0.18;
    lights += vec3(0.95, 0.63, 0.42) * glow; // warm city/horizon bounce
    intensity += glow * 0.6;
    // Cloud TOP edge (bright over darker above) catches a cool silver lining
    // from the moon/sky, so the otherwise-flat painted clouds gain a lit rim and
    // a shadowed core — warm belly + cool crown = volume.
    float topEdge =
        smoothstep(0.15, 0.34, lHere) * smoothstep(0.0, 0.06, lHere - lAbove);
    float rim = topEdge * (1.0 - smoothstep(0.02, 0.36, muv.y)) * 0.11;
    lights += vec3(0.66, 0.76, 0.92) * rim; // cool moon/sky silver lining
    intensity += rim * 0.5;
  }

  // --- City: light whole floors of the master's own painted windows ---
  float field = texture(uWindowField, muv).r;
  float warmSel;
  float win =
      cityWindows(muv, field, uWindowAmount, uTime, uFlicker, warmSel);
  // Only "turn ON" windows that are DARK/off in the plate: gate the additive
  // emission by master darkness so already-bright (sky-reflective glass, white
  // facade) panes don't clip to a flat overexposed white when the warm light is
  // added on top — the glow lands on the real dark panes, and bright facades
  // keep their painted value. (Same darkness-gating the yacht glass uses.)
  float mLum = lum(texture(uMaster, muv).rgb);
  float darkGate = mix(0.16, 1.0, 1.0 - smoothstep(0.32, 0.60, mLum));
  // Aerial perspective: far windows EMIT less and lean toward the cool haze
  // colour, so the back of the skyline dissolves into the air instead of
  // punching at the same brightness/saturation as the near towers.
  // Gentle aerial dimming (was 0.55): the far towers still recede, but not so
  // hard that the highrises read as dark — they should be brightly lit at night.
  float farDim = 1.0 - 0.30 * depthFar;
  // Cool LED panes (#DCEBFF, near-white) clip to white far sooner than warm
  // sodium, so the minority LED windows are dimmed a touch to keep them reading
  // as cool-white panes instead of blown highlights.
  float cityRaw = win * (0.78 + 0.5 * uWindowAmount) * beat * farDim * darkGate *
      (0.72 + 0.28 * warmSel);
  // Soft highlight rolloff (Reinhard knee): dense window clusters glow but
  // asymptote well below white instead of stacking into a flat blown blob over
  // the plate, while dim windows stay ~linear. Many MODERATELY-lit windows read
  // as a living city far better than a few blinding ones.
  float cityLit = cityRaw / (1.0 + 1.2 * cityRaw);
  vec3 cityCol =
      mix(mix(uCool.rgb, uWarm.rgb, warmSel), hazeCol * 1.6, 0.32 * depthFar);
  lights += cityCol * cityLit;
  intensity += cityLit;

  // --- Bloom: a soft halo around lit clusters (4 diagonal taps of the same lit
  // logic, averaged + dimmed) so windows glow into the dusk air instead of
  // reading as crisp emissive decals. ---
  const float br = 0.0055;
  float bd;
  float bloom =
      cityWindows(muv + vec2(br, br), texture(uWindowField, muv + vec2(br, br)).r,
          uWindowAmount, uTime, uFlicker, bd) +
      cityWindows(muv + vec2(-br, br),
          texture(uWindowField, muv + vec2(-br, br)).r, uWindowAmount, uTime,
          uFlicker, bd) +
      cityWindows(muv + vec2(br, -br),
          texture(uWindowField, muv + vec2(br, -br)).r, uWindowAmount, uTime,
          uFlicker, bd) +
      cityWindows(muv + vec2(-br, -br),
          texture(uWindowField, muv + vec2(-br, -br)).r, uWindowAmount, uTime,
          uFlicker, bd);
  // Far windows bloom MORE and warmer — their light travels through more haze —
  // converting the distant towers into a soft glow band, while NEAR windows
  // stay tight so each lit pane keeps its individual sparkle (the bloom is
  // throttled hard on the near towers and opened up only with distance).
  // Soft-knee: where the DIRECT window light is already strong, suppress the
  // bloom so hot cores stop stacking into clipped white blobs — the bloom then
  // lives in the dimmer air AROUND the bright panes (a real bloom prefilter),
  // not on top of them.
  float knee = 1.0 - 0.6 * smoothstep(0.35, 0.85, win);
  float bloomLit = bloom * 0.12 * (0.7 + 0.6 * uWindowAmount) * beat *
      (0.5 + 1.15 * depthFar) * darkGate * knee;
  vec3 bloomCol =
      mix(mix(uCool.rgb, uWarm.rgb, warmSel), uWarm.rgb, 0.30 * depthFar);
  lights += bloomCol * bloomLit;
  intensity += bloomLit;

  // --- Anamorphic streak: lit windows throw a faint HORIZONTAL flare (a lens /
  // film signature), sampled only along x so the brightest clusters smear
  // sideways like a real anamorphic bloom instead of an isotropic disc. ---
  float streak = 0.0;
  for (int s = 1; s <= 3; s++) {
    float dx = float(s) * 0.006;
    float w = 1.0 - float(s) * 0.25; // 0.75, 0.50, 0.25
    float sd;
    streak += w *
        cityWindows(muv + vec2(dx, 0.0),
            texture(uWindowField, muv + vec2(dx, 0.0)).r, uWindowAmount, uTime,
            uFlicker, sd);
    streak += w *
        cityWindows(muv + vec2(-dx, 0.0),
            texture(uWindowField, muv + vec2(-dx, 0.0)).r, uWindowAmount, uTime,
            uFlicker, sd);
  }
  float streakLit = streak * 0.085 * (0.7 + 0.6 * uWindowAmount) * beat *
      (0.8 + 0.5 * depthFar) * darkGate;
  lights += mix(uCool.rgb, uWarm.rgb, warmSel) * streakLit;
  intensity += streakLit;

  // --- City up-glow: a warm sodium dome bleeding off the skyline into the dusk
  // sky, so the lit city actually colours the air above it (densest over the
  // cool left-centre district; the painted sunset already warms the right). ---
  // Tall, soft warm gradient: peaks at the rooftops and thins with altitude, so
  // it both lifts the dusk sky behind the skyline AND warms the bases of the low
  // clouds above the city (city glow on the atmosphere). Concentrated over the
  // cool left-centre district; the painted sunset already warms the right.
  float domeY = smoothstep(0.12, 0.46, muv.y) *
      (1.0 - smoothstep(0.46, kWaterline, muv.y));
  float domeX =
      smoothstep(0.02, 0.14, muv.x) * (1.0 - smoothstep(0.44, 0.62, muv.x));
  float dome = domeY * domeX * 0.11 * (0.85 + 0.3 * uBeat);
  lights += uWarm.rgb * dome;
  intensity += dome;

  // --- Reflections: the skyline's own lit windows smeared down the lagoon.
  // Mirror about the far waterline and re-evaluate the SAME window field + lit
  // logic at the source, then break it into rippled horizontal dashes so the
  // city shimmers on the water instead of mirroring cleanly. This is the cue
  // that sells "lit city across water at night". ---
  if (muv.y > kWaterline) {
    float below = muv.y - kWaterline;
    float srcY = kWaterline - below * 1.7; // mirror, stretched into tall columns
    if (srcY > 0.02) {
      // Vertical smear: average several ripple-jittered samples of the SAME lit
      // field up the column, so each lit window pulls into a soft vertical light
      // COLUMN on the water (real reflections elongate toward the viewer),
      // instead of a crisp, noisy mirror dot. The jitter spread grows with
      // distance from the shore so far reflections stay tight and near ones
      // stretch and shimmer.
      // Normalized distance from the far shore toward the viewer (0 at the
      // waterline, 1 at the bottom edge of the lagoon).
      float bf = clamp(below / (1.0 - kWaterline), 0.0, 1.0);
      // Coherent horizontal CHOP: a low-frequency flowing wave shifts the WHOLE
      // reflected column sideways (the same offset for every tap up the column),
      // so each reflection wavers left/right like wind-chop on the surface
      // instead of standing as a dead-straight vertical bar. Grows toward the
      // viewer where the water is more agitated.
      float chop =
          (fbm(vec2(muv.y * 7.0 - uTime * 0.3, muv.x * 3.0)) - 0.5) *
          (0.008 + 0.055 * bf);
      float rwin = 0.0;
      float rWarm = 0.0;
      for (int k = 0; k < 6; k++) {
        float fk = float(k);
        float jy =
            (fbm(vec2(muv.x * 30.0 + fk * 3.7, below * 40.0 - uTime * 0.4)) -
                0.5) *
            (0.010 + 0.08 * below);
        float sy = max(srcY + jy, 0.02);
        float sx = muv.x + chop +
            (fbm(vec2(muv.x * 22.0 + fk * 1.3, below * 26.0 - uTime * 0.35)) -
                0.5) *
                (0.006 + 0.05 * below);
        float rw;
        float rf = texture(uWindowField, vec2(sx, sy)).r;
        rwin += cityWindows(vec2(sx, sy), rf, uWindowAmount, uTime, uFlicker, rw);
        rWarm += rw;
      }
      rwin *= 1.0 / 6.0;
      rWarm *= 1.0 / 6.0;
      // Reflections read as CONTINUOUS vertical light columns at the far shore
      // (grazing angle => long unbroken smears), fragmenting into shorter ripple
      // dashes as they approach the viewer; ripple frequency compresses with
      // distance too, so the surface foreshortens instead of banding evenly.
      float rfreq = mix(34.0, 82.0, bf);
      float breakAmt = mix(0.22, 0.6, bf);
      // Per-column phase jitter so adjacent columns break at DIFFERENT heights —
      // otherwise the ripple dashes line up into a regular horizontal scanline
      // cadence across the basin.
      float colJit = hash(vec2(floor(muv.x * 60.0), 7.0)) * 6.2831;
      // De-band: give EACH column its own slightly different ripple frequency so
      // the dashes never share one global cadence (the source of horizontal
      // scanline banding), and add a small per-pixel hash dither so the
      // smoothstep edge can't quantise into stair-steps.
      float rfJit = rfreq * (0.72 + 0.56 * hash(vec2(floor(muv.x * 80.0), 3.0)));
      float dith = (hash(frag) - 0.5) * 0.16;
      float dash = (1.0 - breakAmt) +
          breakAmt *
              smoothstep(0.30, 0.80,
                  fbm(vec2(muv.x * 7.0, muv.y * rfJit + colJit - uTime * 0.5)) +
                      dith);
      float fade = 1.0 - smoothstep(kWaterline, 0.72, muv.y);
      float refl = rwin * dash * fade * 0.95 * beat;
      // City reflections read warmer than their sources (sodium dominates and
      // water absorbs the cool end), so bias the tint toward amber.
      vec3 rcol = mix(mix(uCool.rgb, uWarm.rgb, rWarm), uWarm.rgb, 0.35);
      lights += rcol * refl;
      intensity += refl;
    }
  }

  // --- Yacht: warm cabin / porthole glow from the explicit anchors. The moored
  // luxury yacht reads as occupied and lit at night, so this is pushed bright
  // (it was barely visible at normal viewing size). ---
  float yachtLit = yachtWindow(muv) * (0.85 + 0.5 * uWindowAmount) * beat;
  lights += uYachtGlow.rgb * yachtLit;
  intensity += yachtLit;
  // Halation: a soft warm halo bleeding out from the cabin glass onto the dark
  // hull (4 offset taps of the same glow, dimmed) so the windows read as glowing
  // SOURCES radiating into the dusk, not flat painted panes.
  const float yb = 0.012;
  float yhalo = yachtWindow(muv + vec2(yb, yb)) +
      yachtWindow(muv + vec2(-yb, yb)) + yachtWindow(muv + vec2(yb, -yb)) +
      yachtWindow(muv + vec2(-yb, -yb));
  float yhaloLit = yhalo * 0.22 * (0.5 + 0.4 * uWindowAmount) * beat;
  lights += uYachtGlow.rgb * yhaloLit;
  intensity += yhaloLit;

  fragColor = vec4(lights, clamp(intensity, 0.0, 1.0));
}
