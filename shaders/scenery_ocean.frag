#include <flutter/runtime_effect.glsl>

precision highp float;

// Band-clipped ocean overlay for the painted blue-hour plate. The master plate
// already paints static water; this layer ADDS animated life over it — drifting
// foam crests, a broken vertical moon-glint column, and a very subtle vertical
// tint — confined to the water band below the waterline. Fragments are mapped
// into the art's cover-fit space (uCoverOffset/uCoverDrawn), the SAME crop the
// master plate uses, so the band lines up with the painted waterline at any
// viewport aspect, exactly like the city-lights overlay.
//
// Drawn with BlendMode.plus: the output mirrors the city-lights convention —
// rgb is the summed colored contribution and alpha is the summed coverage — so
// the region above the waterline and calm troughs contribute nothing while foam
// crests and the glint column add brightness. Uniform order MUST match
// buildOceanUniforms().

uniform vec2 uResolution;   // 0,1 viewport px
uniform float uTime;        // 2  scene clock (seconds)
uniform vec2 uCoverOffset;  // 3,4 px: top-left of the cover-fit art
uniform vec2 uCoverDrawn;   // 5,6 px: cover-fit art size
uniform float uWaterline;   // 7  normalized art-y where the water begins
uniform float uMoonX;       // 8  normalized art-x of the glint column
uniform float uFoamDensity; // 9  0..1 crest coverage
uniform float uWaveScale;   // 10 base crest frequency
uniform float uReflection;  // 11 moon-glint strength
uniform float uTint;        // 12 subtle vertical-tint alpha (0..~0.2)
uniform float uGrain;       // 13 film grain
uniform float uBeat;        // 14 0..1 musical pulse (swells foam)
uniform vec4 uOceanHorizon; // 15..18 water at the waterline
uniform vec4 uOceanNear;    // 19..22 water at the bottom
uniform vec4 uFoam;         // 23..26 crest foam
uniform vec4 uMoonGlint;    // 27..30 reflection column

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

void main() {
  vec2 frag = FlutterFragCoord().xy;
  // Map into the art's cover-fit space so the band tracks the painted plate.
  vec2 art = (frag - uCoverOffset) / uCoverDrawn;

  // depth: 0 at the waterline, 1 at the art's bottom edge. Water band only.
  float span = max(1.0 - uWaterline, 0.001);
  float depth = (art.y - uWaterline) / span;
  if (depth < 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  depth = clamp(depth, 0.0, 1.0);

  float aspect = uResolution.x / max(uResolution.y, 1.0);
  // Aspect-corrected horizontal art coordinate for isotropic wave spacing.
  float x = art.x * aspect;
  float beat = clamp(uBeat, 0.0, 1.0);
  // Lateral aerial perspective: the bright left bay (under the lit city) sits
  // closest to the strongest source and the surface recedes + hazes toward the
  // moored yacht on the right, so the surface life (crest foam + glitter) dims
  // toward the right rather than staying evenly bright edge to edge. The warm
  // reflection columns are NOT subject to this (they track their own sources).
  // Onset pushed right (0.5) and floor raised (0.72): the dead-centre strip in
  // front of the lead now keeps full crest amplitude, and the far-right open
  // water between the lead and the yacht keeps legible chop instead of thinning
  // to a glassy remnant — a gentle aerial dim toward the haze, not a wipe.
  float lateralFall = mix(1.0, 0.72, smoothstep(0.5, 0.97, art.x));

  // --- Subtle vertical tint (very low alpha; the plate already paints water) ---
  vec3 water =
      mix(uOceanHorizon.rgb, uOceanNear.rgb, smoothstep(0.0, 1.0, depth));
  float tintA = clamp(uTint, 0.0, 1.0) * smoothstep(0.0, 0.35, depth);

  // --- Foam crests: roughly HORIZONTAL ridge lines parallel to the shore (the
  // water plane recedes, so crests read as near-horizontal bands, NOT vertical
  // streaks), packed tighter near the waterline by perspective and advecting
  // gently toward the viewer. A little x-waviness keeps them from being dead
  // straight; uWaveScale tunes the x-wobble frequency. ---
  float foamAmt = 0.0;
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    // Crest pitch in y: a LOW row count so crests are broad horizontal FILAMENTS,
    // not a fine speckle. Dense rows (the old 42 near the waterline) compress to
    // sub-pixel dots that read as sensor noise rather than moving foam, so the
    // pitch is kept low enough that each crest spans many pixels.
    // Denser crest pitch near the waterline (34 rows) collapsing to 9 toward the
    // viewer gives perspective foreshortening — crests compress with distance so
    // the band reads as a receding plane, not a uniformly-tiled wallpaper.
    float rows = mix(34.0, 9.0, depth) * (1.0 + fi * 0.4);
    float speed = 0.05 + fi * 0.035;
    float wob = fbm(vec2(x * uWaveScale * (0.12 + 0.06 * fi), depth * 3.0) -
        vec2(uTime * speed, 0.0));
    // Irregularly-spaced, wavy ridge phase. Keep the y-frequency of the phase
    // noise LOW (depth*3.0, not 6.0): a high y-frequency made the crest line jump
    // phase between adjacent rows, rounding each whitecap into an isotropic blob.
    // A low y-frequency lets a single crest stay coherent over a long horizontal
    // run (a filament) while still bending — the whole point of "whitecap", not
    // "speckle".
    float phase = depth * rows + wob * 3.5 +
        fbm(vec2(x * 1.4, depth * 3.0)) * 4.0 - uTime * (0.25 + speed);
    float crest = sin(phase);
    // Break-up stretched HARD horizontally: x freq 2.2 gives long runs, and the
    // y-frequency is dropped to depth*2.0 so the bright/dark segmentation does NOT
    // chop the filament vertically — segments stay long in x with dark gaps
    // between, reading as elongated foam streaks rather than a dot-field.
    float dash = mix(0.16, 1.0, smoothstep(0.32, 0.76,
        fbm(vec2(x * 2.2 + fi * 9.0, depth * 2.0 - uTime * (speed + 0.1)))));
    // Tighter threshold (0.5..0.74) carves thinner, harder-edged horizontal
    // filaments; a lifted amplitude floor (0.85) so the crests in the visible
    // upper strip out-punch the smooth reflection sheen below them, instead of
    // the foam being the dim element and the sheen the bright one.
    foamAmt += smoothstep(0.5, 0.74, crest) * dash * (0.62 + 0.25 * wob);
  }
  // Ease foam in FAST just under the waterline (the upper strip of water is the
  // most-visible band; a slow 0..0.12 ramp left it bald) and concentrate the
  // crest brightness in the VISIBLE band only: the foreground deck occludes the
  // water below art-y ~0.65, i.e. everything past depth ~0.28, so biasing
  // brightness toward depth 1 (the old 0.55+0.55*depth) spent the foam energy
  // UNDER the deck where the camera never sees it. Ramp up to full by the visible
  // waterline-to-deck strip, then hold (the rest is hidden anyway).
  float foamBand = smoothstep(0.0, 0.06, depth) *
      (1.0 - smoothstep(0.8, 1.0, depth)) *
      (0.42 + 0.42 * smoothstep(0.04, 0.26, depth)) * lateralFall;
  // Only a whisper of beat reactivity (was 0.6): a big beat-swell made the whole
  // foam field brighten and dim on every beat, which read as a weird pulsing of
  // the water. Keep it nearly steady.
  float foamA = clamp(
      clamp(foamAmt, 0.0, 1.2) * foamBand *
          clamp(uFoamDensity * (1.0 + 0.1 * beat), 0.0, 1.7),
      0.0,
      0.22);
  // Foam LIP at the waterline: a brighter, broken band right where the water
  // meets the seawall / far shore — the single strongest "this is liquid" cue.
  // BROKEN TONGUES, not a continuous smear: an x-varying gate picks WHICH columns
  // grow a bright foam tongue, and gates both how far each tongue reaches down and
  // its brightness — so the lip reads as discrete bright tongues licking into the
  // water with dark gaps between, exactly where the camera can see it (in the pier
  // gaps), rather than a soft even glow stripe along the whole waterline.
  float tongue = smoothstep(0.36, 0.66,
      fbm(vec2(x * 4.5, 7.0 - uTime * 0.12)));
  float lipReach = mix(0.07, 0.24, tongue);
  float lip = (1.0 - smoothstep(0.0, lipReach, depth)) *
      smoothstep(0.0, 0.012, depth);
  // A finer scallop within each tongue keeps its inner edge ragged. Driven HOT
  // (~1.7) and gated by `tongue` so the bright tongues quantize toward a near-1.0
  // white line and punch through the pale haze band on the same waterline.
  float lipWob =
      0.2 + 0.8 * smoothstep(0.3, 0.75,
          fbm(vec2(x * 6.0, depth * 12.0 - uTime * 0.18)));
  foamA = clamp(
      foamA + lip * lipWob * tongue * 0.18 * clamp(uFoamDensity, 0.0, 1.0),
      0.0,
      0.24);
  // NEAR foam: a broader broken wash where the lagoon laps the foreground
  // seawall/deck. This band is big and close to camera, so it is the foam that
  // actually reads — the far waterline lip alone is too distant to register.
  float nearLip =
      smoothstep(0.78, 0.92, depth) * (1.0 - smoothstep(0.93, 1.0, depth));
  float nearWob = 0.32 + 0.68 * smoothstep(0.3, 0.82,
      fbm(vec2(x * 6.5, depth * 22.0 - uTime * 0.14)));
  foamA = clamp(
      foamA + nearLip * nearWob * 0.08 * clamp(uFoamDensity, 0.0, 1.0), 0.0, 0.28);

  // --- Moon glint: a soft, broken vertical shimmer under uMoonX. Kept gentle
  // (the plate already paints the city's reflections); ripples horizontally so
  // it twinkles rather than sitting as a solid blob. ---
  float colX = abs(art.x - uMoonX) * aspect;
  float column = exp(-pow(colX / 0.06, 2.0));
  float ripple = smoothstep(0.5, 1.0,
      fbm(vec2(x * 18.0, depth * 14.0 - uTime * 0.4)));
  float glintA = clamp(
      column * ripple * clamp(uReflection, 0.0, 2.0) * (0.55 + 0.85 * depth),
      0.0,
      0.85);

  // --- Surface glitter: broad, low-frequency broken HORIZONTAL specular dashes
  // running across the WHOLE lagoon, NOT anchored to any source. The reflection
  // columns only live under the city/yacht, leaving the centre-front water (in
  // front of the lead) a dead near-black slab; this cool rippled sheet ties the
  // bright left to the receded right so the whole surface reads as living water
  // rather than a painted board between the columns. ---
  float glit = 0.0;
  for (int k = 0; k < 2; k++) {
    float fk = float(k);
    float gw = fbm(vec2(x * 1.1, depth * 3.5) -
        vec2(uTime * (0.06 + fk * 0.04), 0.0));
    float gridge = sin(depth * mix(24.0, 9.0, depth) * (1.0 + fk * 0.6) +
        gw * 4.0 - uTime * (0.16 + fk * 0.05));
    float gseg = smoothstep(0.45, 0.92,
        fbm(vec2(x * 1.6 + fk * 5.0, depth * 5.0 - uTime * 0.1)));
    glit += smoothstep(0.62, 0.95, gridge) * gseg;
  }
  // Strongest in the mid-water, easing off at the far waterline and the deck.
  float glitBand =
      smoothstep(0.06, 0.32, depth) * (1.0 - smoothstep(0.86, 1.0, depth));
  // Carry a LITTLE extra specular energy across the seam just right of the city
  // columns (~x 0.42) so the reflected-city band doesn't drop in a hard vertical
  // step — but kept small (0.3, wider sigma) because at 0.55 it built a smooth
  // bright "milky slab" of glitter at centre-left that read as an airbrushed wash
  // rather than broken specular dashes. The break-up now comes from `glit` itself.
  float seamLift = 1.0 + 0.3 * exp(-pow((art.x - 0.42) / 0.17, 2.0));
  float glitA =
      clamp(glit * glitBand * 0.14 * seamLift * lateralFall, 0.0, 0.22);
  // Cool sky-reflection tone (the surface mirrors the twilight sky between
  // crests), warming a touch toward the city columns on the left.
  vec3 glitCol = mix(uOceanHorizon.rgb * 1.7, uFoam.rgb, 0.35);

  // --- Warm reflection columns under the FIXED bright sources: the lit city
  // window cluster (left third, ~0.13/0.22/0.33) and the moored yacht's interior
  // glow (right ~0.85). The scene's structures don't move, so their x is baked
  // here. Each is a soft column broken into vertical dashes. A real reflection of
  // a distant light is BRIGHTEST AT THE LIP (right under the source, on the
  // waterline) and breaks up + dims as it runs toward the viewer — so the column
  // weight is biased to the waterline and decays downward (the previous version
  // brightened toward the foreground, which read backwards: the streaks looked
  // detached from the windows above them). The city windows are the brightest
  // sources in frame yet the left bay was reading flat navy, so the left columns
  // carry the most weight. ---
  // CITY columns: the warm window centroid sits at art-x ~0.15..0.22, so the
  // three sources are anchored there (the old 0.33 column sat over a dark
  // building/bridge gap with no source above it). Pixel measurement showed the
  // left bay reading flat navy — the additive contribution was too weak + too
  // neutral to survive the cool plate and the haze — so the city columns are
  // multiplied hard (uReflection x ~3.5) and tinted a saturated sodium WARM
  // (vec3(1.0,0.62,0.32)), not the near-neutral glint tone the navy swamped.
  // The skyline has SEVERAL lit-window clusters but the water was showing only
  // one reflection (the lagoon read under-reflecting). Populate the left bay
  // with five columns spanning the cluster (0.10..0.33) so the city throws a
  // believable spread of warm streaks, not a lone pool.
  float reflCity = 0.0;
  for (int s = 0; s < 5; s++) {
    float cx = s == 0
        ? 0.10
        : s == 1 ? 0.15 : s == 2 ? 0.20 : s == 3 ? 0.27 : 0.33;
    float str = s == 0
        ? 0.7
        : s == 1 ? 1.0 : s == 2 ? 0.95 : s == 3 ? 0.75 : 0.8;
    // Per-row horizontal wobble so the columns aren't a rigid parallel "barcode":
    // real reflections ripple + smear sideways as the surface moves.
    cx += 0.008 * sin(depth * 11.0 + float(s) * 1.7 - uTime * 0.5);
    float d = abs(art.x - cx) * aspect;
    // ANISOTROPIC: keep sigma_x small (a tight vertical streak, not a wash blob)
    // and let it fan only slightly toward the viewer.
    float colw = 0.012 + 0.02 * depth;
    float col = exp(-pow(d / colw, 2.0));
    // Break the streak into STACKED vertical dashes: the noise runs mostly along
    // y (high depth frequency) so each column reads as ripple-broken segments
    // rather than a horizontal smear.
    float dash = smoothstep(0.4, 0.82,
        fbm(vec2(art.x * 8.0, depth * 42.0 - uTime * 0.5 + float(s) * 7.0)));
    // Lip-weighted fall with a raised floor at the lip itself (so the column
    // doesn't go to dark navy right under the source) then a decay toward the
    // foreground — the brightest part sits under the source and it tapers to a
    // faint shimmer ~2/3 of the way down (never reaching the deck).
    float colFall = max(0.3, smoothstep(0.0, 0.04, depth)) * exp(-depth * 4.5);
    reflCity += col * dash * str * colFall;
  }
  // YACHT reflection: the moored yacht's warm cabin/deck lights throw their own
  // broken columns onto the near water IN FRONT of the hull. Three streaks span
  // the lit superstructure (0.80..0.90). Their heads pin to the HULL waterline
  // (further down-frame than the far-shore waterline), so the fall is offset by
  // ~0.10 depth — anchoring at depth 0 would bury the bright head BEHIND the
  // opaque hull, leaving only the dim tail (why the yacht read as not reflecting
  // at all). The whole reflection is also added AFTER the hull footprint mask
  // (below), so the footprint that hides ocean THROUGH the hull doesn't also
  // erase the reflection on the open water just in front of it.
  float reflYacht = 0.0;
  float yDepth = depth - 0.08;
  for (int yc = 0; yc < 3; yc++) {
    float cx = yc == 0 ? 0.80 : (yc == 1 ? 0.85 : 0.90);
    float str = yc == 0 ? 0.9 : (yc == 1 ? 1.0 : 0.72);
    // Per-row horizontal wobble so the three streaks shimmer as SEPARATE broken
    // reflections (a rippled mirror) instead of fusing into one uniform band.
    cx += 0.012 * sin(depth * 9.0 + float(yc) * 2.0 - uTime * 0.6);
    float d = abs(art.x - cx) * aspect;
    float colw = 0.012 + 0.02 * depth;
    float col = exp(-pow(d / colw, 2.0));
    float dash = smoothstep(0.3, 0.85,
        fbm(vec2(art.x * 8.0,
            depth * 34.0 - uTime * 0.5 + float(yc) * 11.0 + 30.0)));
    // A MUCH longer reach than the city columns (decay 1.8 vs 4.5): the streaks
    // run down past the hull lip into the mid-water band toward the near-foam
    // line, instead of terminating as a thin bright lip right under the hull.
    float colFall =
        smoothstep(0.0, 0.04, yDepth) * exp(-max(yDepth, 0.0) * 1.8);
    reflYacht += col * dash * str * colFall;
  }

  // Gain pushed to ~6x (measured: at 3.5x the warm peak never crossed neutral
  // R-B — the cool plate still won). At this gain the column centre reads as a
  // genuinely warm sodium reflection, not a faint less-blue patch. The yacht
  // sits a touch under the city (~0.7x) and a warmer, softer 2700K amber.
  float reflCityA =
      clamp(reflCity * clamp(uReflection, 0.0, 2.0) * 2.2, 0.0, 0.36);
  float reflYachtA =
      clamp(reflYacht * clamp(uReflection, 0.0, 2.0) * 2.0, 0.0, 0.34);
  vec3 cityWarm = vec3(1.0, 0.62, 0.32);
  vec3 yachtWarm = vec3(1.0, 0.66, 0.38);

  // --- Fresnel horizon sheen: at the grazing angle near the far shore the
  // lagoon mirrors the bright twilight sky, so the band just under the waterline
  // lifts toward a cool desaturated sky tone while the surface darkens toward the
  // viewer (body absorption). This depth grade is the main cue that the water
  // recedes instead of reading as one flat sheet; a faint ripple keeps the sheen
  // from being a clean horizontal stripe. ---
  float fres = 1.0 - smoothstep(0.0, 0.55, depth);
  // Higher-contrast ripple (0.55..1.0, was 0.75..1.0) so the sheen carves visible
  // darker troughs across the surface instead of laying down a flat, even,
  // airbrushed milky band — the troughs are what make it read as a rippled mirror.
  float sheenRipple =
      0.55 + 0.45 * fbm(vec2(x * 6.5, depth * 24.0 - uTime * 0.3));
  // Desaturated toward a cool slate (not bright teal): oceanHorizon * 1.9 read
  // as a milky CYAN smear at the far waterline. Pull the multiplier down and mix
  // harder toward the neutral foam tone so the sheen lifts the horizon without a
  // saturated cyan blob.
  vec3 sheenCol = mix(uOceanHorizon.rgb * 1.35, uFoam.rgb, 0.5);
  float sheenA = fres * fres * 0.035 * sheenRipple;

  // Summed colored contribution + summed coverage (city-lights convention). The
  // city reflections carry their own saturated sodium WARM; the moon glint keeps
  // the cooler glint tone. The yacht reflection is summed in LATER (after the
  // hull footprint mask) so the mask can't erase it.
  vec3 added = water * tintA + sheenCol * sheenA + uFoam.rgb * foamA +
      uMoonGlint.rgb * glintA + cityWarm * reflCityA + glitCol * glitA;
  float coverage =
      clamp(tintA + sheenA + foamA + glintA + reflCityA + glitA, 0.0, 1.0);

  // Static (UV-locked) grain. The old per-frame reseed (fract(uTime) in the hash)
  // re-randomised every pixel every frame, which BOILED the bright foam/water —
  // the #1 cause of the "flicker". A fixed-pattern dither textures the surface
  // without any temporal twinkle.
  float g = (hash(frag) - 0.5) * min(uGrain, 0.014);
  added *= 1.0 + g;

  // Suppress the ocean behind the moored yacht (lower-right). Its lower-window
  // glass is partly transparent, so foam/glint would otherwise show THROUGH it.
  // The yacht is a fixed element of this scene, so a fixed footprint does the job
  // without a per-frame mask sampler (which crashed on hot-reload).
  float yachtFoot =
      smoothstep(0.60, 0.66, art.x) * smoothstep(0.52, 0.56, art.y);
  vec4 outc = vec4(added, coverage) * (1.0 - clamp(yachtFoot, 0.0, 1.0));
  // Right-half (yacht-side) ambient water lift. The painted plate is ~40% darker
  // under the yacht, and the footprint mask above zeroes the ocean shader there,
  // so the right bay read as a near-black void between the reflection columns. A
  // subtle cool fill on the open near-water IN FRONT of the hull (gated below the
  // hull waterline so it only touches water, added after the mask) lifts it to
  // read as lit lagoon — additive can only fill, not darken, so this rebalances
  // toward the brighter left half rather than crushing the left.
  float rightLift = smoothstep(0.60, 0.82, art.x) *
      smoothstep(0.13, 0.22, depth) * (1.0 - smoothstep(0.82, 1.0, depth));
  // Bleed a whisper of warm sunset (~0.16) into the right fill so the band isn't
  // one flat cool steel-blue edge to edge — the right sits under the warmer haze
  // toward the sunset azimuth, so its open water carries a faint warm cast against
  // the cool city-blue left.
  vec3 rightCool = mix(
      mix(uOceanHorizon.rgb, uOceanNear.rgb, depth), vec3(0.5, 0.4, 0.32), 0.16);
  outc.rgb += rightCool * rightLift * 0.04;
  // Yacht reflection added AFTER the footprint suppression: it lives on the
  // open near-water in front of the hull, and the opaque yacht bitmap drawn over
  // this layer still occludes any part that falls behind the hull.
  outc.rgb += yachtWarm * reflYachtA;
  outc.a = clamp(outc.a + rightLift * 0.04 + reflYachtA, 0.0, 1.0);
  fragColor = outc;
}
