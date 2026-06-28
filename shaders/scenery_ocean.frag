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
    // Crest pitch in y: many thin rows near the horizon, broader near the
    // bottom. The row count is the perspective compression.
    float rows = mix(80.0, 18.0, depth) * (1.0 + fi * 0.5);
    float speed = 0.05 + fi * 0.035;
    float wob = fbm(vec2(x * uWaveScale * (0.12 + 0.06 * fi), depth * 3.0) -
        vec2(uTime * speed, 0.0));
    // Irregularly-spaced, wavy ridge phase: low-frequency noise on the phase
    // keeps the crests from forming evenly-spaced horizontal scanlines (the
    // #1 procedural-water tell) — real whitecaps wander in spacing and bend.
    float phase = depth * rows + wob * 3.5 +
        fbm(vec2(x * 1.7, depth * 6.0)) * 5.0 - uTime * (0.25 + speed);
    float crest = sin(phase);
    // Break each crest into drifting dashes so foam reads as scattered
    // whitecaps, not continuous lines spanning the whole width.
    float dash = smoothstep(0.32, 0.72,
        fbm(vec2(x * 5.0 + fi * 9.0, depth * 9.0 - uTime * (speed + 0.1))));
    // Keep the upper part of each ridge → broader, clearly visible whitecaps
    // (a wider band than a hairline tip so the water reads as moving at normal
    // viewing size, not just under magnification).
    foamAmt += smoothstep(0.82, 0.97, crest) * dash * (0.45 + 0.55 * wob);
  }
  // Ease foam in just under the waterline and off at the very bottom, and bias
  // its brightness toward the viewer so the surface reads as receding water
  // (busier near the deck, calmer toward the far shore) instead of a flat sheet.
  float foamBand = smoothstep(0.0, 0.12, depth) *
      (1.0 - smoothstep(0.8, 1.0, depth)) * (0.4 + 0.6 * depth);
  float foamA = clamp(
      clamp(foamAmt, 0.0, 1.0) * foamBand *
          clamp(uFoamDensity * (1.0 + 0.6 * beat), 0.0, 1.4),
      0.0,
      0.9);

  // --- Moon glint: a soft, broken vertical shimmer under uMoonX. Kept gentle
  // (the plate already paints the city's reflections); ripples horizontally so
  // it twinkles rather than sitting as a solid blob. ---
  float colX = abs(art.x - uMoonX) * aspect;
  float column = exp(-pow(colX / 0.05, 2.0));
  float ripple = smoothstep(0.55, 1.0,
      fbm(vec2(x * 18.0, depth * 14.0 - uTime * 0.4)));
  float glintA = clamp(
      column * ripple * clamp(uReflection, 0.0, 2.0) * (0.2 + 0.5 * depth),
      0.0,
      0.5);

  // --- Fresnel horizon sheen: at the grazing angle near the far shore the
  // lagoon mirrors the bright twilight sky, so the band just under the waterline
  // lifts toward a cool desaturated sky tone while the surface darkens toward the
  // viewer (body absorption). This depth grade is the main cue that the water
  // recedes instead of reading as one flat sheet; a faint ripple keeps the sheen
  // from being a clean horizontal stripe. ---
  float fres = 1.0 - smoothstep(0.0, 0.55, depth);
  float sheenRipple = 0.75 + 0.25 * fbm(vec2(x * 6.0, depth * 22.0 - uTime * 0.3));
  vec3 sheenCol = mix(uOceanHorizon.rgb * 1.9, uFoam.rgb, 0.28);
  float sheenA = fres * fres * 0.12 * sheenRipple;

  // Summed colored contribution + summed coverage (city-lights convention).
  vec3 added = water * tintA + sheenCol * sheenA + uFoam.rgb * foamA +
      uMoonGlint.rgb * glintA;
  float coverage = clamp(tintA + sheenA + foamA + glintA, 0.0, 1.0);

  // Film grain modulates the additive energy (never lifts calm water alone).
  float g = (hash(frag + fract(uTime) * vec2(9.3, 5.1)) - 0.5) * uGrain;
  added *= 1.0 + g;

  fragColor = vec4(added, coverage);
}
