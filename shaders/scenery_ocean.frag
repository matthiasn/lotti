#include <flutter/runtime_effect.glsl>

precision highp float;

// Lower-band lagoon water: vertical gradient + drifting cartoon foam crests +
// a broken vertical moon-glint column, with smog tint + grain for grime. The
// painter draws this into the water band only (band-local frag coords), so
// uResolution is the band size. Uniform order MUST match buildOceanUniforms().

uniform vec2 uResolution;
uniform float uTime;
uniform float uMoonX;          // 0..1 reflection column (band-local)
uniform float uHorizonFade;    // top fraction blending into the skyline base
uniform float uFoamDensity;    // 0..1
uniform float uWaveScale;      // crest frequency
uniform float uReflection;     // moon-glint strength
uniform float uHazeStrength;   // 0..1
uniform float uGrain;          // 0..1
uniform float uBeat;           // 0..1 musical pulse (swells foam)
uniform vec4 uWaterTop;
uniform vec4 uWaterBottom;
uniform vec4 uFoam;
uniform vec4 uMoonGlint;
uniform vec4 uHaze;

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
  vec2 uv = frag / uResolution;
  float aspect = uResolution.x / max(uResolution.y, 1.0);

  // Perspective: rows near the top (horizon) are compressed.
  float depth = uv.y;
  vec3 col = mix(uWaterTop.rgb, uWaterBottom.rgb, smoothstep(0.0, 1.0, depth));

  // Cartoon foam: a few advected crest ridges, brightest mid-band.
  float foamAmt = 0.0;
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float scale = uWaveScale * (1.0 + fi * 0.7);
    float speed = 0.20 + fi * 0.13;
    float n = fbm(vec2(uv.x * aspect * scale, depth * 6.0) +
        vec2(uTime * speed, fi * 3.1));
    float crest = sin(uv.x * aspect * scale * 3.14159 + n * 4.0 + uTime * speed);
    foamAmt += smoothstep(0.86, 0.99, crest) * (0.5 + 0.5 * n);
  }
  float foamBand = smoothstep(0.0, 0.25, depth) * (1.0 - smoothstep(0.7, 1.0, depth));
  float foam = clamp(foamAmt, 0.0, 1.0) * foamBand *
      clamp(uFoamDensity * (1.0 + 0.4 * uBeat), 0.0, 1.5);
  col = mix(col, uFoam.rgb, clamp(foam, 0.0, 0.85));

  // Broken vertical moon-glint column.
  float colX = abs(uv.x - uMoonX) * aspect;
  float glintShape = exp(-pow(colX / 0.05, 2.0));
  float ripple = smoothstep(0.45, 1.0,
      fbm(vec2(uv.x * aspect * 30.0, depth * 22.0 - uTime * 0.6)));
  float glint = glintShape * ripple * uReflection * (0.4 + 0.6 * depth);
  col += uMoonGlint.rgb * clamp(glint, 0.0, 1.0);

  // Seat the band under the skyline with a haze fade at the very top.
  float fade = uHazeStrength * (1.0 - smoothstep(0.0, uHorizonFade, depth));
  col = mix(col, uHaze.rgb, clamp(fade, 0.0, 0.6));

  // Film grain.
  float g = (hash(frag + fract(uTime) * vec2(9.3, 5.1)) - 0.5) * uGrain;
  col += g;

  fragColor = vec4(col, 1.0);
}
