#include <flutter/runtime_effect.glsl>

precision highp float;

// Additive night-lights overlay for the painted plate. Window grids are locked
// to the art's cover-fit coordinate space (uCoverOffset/uCoverDrawn) — the SAME
// crop the master plate uses — and masked to the city / yacht silhouettes so
// lights land exactly on the painted structures at any viewport aspect. Drawn
// with BlendMode.plus. Uniform order MUST match CityLightsLayer.

uniform vec2 uResolution;
uniform float uTime;
uniform float uWindowAmount; // 0..1 fraction of windows lit
uniform float uFlicker;      // 0..1 flicker depth
uniform float uBeat;         // 0..1 musical pulse
uniform vec2 uCoverOffset;   // px: top-left of the cover-fit art in the viewport
uniform vec2 uCoverDrawn;    // px: cover-fit art size
uniform vec4 uWarm;          // sodium window
uniform vec4 uCool;          // LED window
uniform vec4 uYachtGlow;     // warm cabin
uniform sampler2D uCityMask;
uniform sampler2D uYachtMask;

out vec4 fragColor;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// One lit-window field over [grid] cells in art space.
float windowField(vec2 uv, vec2 grid, float amount, float time, float flicker,
    out float warmSel) {
  vec2 cell = floor(uv * grid);
  vec2 f = fract(uv * grid);
  float h = hash(cell);
  float wx = smoothstep(0.16, 0.32, f.x) * smoothstep(0.84, 0.68, f.x);
  float wy = smoothstep(0.18, 0.34, f.y) * smoothstep(0.82, 0.66, f.y);
  float lit = step(1.0 - amount, h);
  float flick =
      1.0 - flicker * (0.5 + 0.5 * sin(time * (0.6 + 1.8 * hash(cell + 5.0)) + h * 21.0));
  warmSel = step(hash(cell + 1.7), 0.8);
  return wx * wy * lit * flick;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  // Map the fragment into the art's normalized cover-fit space.
  vec2 muv = (frag - uCoverOffset) / uCoverDrawn;
  if (muv.x < 0.0 || muv.x > 1.0 || muv.y < 0.0 || muv.y > 1.0) {
    fragColor = vec4(0.0);
    return;
  }

  float cityA = texture(uCityMask, muv).a;
  float yachtA = texture(uYachtMask, muv).a;

  vec3 lights = vec3(0.0);
  float intensity = 0.0;

  // --- City windows (locked to the art, faded out at the waterline) ---
  float warmSel;
  float aboveWater = 1.0 - smoothstep(0.52, 0.60, muv.y);
  float cityWin =
      windowField(muv, vec2(230.0, 160.0), uWindowAmount, uTime, uFlicker, warmSel) *
      cityA * aboveWater;
  cityWin *= 0.55 * (0.85 + 0.3 * uBeat);
  lights += mix(uCool.rgb, uWarm.rgb, warmSel) * cityWin;
  intensity += cityWin;

  // --- Yacht: warm cabin windows + a soft overall cabin glow ---
  float ySel;
  float yachtWin =
      windowField(muv, vec2(150.0, 64.0), 0.4, uTime, uFlicker * 0.35, ySel) * yachtA;
  lights += uYachtGlow.rgb * yachtWin * (0.85 + 0.3 * uBeat);
  intensity += yachtWin;
  float cabin = yachtA * 0.06 * (0.85 + 0.3 * uBeat);
  lights += uYachtGlow.rgb * cabin;
  intensity += cabin;

  fragColor = vec4(lights, clamp(intensity, 0.0, 1.0));
}
