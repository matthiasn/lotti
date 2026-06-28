#include <flutter/runtime_effect.glsl>

precision highp float;

// Dramatic post-sunset sky: deep zenith fading to a warm afterglow at the
// horizon with a hot sun hotspot, twinkling stars, a soft moon, and cumulus
// clouds underlit by the sunset. Uniform order MUST match buildSkyUniforms().

uniform vec2 uResolution;
uniform float uTime;
uniform float uHorizon;        // y-fraction of the horizon
uniform float uSunGlowX;       // 0..1 x of the afterglow hotspot
uniform vec2 uMoonPos;         // 0..1, top-left origin
uniform float uMoonRadius;     // fraction of the smaller dimension
uniform float uStarDensity;    // 0..1
uniform float uCloudCoverage;  // threshold (higher => fewer clouds)
uniform float uCloudSoftness;  // edge feather
uniform float uCloudScale;     // spatial frequency
uniform float uHazeStrength;   // 0..1 smog band
uniform float uGrain;          // 0..1 film grain
uniform vec4 uSkyZenith;
uniform vec4 uSkyUpper;
uniform vec4 uSkyHorizon;      // cool transitional band above the warm
uniform vec4 uSunsetGlow;      // burnt-orange afterglow
uniform vec4 uSunsetHot;       // hot amber core at the horizon
uniform vec4 uCloudDark;       // shadowed cloud top
uniform vec4 uMoon;
uniform vec4 uMoonHalo;
uniform vec4 uStar;
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
  for (int i = 0; i < 6; i++) {
    v += a * noise(p);
    p = p * 2.0 + vec2(11.3, 7.7);
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uResolution;
  float aspect = uResolution.x / max(uResolution.y, 1.0);

  // t: 0 at the top of the frame, 1 at the horizon.
  float t = clamp(uv.y / max(uHorizon, 0.001), 0.0, 1.0);

  // --- Dramatic post-sunset vertical gradient ---
  vec3 sky = mix(uSkyZenith.rgb, uSkyUpper.rgb, smoothstep(0.0, 0.52, t));
  sky = mix(sky, uSkyHorizon.rgb, smoothstep(0.46, 0.80, t));
  sky = mix(sky, uSunsetGlow.rgb, smoothstep(0.80, 1.0, t));

  // Warm sun hotspot sitting on the horizon at uSunGlowX.
  float sdx = (uv.x - uSunGlowX) * aspect;
  float sdy = (t - 1.0) * 1.5;
  float sun = exp(-(sdx * sdx + sdy * sdy) * 2.2);
  sky = mix(sky, uSunsetHot.rgb, clamp(sun, 0.0, 1.0));

  // --- Stars (high sky only, dimmed by the afterglow) ---
  float starBand = 1.0 - smoothstep(0.35, 0.75, t);
  vec2 sc = vec2(uv.x * aspect, uv.y) * 170.0;
  vec2 scell = floor(sc);
  float sh = hash(scell);
  float lit = step(1.0 - clamp(uStarDensity, 0.0, 1.0) * 0.14, sh);
  vec2 sp = fract(sc) - 0.5;
  float tw = 0.5 + 0.5 * sin(uTime * (1.4 + 2.6 * hash(scell + 3.3)) + sh * 6.2831);
  sky += uStar.rgb * (lit * smoothstep(0.16, 0.0, length(sp)) * tw * starBand * 0.9);

  // --- Moon: soft disc + gentle bloom (no cross flare) ---
  vec2 mdv = uv - uMoonPos;
  mdv.x *= aspect;
  float ml = length(mdv);
  float disc = smoothstep(uMoonRadius, uMoonRadius * 0.92, ml);
  float bloom = exp(-pow(ml / (uMoonRadius * 2.6), 2.0));
  sky = mix(sky, uMoonHalo.rgb, bloom * 0.35);
  sky += uMoon.rgb * disc;

  // --- Cumulus clouds, underlit by the sunset ---
  // Compress vertically toward the horizon so cloud rows stack near the skyline.
  vec2 cuv = vec2(uv.x * aspect, t * 1.6) * max(uCloudScale, 0.001);
  vec2 wind = vec2(uTime * 0.010, 0.0);
  vec2 warp = vec2(
    fbm(cuv * 0.6 + wind),
    fbm(cuv * 0.6 + vec2(5.2, 1.3) + wind)
  );
  float dens = fbm(cuv + 0.7 * warp + wind);
  // Sample a touch toward the zenith to get a vertical density slope (a fake
  // surface normal): bottoms (slope > 0) catch the warm underlight.
  float densUp = fbm(cuv + 0.7 * warp + wind + vec2(0.0, -0.18));
  float slope = clamp((dens - densUp) * 4.0 + 0.45, 0.0, 1.0);

  // Float in the mid sky and fade out before the horizon glow.
  float band = smoothstep(0.05, 0.26, t) * (1.0 - smoothstep(0.78, 0.93, t));
  float cover =
      smoothstep(uCloudCoverage, uCloudCoverage + uCloudSoftness, dens) * band;
  float core =
      smoothstep(uCloudCoverage + uCloudSoftness, uCloudCoverage + 0.35, dens);

  float warmth = clamp(sun * 1.6 + t * 0.5, 0.0, 1.0);
  vec3 litCloud = mix(uSunsetGlow.rgb, uSunsetHot.rgb, warmth * 0.7) * 1.05;
  vec3 cloudCol = mix(uCloudDark.rgb, litCloud, slope * (0.35 + 0.65 * warmth));
  cloudCol = mix(cloudCol, uCloudDark.rgb, core * 0.5);
  sky = mix(sky, cloudCol, clamp(cover, 0.0, 1.0));

  // --- Smog band + film grain ---
  float haze = clamp(uHazeStrength, 0.0, 1.0) * smoothstep(0.55, 1.0, t);
  sky = mix(sky, uHaze.rgb, haze * 0.45);
  sky += (hash(frag + fract(uTime) * vec2(13.1, 7.7)) - 0.5) * uGrain;

  fragColor = vec4(sky, 1.0);
}
