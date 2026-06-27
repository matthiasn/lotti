#include <flutter/runtime_effect.glsl>

precision highp float;

// Blue-hour sky: vertical twilight gradient + twinkling stars + a moon with
// bloom and a faint crescent + drifting domain-warped cumulus clouds, finished
// with a low smog/haze band and film grain so it reads grimy, not pristine.
// Uniform order here MUST match buildSkyUniforms() on the Dart side.

uniform vec2 uResolution;
uniform float uTime;
uniform float uHorizon;        // y-fraction of the horizon/waterline
uniform vec2 uMoonPos;         // 0..1, top-left origin
uniform float uMoonRadius;     // fraction of the smaller dimension
uniform float uStarDensity;    // 0..1
uniform float uCloudCoverage;  // 0..1 (higher => fewer clouds)
uniform float uCloudSoftness;  // edge feather
uniform float uCloudScale;     // spatial frequency
uniform float uHazeStrength;   // 0..1 smog band
uniform float uGrain;          // 0..1 film grain
uniform vec4 uSkyZenith;
uniform vec4 uSkyUpper;
uniform vec4 uSkyHorizon;
uniform vec4 uMoonColor;
uniform vec4 uMoonHalo;
uniform vec4 uStarColor;
uniform vec4 uCloudLit;
uniform vec4 uCloudShadow;
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
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p *= 2.02;
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uResolution;
  float aspect = uResolution.x / max(uResolution.y, 1.0);

  // Vertical twilight gradient: zenith at the top, cyan at the horizon.
  float h = clamp(uv.y / max(uHorizon, 0.001), 0.0, 1.0);
  vec3 col = mix(uSkyZenith.rgb, uSkyUpper.rgb, smoothstep(0.0, 0.72, h));
  col = mix(col, uSkyHorizon.rgb, smoothstep(0.55, 1.0, h));

  // Stars — sparse per-cell, twinkling, fading toward the horizon.
  float starBand = 1.0 - smoothstep(uHorizon * 0.5, uHorizon, uv.y);
  vec2 sc = vec2(uv.x * aspect, uv.y) * 150.0;
  vec2 scell = floor(sc);
  float sh = hash(scell);
  float lit = step(1.0 - clamp(uStarDensity, 0.0, 1.0) * 0.16, sh);
  vec2 sp = fract(sc) - 0.5;
  float sd = length(sp);
  float tw = 0.5 + 0.5 * sin(uTime * (1.5 + 3.0 * hash(scell + 7.3)) + sh * 6.2831);
  col += uStarColor.rgb * (lit * smoothstep(0.16, 0.0, sd) * tw * starBand);

  // Moon — disc, crescent terminator, bloom and slow sparkle spikes.
  vec2 md = uv - uMoonPos;
  md.x *= aspect;
  float mr = uMoonRadius;
  float mlen = length(md);
  float disc = smoothstep(mr, mr * 0.86, mlen);
  float term = smoothstep(
      mr * 0.96, mr * 0.70, length(md + vec2(mr * 0.34, -mr * 0.10)));
  float body = clamp(disc - term * 0.4, 0.0, 1.0);
  float halo = exp(-pow(mlen / (mr * 3.6), 2.0));
  float ang = atan(md.y, md.x);
  float spike = pow(max(0.0, cos(ang * 2.0 + uTime * 0.12)), 48.0) +
      pow(max(0.0, cos(ang * 2.0 - 0.785 + uTime * 0.12)), 48.0);
  float sparkle = spike * exp(-pow(mlen / (mr * 2.2), 2.0)) * 0.5;
  col = mix(col, uMoonHalo.rgb, halo * 0.45);
  col += uMoonColor.rgb * (body + sparkle);

  // Cumulus clouds — domain-warped fbm, drifting, confined to the upper band.
  vec2 cuv = vec2(uv.x * aspect, uv.y) * max(uCloudScale, 0.001);
  vec2 drift = vec2(uTime * 0.012, uTime * 0.002);
  vec2 warp = vec2(fbm(cuv + drift), fbm(cuv + drift + vec2(5.2, 1.3)));
  float d = fbm(cuv + 1.8 * warp + drift);
  float band = smoothstep(0.0, 0.16, uv.y) *
      (1.0 - smoothstep(uHorizon * 0.65, uHorizon, uv.y));
  float cov = smoothstep(uCloudCoverage, uCloudCoverage + uCloudSoftness, d) * band;
  vec3 cloudCol = mix(uCloudShadow.rgb, uCloudLit.rgb, smoothstep(0.2, 1.0, d));
  col = mix(col, cloudCol, clamp(cov, 0.0, 1.0) * 0.92);

  // Smog/haze band near the horizon — lifts blacks, desaturates (grime).
  float haze = clamp(uHazeStrength, 0.0, 1.0) *
      smoothstep(uHorizon * 0.45, uHorizon, uv.y);
  col = mix(col, uHaze.rgb, haze * 0.6);

  // Film grain.
  float g = (hash(frag + fract(uTime) * vec2(13.1, 7.7)) - 0.5) * uGrain;
  col += g;

  fragColor = vec4(col, 1.0);
}
