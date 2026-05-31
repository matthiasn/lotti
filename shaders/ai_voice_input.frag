#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uResolution;
uniform float uTime;
uniform float uDbfs;
uniform float uDbfsFloor;
uniform float uIntensity;
uniform float uLineDensity;
uniform float uOrbitalMix;
uniform float uVariant;
uniform vec4 uPrimaryColor;
uniform vec4 uSecondaryColor;
uniform vec4 uBackgroundColor;

out vec4 fragColor;

float saturate(float value) {
  return clamp(value, 0.0, 1.0);
}

float glow(float distanceToShape, float radius) {
  float safeRadius = max(radius, 0.0001);
  float normalized = distanceToShape / safeRadius;
  return exp(-normalized * normalized);
}

float ring(float radius, float target, float width) {
  return glow(abs(radius - target), width);
}

float angleDistance(float left, float right) {
  return abs(atan(sin(left - right), cos(left - right)));
}

float angularGlow(float angle, float center, float width) {
  return glow(angleDistance(angle, center), width);
}

float hash(vec2 point) {
  return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 point) {
  vec2 cell = floor(point);
  vec2 local = fract(point);
  vec2 eased = local * local * (3.0 - 2.0 * local);

  float a = hash(cell);
  float b = hash(cell + vec2(1.0, 0.0));
  float c = hash(cell + vec2(0.0, 1.0));
  float d = hash(cell + vec2(1.0, 1.0));

  return mix(mix(a, b, eased.x), mix(c, d, eased.x), eased.y);
}

float softMode(float angle, float time, float seed) {
  float a = sin(angle * 2.0 + time * 0.38 + seed) * 0.42;
  float b = sin(angle * 3.0 - time * 0.27 + seed * 1.7) * 0.30;
  float c = sin(angle * 4.0 + time * 0.19 - seed * 0.8) * 0.18;
  return a + b + c;
}

float pressureField(float angle, float time, float seed) {
  float centerA = time * 0.74 + seed;
  float centerB = -time * 0.51 + seed * 1.91 + 2.05;
  float centerC = time * 0.31 - seed * 0.62 - 2.36;

  float pushA = angularGlow(angle, centerA, 0.54);
  float pushB = angularGlow(angle, centerB, 0.42);
  float pullC = angularGlow(angle, centerC, 0.62);
  float traveling = angularGlow(angle, time * 1.12 + seed * 0.37, 0.18);

  return pushA * 1.05 + pushB * 0.62 - pullC * 0.52 + traveling * 0.26;
}

float contourOffset(float angle, float time, float level, float seed, float force) {
  float idle = 0.010 + 0.006 * sin(time * 0.17 + seed);
  float voice = level * level * 0.078;
  float field = pressureField(angle, time, seed);
  float modes = softMode(angle, time, seed) * 0.48;
  return (field + modes) * (idle + voice) * force;
}

float contourRadius(
    float angle,
    float time,
    float level,
    float baseRadius,
    float seed,
    float force) {
  return baseRadius + contourOffset(angle, time, level, seed, force);
}

float contourRing(
    float radius,
    float angle,
    float time,
    float level,
    float baseRadius,
    float width,
    float seed,
    float force) {
  float target = contourRadius(angle, time, level, baseRadius, seed, force);
  return ring(radius, target, width);
}

float contourAura(
    float radius,
    float angle,
    float time,
    float level,
    float baseRadius,
    float seed,
    float force) {
  float target = contourRadius(angle, time, level, baseRadius, seed, force);
  return ring(radius, target, 0.055 + level * 0.022);
}

float edgeTrace(
    float radius,
    float angle,
    float time,
    float level,
    float baseRadius,
    float seed,
    float force) {
  float target = contourRadius(angle, time, level, baseRadius, seed, force);
  float line = ring(radius, target, 0.004 + level * 0.003);
  float traceA = angularGlow(angle, time * 1.18 + seed * 0.74, 0.23);
  float traceB = angularGlow(angle, -time * 0.82 + seed * 1.33, 0.18);
  return line * (traceA + traceB * 0.72) * (0.32 + level * 0.92);
}

float delayedContour(
    float radius,
    float angle,
    float time,
    float level,
    float baseRadius,
    float width,
    float seed,
    float force,
    float delay) {
  return contourRing(
      radius,
      angle,
      time - delay,
      level,
      baseRadius,
      width,
      seed + delay,
      force);
}

vec4 compose(vec3 color, float alpha, float radius) {
  float crop = 1.0 - smoothstep(0.49, 0.59, radius);
  alpha = saturate(alpha * crop);
  alpha = alpha < 0.002 ? 0.0 : alpha;
  return vec4(color * alpha, alpha);
}

vec4 elasticMembrane(
    vec2 uv,
    float radius,
    float angle,
    float time,
    float level,
    float intensity,
    float force,
    vec3 primary,
    vec3 secondary,
    vec3 background,
    float backgroundAlpha) {
  float contour = contourRing(
      radius,
      angle,
      time,
      level,
      0.326 + level * 0.016,
      0.009 + level * 0.011,
      0.6,
      force);
  float innerShadow = contourRing(
      radius,
      angle,
      time * 0.82,
      level,
      0.274 - level * 0.010,
      0.010 + level * 0.006,
      2.1,
      force * 0.48);
  float pressureA = angularGlow(angle, time * 0.74 + 0.6, 0.50);
  float pressureB = angularGlow(angle, -time * 0.51 + 3.2, 0.44);
  float activeEdge = contour * (0.42 + pressureA * 0.86 + pressureB * 0.52);
  float delayedA = delayedContour(
      radius,
      angle,
      time,
      level,
      0.336 + level * 0.018,
      0.005 + level * 0.004,
      3.8,
      force * 0.62,
      0.58);
  float delayedB = delayedContour(
      radius,
      angle,
      time,
      level,
      0.288 - level * 0.006,
      0.006 + level * 0.004,
      5.5,
      force * 0.38,
      1.05);
  float trace = edgeTrace(radius, angle, time, level, 0.326, 6.4, force * 0.88);
  float aura = contourAura(radius, angle, time, level, 0.326, 0.6, force);
  float core = exp(-radius * radius * (72.0 - level * 16.0)) * (0.05 + level * 0.14);

  vec3 color = primary * (activeEdge * 1.28 + innerShadow * 0.34 + delayedA * 0.36);
  color += secondary * (contour * pressureA * 0.72 + delayedB * 0.32 + trace * 0.90 + core * 0.42);
  color += background * backgroundAlpha * aura * 0.12;

  float alpha = (activeEdge * 0.84 + innerShadow * 0.26 + aura * 0.12 +
      delayedA * 0.24 + delayedB * 0.18 + trace * 0.44 + core * 0.14) * intensity;
  return compose(color * intensity, alpha, radius);
}

vec4 impactRipples(
    vec2 uv,
    float radius,
    float angle,
    float time,
    float level,
    float intensity,
    float force,
    vec3 primary,
    vec3 secondary,
    vec3 background,
    float backgroundAlpha) {
  float forceAngle = time * 0.68 + 1.1;
  float hit = angularGlow(angle, forceAngle, 0.36);
  float counterHit = angularGlow(angle, forceAngle + 3.04, 0.58);
  float ringA = contourRing(
      radius,
      angle,
      time,
      level,
      0.300 + level * 0.018,
      0.012 + level * 0.009,
      1.4,
      force * 1.08);
  float ringB = contourRing(
      radius,
      angle,
      time * 0.76,
      level,
      0.358 + level * 0.028,
      0.006 + level * 0.005,
      3.7,
      force * 0.72);
  float ringC = contourRing(
      radius,
      angle,
      -time * 0.50,
      level,
      0.236 - level * 0.006,
      0.008 + level * 0.005,
      5.2,
      force * 0.48);
  float wake = (hit * ringA + counterHit * ringB) * (0.35 + level * 0.92);
  float shock = ring(radius, 0.416 + level * 0.030, 0.006 + level * 0.004) *
      angularGlow(angle, forceAngle - 0.35, 0.42) * (0.30 + level * 0.90);
  float trace = edgeTrace(radius, angle, time, level, 0.300, 0.7, force * 0.84);
  float after = delayedContour(
      radius,
      angle,
      time,
      level,
      0.334 + level * 0.012,
      0.005 + level * 0.004,
      4.6,
      force * 0.48,
      0.72);
  float aura = contourAura(radius, angle, time, level, 0.300, 1.4, force * 0.70);

  vec3 color = primary * (ringA * 0.92 + ringB * 0.46 + ringC * 0.26 + after * 0.34);
  color += secondary * (wake * 1.05 + ringC * hit * 0.56 + shock * 0.78 + trace * 0.74);
  color += background * backgroundAlpha * aura * 0.10;

  float alpha = (ringA * 0.66 + ringB * 0.34 + ringC * 0.20 +
      wake * 0.62 + shock * 0.46 + trace * 0.36 + after * 0.22 + aura * 0.10) * intensity;
  return compose(color * intensity, alpha, radius);
}

vec4 tensionLoop(
    vec2 uv,
    float radius,
    float angle,
    float time,
    float level,
    float intensity,
    float force,
    vec3 primary,
    vec3 secondary,
    vec3 background,
    float backgroundAlpha) {
  vec3 paleTeal = mix(primary, vec3(1.0), 0.34 + level * 0.10);
  vec3 hot = mix(primary, vec3(1.0), 0.76 + level * 0.18);
  vec3 whiteHot = mix(primary, vec3(1.0), 0.92);
  vec3 fineTeal = mix(primary, paleTeal, 0.18);
  float heatA = angularGlow(angle, time * 0.46 + 0.3, 0.42);
  float heatB = angularGlow(angle, -time * 0.34 - 2.2, 0.44);
  float heatC = angularGlow(angle, time * 0.25 + 2.8, 0.58);
  float heatD = angularGlow(angle, -time * 0.22 + 1.4, 0.50);
  float heatE = angularGlow(angle, time * 0.31 - 2.7, 0.46);
  float loopA = contourRing(
      radius,
      angle,
      time * 0.58,
      level,
      0.320,
      0.009 + level * 0.008,
      2.6,
      force * 0.92);
  float loopB = contourRing(
      radius,
      angle,
      -time * 0.43,
      level,
      0.322 + level * 0.018,
      0.010 + level * 0.009,
      4.0,
      force * 0.86);
  float loopC = contourRing(
      radius,
      angle,
      time * 0.36,
      level,
      0.382 + level * 0.014,
      0.007 + level * 0.006,
      7.4,
      force * 0.58);
  float loopD = contourRing(
      radius,
      angle,
      -time * 0.52,
      level,
      0.250 - level * 0.006,
      0.006 + level * 0.005,
      8.6,
      force * 0.50);
  float hotLoopA = contourRing(
      radius,
      angle,
      time * 0.50,
      level,
      0.332 + level * 0.010,
      0.018 + level * 0.014,
      0.9,
      force * 0.58);
  float hotLoopB = contourRing(
      radius,
      angle,
      -time * 0.38,
      level,
      0.304 - level * 0.006,
      0.015 + level * 0.010,
      5.7,
      force * 0.50);
  float hotLoopC = contourRing(
      radius,
      angle,
      time * 0.44,
      level,
      0.368 + level * 0.010,
      0.012 + level * 0.008,
      3.3,
      force * 0.42);
  float hotLoopD = contourRing(
      radius,
      angle,
      -time * 0.48,
      level,
      0.268 - level * 0.005,
      0.011 + level * 0.007,
      6.9,
      force * 0.38);
  float glowLoopA = contourRing(
      radius,
      angle,
      time * 0.46,
      level,
      0.334 + level * 0.012,
      0.040 + level * 0.020,
      0.9,
      force * 0.42);
  float glowLoopB = contourRing(
      radius,
      angle,
      -time * 0.32,
      level,
      0.304 - level * 0.006,
      0.034 + level * 0.018,
      5.7,
      force * 0.36);
  float glowLoopC = contourRing(
      radius,
      angle,
      time * 0.40,
      level,
      0.372 + level * 0.012,
      0.032 + level * 0.016,
      3.3,
      force * 0.30);
  float glowLoopD = contourRing(
      radius,
      angle,
      -time * 0.42,
      level,
      0.266 - level * 0.006,
      0.030 + level * 0.014,
      6.9,
      force * 0.28);
  float thinLoopA = contourRing(
      radius,
      angle,
      time * 0.82,
      level,
      0.354 + level * 0.010,
      0.0060 + level * 0.0038,
      7.1,
      force * 0.72);
  float thinLoopB = contourRing(
      radius,
      angle,
      -time * 0.68,
      level,
      0.284 - level * 0.004,
      0.0060 + level * 0.0038,
      1.6,
      force * 0.62);
  float thinLoopC = contourRing(
      radius,
      angle,
      time * 0.96,
      level,
      0.394 + level * 0.008,
      0.0056 + level * 0.0034,
      4.4,
      force * 0.52);
  float thinLoopD = contourRing(
      radius,
      angle,
      -time * 0.88,
      level,
      0.244 - level * 0.004,
      0.0056 + level * 0.0034,
      8.1,
      force * 0.46);
  float thinLoopE = contourRing(
      radius,
      angle,
      time * 1.10,
      level,
      0.336 + level * 0.007,
      0.0054 + level * 0.0032,
      9.5,
      force * 0.50);
  float thinLoopF = contourRing(
      radius,
      angle,
      -time * 0.98,
      level,
      0.306 - level * 0.004,
      0.0054 + level * 0.0032,
      2.9,
      force * 0.48);
  float thinLoopG = contourRing(
      radius,
      angle,
      time * 0.72,
      level,
      0.414 + level * 0.006,
      0.0050 + level * 0.0029,
      5.9,
      force * 0.38);
  float thinLoopH = contourRing(
      radius,
      angle,
      -time * 0.74,
      level,
      0.224 - level * 0.002,
      0.0050 + level * 0.0029,
      7.7,
      force * 0.36);
  float tensionA = angularGlow(angle, time * 0.36 + 0.3, 0.46);
  float tensionB = angularGlow(angle, -time * 0.27 - 2.2, 0.48);
  float overlap = min(loopA, loopB) * (0.65 + level * 0.76);
  float outerOverlap = min(loopC, loopA) * (0.42 + level * 0.54);
  float innerOverlap = min(loopD, loopB) * (0.38 + level * 0.48);
  float highlight = loopA * tensionA + loopB * tensionB +
      loopC * heatD * 0.62 + loopD * heatE * 0.58;
  float heat = hotLoopA * heatA + hotLoopB * heatB +
      hotLoopC * heatD + hotLoopD * heatE +
      overlap * heatC + outerOverlap * heatD + innerOverlap * heatE;
  float threadA = edgeTrace(radius, angle, time, level, 0.320, 5.2, force * 0.78);
  float threadB = edgeTrace(radius, angle, -time * 0.70, level, 0.344, 1.2, force * 0.62);
  float threadC = edgeTrace(radius, angle, time * 1.16, level, 0.286, 3.5, force * 0.58);
  float threadD = edgeTrace(radius, angle, -time * 1.04, level, 0.356, 6.0, force * 0.50);
  float ghost = delayedContour(
      radius,
      angle,
      time,
      level,
      0.302,
      0.006 + level * 0.004,
      6.7,
      force * 0.46,
      0.86);
  float ember = delayedContour(
      radius,
      angle,
      time,
      level,
      0.336 + level * 0.008,
      0.010 + level * 0.006,
      2.4,
      force * 0.36,
      1.18);
  float aura = contourAura(radius, angle, time, level, 0.321, 2.6, force * 0.52);

  vec3 color = primary * (
      threadA * 0.78 + threadB * 0.68 + threadC * 0.58 + threadD * 0.52 +
      ghost * 0.20);
  color += fineTeal * (thinLoopA * 1.02 + thinLoopB * 0.94 +
      thinLoopC * 0.74 + thinLoopD * 0.68 +
      thinLoopE * 0.78 + thinLoopF * 0.74 +
      thinLoopG * 0.52 + thinLoopH * 0.48);
  color += paleTeal * (loopA * 0.38 + loopB * 0.34 +
      loopC * 0.34 + loopD * 0.28 + highlight * 0.46);
  color += hot * (glowLoopA * heatA * 0.22 + glowLoopB * heatB * 0.18 +
      glowLoopC * heatD * 0.16 + glowLoopD * heatE * 0.14 +
      heat * 0.86 + overlap * 0.44 +
      outerOverlap * 0.30 + innerOverlap * 0.26 + ember * 0.28);
  color += whiteHot * (hotLoopA * heatA * 0.34 + hotLoopB * heatB * 0.30 +
      hotLoopC * heatD * 0.24 + hotLoopD * heatE * 0.22);
  color += background * backgroundAlpha * aura * 0.08;

  float alpha = (loopA * 0.32 + loopB * 0.30 + loopC * 0.24 + loopD * 0.22 +
      glowLoopA * heatA * 0.10 + glowLoopB * heatB * 0.09 +
      glowLoopC * heatD * 0.07 + glowLoopD * heatE * 0.06 +
      hotLoopA * heatA * 0.40 + hotLoopB * heatB * 0.36 +
      hotLoopC * heatD * 0.26 + hotLoopD * heatE * 0.24 +
      thinLoopA * 0.24 + thinLoopB * 0.22 +
      thinLoopC * 0.17 + thinLoopD * 0.16 +
      thinLoopE * 0.18 + thinLoopF * 0.17 +
      thinLoopG * 0.13 + thinLoopH * 0.12 +
      overlap * 0.56 + outerOverlap * 0.32 + innerOverlap * 0.28 +
      highlight * 0.36 + heat * 0.38 +
      threadA * 0.34 + threadB * 0.30 + threadC * 0.24 + threadD * 0.22 +
      ghost * 0.16 + ember * 0.20 + aura * 0.08) * intensity;
  return compose(color * intensity, alpha, radius);
}

vec4 liquidPulse(
    vec2 uv,
    float radius,
    float angle,
    float time,
    float level,
    float intensity,
    float force,
    vec3 primary,
    vec3 secondary,
    vec3 background,
    float backgroundAlpha) {
  float pulse = 0.5 + 0.5 * sin(time * 1.15);
  float mouthRadius = 0.300 + level * 0.042 + pulse * 0.010;
  float rim = contourRing(
      radius,
      angle,
      time * 0.66,
      level,
      mouthRadius,
      0.017 + level * 0.010,
      3.1,
      force * 1.00);
  float lip = contourRing(
      radius,
      angle,
      -time * 0.34,
      level,
      mouthRadius + 0.054 + level * 0.006,
      0.007 + level * 0.004,
      0.8,
      force * 0.54);
  float interior = contourRing(
      radius,
      angle,
      time * 0.45,
      level,
      mouthRadius - 0.058 - level * 0.012,
      0.010 + level * 0.005,
      5.1,
      force * 0.38);
  float glint = angularGlow(angle, time * 0.28 - 1.0, 0.34) * lip;
  float pressure = angularGlow(angle, -time * 0.25 + 2.2, 0.48) * rim;
  float surfaceTrace = edgeTrace(radius, angle, time, level, mouthRadius, 2.7, force * 0.74);
  float after = delayedContour(
      radius,
      angle,
      time,
      level,
      mouthRadius + 0.026,
      0.006 + level * 0.004,
      4.8,
      force * 0.50,
      0.64);
  float aura = contourAura(radius, angle, time, level, mouthRadius, 3.1, force * 0.55);

  vec3 color = primary * (rim * 0.90 + lip * 0.42 + pressure * 0.52 + after * 0.28);
  color += secondary * (glint * 1.08 + interior * 0.34 + surfaceTrace * 0.78);
  color += background * backgroundAlpha * aura * 0.10;

  float alpha = (rim * 0.66 + lip * 0.34 + interior * 0.20 +
      glint * 0.62 + pressure * 0.44 + surfaceTrace * 0.38 + after * 0.22 + aura * 0.09) * intensity;
  return compose(color * intensity, alpha, radius);
}

vec4 resonanceBraid(
    vec2 uv,
    float radius,
    float angle,
    float time,
    float level,
    float intensity,
    float force,
    vec3 primary,
    vec3 secondary,
    vec3 background,
    float backgroundAlpha) {
  float braidA = contourRing(
      radius,
      angle,
      time * 0.72,
      level,
      0.316,
      0.006 + level * 0.005,
      4.7,
      force * 1.02);
  float braidB = contourRing(
      radius,
      angle,
      time * 0.72 + 1.8,
      level,
      0.346 + level * 0.012,
      0.006 + level * 0.006,
      1.9,
      force * 0.88);
  float braidC = contourRing(
      radius,
      angle,
      -time * 0.52,
      level,
      0.276 - level * 0.006,
      0.005 + level * 0.004,
      6.2,
      force * 0.54);
  float phaseA = angularGlow(angle, time * 0.42 + 0.6, 0.42);
  float phaseB = angularGlow(angle, -time * 0.33 + 3.0, 0.40);
  float braid = braidA * (0.58 + phaseA * 0.82) +
      braidB * (0.46 + phaseB * 0.74) + braidC * 0.30;
  float traceA = edgeTrace(radius, angle, time, level, 0.316, 7.2, force * 0.86);
  float traceB = edgeTrace(radius, angle, -time * 0.64, level, 0.346, 2.8, force * 0.72);
  float delayed = delayedContour(
      radius,
      angle,
      time,
      level,
      0.304,
      0.005 + level * 0.004,
      5.6,
      force * 0.46,
      0.78);
  float aura = contourAura(radius, angle, time, level, 0.322, 4.7, force * 0.46);

  vec3 color = primary * (braid * 0.86 + braidC * 0.18 + delayed * 0.24);
  color += secondary * (braidA * phaseA * 0.62 + braidB * phaseB * 0.72 + traceA * 0.58 + traceB * 0.52);
  color += background * backgroundAlpha * aura * 0.08;

  float alpha = (braid * 0.62 + braidA * phaseA * 0.34 +
      braidB * phaseB * 0.34 + traceA * 0.30 + traceB * 0.28 + delayed * 0.18 + aura * 0.08) * intensity;
  return compose(color * intensity, alpha, radius);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  float scale = max(min(uResolution.x, uResolution.y), 1.0);
  vec2 uv = (fragCoord - 0.5 * uResolution) / scale;

  float radius = length(uv);
  float angle = atan(uv.y, uv.x);
  float dbfsFloor = min(uDbfsFloor, -0.001);
  float dbfsLevel = saturate((uDbfs - dbfsFloor) / abs(dbfsFloor));
  float level = smoothstep(0.02, 1.0, dbfsLevel);
  float intensity = saturate(uIntensity);
  float tension = saturate((uLineDensity - 8.0) / 26.0);
  float force = mix(0.82, 1.62, tension) * mix(0.84, 1.42, saturate(uOrbitalMix));
  float variant = floor(uVariant + 0.5);

  if (variant < 0.5) {
    fragColor = elasticMembrane(
        uv,
        radius,
        angle,
        uTime,
        level,
        intensity,
        force,
        uPrimaryColor.rgb,
        uSecondaryColor.rgb,
        uBackgroundColor.rgb,
        uBackgroundColor.a);
  } else if (variant < 1.5) {
    fragColor = impactRipples(
        uv,
        radius,
        angle,
        uTime,
        level,
        intensity,
        force,
        uPrimaryColor.rgb,
        uSecondaryColor.rgb,
        uBackgroundColor.rgb,
        uBackgroundColor.a);
  } else if (variant < 2.5) {
    fragColor = tensionLoop(
        uv,
        radius,
        angle,
        uTime,
        level,
        intensity,
        force,
        uPrimaryColor.rgb,
        uSecondaryColor.rgb,
        uBackgroundColor.rgb,
        uBackgroundColor.a);
  } else if (variant < 3.5) {
    fragColor = liquidPulse(
        uv,
        radius,
        angle,
        uTime,
        level,
        intensity,
        force,
        uPrimaryColor.rgb,
        uSecondaryColor.rgb,
        uBackgroundColor.rgb,
        uBackgroundColor.a);
  } else {
    fragColor = resonanceBraid(
        uv,
        radius,
        angle,
        uTime,
        level,
        intensity,
        force,
        uPrimaryColor.rgb,
        uSecondaryColor.rgb,
        uBackgroundColor.rgb,
        uBackgroundColor.a);
  }
}
