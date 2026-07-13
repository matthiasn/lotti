#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uResolution;
uniform float uTime;
uniform float uDbfs;
uniform float uDbfsFloor;
uniform float uIntensity;
uniform float uLineDensity;
uniform float uOrbitalMix;
uniform vec4 uPrimaryColor;
uniform vec4 uSecondaryColor;
uniform vec4 uBackgroundColor;

out vec4 fragColor;

float saturate(float value) {
  return clamp(value, 0.0, 1.0);
}

float filament(float distanceToContour, float width) {
  return 1.0 - smoothstep(0.0, width, abs(distanceToContour));
}

float boundedField(float value) {
  return clamp(value, -1.0, 1.0);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  float scale = max(min(uResolution.x, uResolution.y), 1.0);
  vec2 uv = (fragCoord - 0.5 * uResolution) / scale;
  float radius = length(uv);
  float angle = atan(uv.y, uv.x);
  float shapeAngle = angle - uTime * 0.07;
  float pixel = 1.0 / scale;

  float dbfsFloor = min(uDbfsFloor, -0.001);
  float dbfsLevel = saturate((uDbfs - dbfsFloor) / abs(dbfsFloor));
  float level = smoothstep(0.02, 1.0, dbfsLevel);
  float intensity = saturate(uIntensity);
  float tension = saturate((uLineDensity - 8.0) / 26.0);
  float orbital = saturate(uOrbitalMix);
  // The loop must remain visibly alive in silence. Voice adds force, but it
  // does not switch the shape from a dead circle to an active one.
  float deformation = mix(0.030, 0.118, level * level) *
      mix(0.88, 1.42, tension) * mix(0.90, 1.24, orbital);

  // Quadrature harmonic pairs are calculated once. A contour gets an
  // independent phase by rotating these shared sine/cosine bases with cheap
  // constant coefficients rather than evaluating another trigonometric field.
  float phaseA = shapeAngle * 2.0 + uTime * 0.45;
  float phaseB = shapeAngle * 3.0 - uTime * 0.39 + 1.3;
  float phaseC = shapeAngle * 4.0 + uTime * 0.31 - 0.7;
  float phaseD = shapeAngle * 5.0 - uTime * 0.57 + 2.1;
  float phaseE = shapeAngle * 7.0 + uTime * 0.36 - 1.8;
  vec4 harmonicsA = vec4(sin(phaseA), cos(phaseA),
      sin(phaseB), cos(phaseB));
  vec4 harmonicsB = vec4(sin(phaseC), cos(phaseC),
      sin(phaseD), cos(phaseD));
  vec2 harmonicsC = vec2(sin(phaseE), cos(phaseE));

  // Four compact pressure events: a broad slow push, a tight counter-pull,
  // and two weaker travelers. Explicit multiply chains avoid pow/exp and are
  // predictable on the affected virtualized Linux graphics stack.
  float broadWave = 0.5 + 0.5 * cos(angle - uTime * 0.34 - 0.4);
  float broad = broadWave * broadWave;
  float tightWave = 0.5 + 0.5 * cos(angle + uTime * 0.82 + 2.2);
  float tight2 = tightWave * tightWave;
  float tight4 = tight2 * tight2;
  float tight = tight4 * tight4;
  float travelWave = 0.5 + 0.5 * cos(angle - uTime * 0.68 + 2.7);
  float travel2 = travelWave * travelWave;
  float travel = travel2 * travel2;
  float echoWave = 0.5 + 0.5 * cos(angle + uTime * 0.51 - 1.1);
  float echo2 = echoWave * echoWave;
  float echo = echo2 * echo2 * echo2;
  vec4 pressure = vec4(broad, tight, travel, echo);

  float heroFieldA = boundedField(
      dot(harmonicsA, vec4(0.30, 0.08, 0.18, -0.12)) +
      dot(harmonicsB, vec4(0.12, 0.06, -0.08, 0.04)) +
      dot(harmonicsC, vec2(0.06, -0.04)) +
      dot(pressure, vec4(0.34, -0.22, 0.16, -0.10)));
  float heroFieldB = boundedField(
      dot(harmonicsA, vec4(-0.14, 0.24, 0.08, 0.20)) +
      dot(harmonicsB, vec4(-0.10, 0.14, 0.06, -0.08)) +
      dot(harmonicsC, vec2(-0.05, 0.07)) +
      dot(pressure, vec4(-0.24, 0.32, -0.12, 0.18)));
  float secondaryFieldA = boundedField(
      dot(harmonicsA, vec4(0.10, -0.20, 0.22, 0.04)) +
      dot(harmonicsB, vec4(0.14, -0.08, 0.08, 0.10)) +
      dot(harmonicsC, vec2(0.08, 0.04)) +
      dot(pressure, vec4(0.16, 0.08, -0.24, 0.12)));
  float secondaryFieldB = boundedField(
      dot(harmonicsA, vec4(-0.22, -0.06, 0.10, -0.16)) +
      dot(harmonicsB, vec4(0.04, 0.18, -0.10, 0.08)) +
      dot(harmonicsC, vec2(-0.06, -0.08)) +
      dot(pressure, vec4(-0.10, -0.18, 0.28, -0.12)));
  float secondaryFieldC = boundedField(
      dot(harmonicsA, vec4(0.16, 0.12, -0.14, 0.18)) +
      dot(harmonicsB, vec4(-0.16, 0.06, 0.12, 0.04)) +
      dot(harmonicsC, vec2(0.04, -0.10)) +
      dot(pressure, vec4(0.12, -0.10, 0.08, 0.22)));
  float secondaryFieldD = boundedField(
      dot(harmonicsA, vec4(-0.08, 0.18, -0.20, -0.04)) +
      dot(harmonicsB, vec4(0.10, 0.12, 0.04, -0.16)) +
      dot(harmonicsC, vec2(0.10, 0.04)) +
      dot(pressure, vec4(-0.16, 0.14, -0.08, 0.20)));

  // Hairlines reuse the independent fields with phase-lagged cross-mixes.
  float hairFieldA = boundedField(heroFieldA * 0.42 +
      secondaryFieldB * 0.58 + harmonicsC.y * 0.18);
  float hairFieldB = boundedField(heroFieldB * 0.38 +
      secondaryFieldA * 0.62 - harmonicsB.x * 0.16);
  float hairFieldC = boundedField(secondaryFieldC * 0.54 -
      heroFieldA * 0.30 + harmonicsA.w * 0.20);
  float hairFieldD = boundedField(secondaryFieldD * 0.56 -
      heroFieldB * 0.28 - harmonicsA.x * 0.18);
  float hairFieldE = boundedField(secondaryFieldA * 0.44 +
      secondaryFieldD * 0.40 + harmonicsB.w * 0.18);
  float hairFieldF = boundedField(secondaryFieldB * 0.46 +
      secondaryFieldC * 0.38 - harmonicsC.x * 0.20);

  float heroDistanceA = radius - (0.316 + deformation * heroFieldA);
  float heroDistanceB = radius -
      (0.336 + level * 0.006 + deformation * 0.94 * heroFieldB);
  // Keep the supporting filaments close enough to read as one energy ring.
  // Their independent fields still cross and breathe, but the base radii are
  // compressed toward the two hero contours instead of filling the whole orb.
  float secondaryDistanceA = radius -
      (0.370 + level * 0.006 + deformation * 0.66 * secondaryFieldA);
  float secondaryDistanceB = radius -
      (0.267 - level * 0.006 + deformation * 0.80 * secondaryFieldB);
  float secondaryDistanceC = radius -
      (0.350 + deformation * 0.70 * secondaryFieldC);
  float secondaryDistanceD = radius -
      (0.296 + deformation * 0.66 * secondaryFieldD);
  float hairDistanceA = radius - (0.387 + deformation * 0.49 * hairFieldA);
  float hairDistanceB = radius - (0.250 + deformation * 0.66 * hairFieldB);
  float hairDistanceC = radius - (0.363 + deformation * 0.53 * hairFieldC);
  float hairDistanceD = radius - (0.282 + deformation * 0.49 * hairFieldD);
  float hairDistanceE = radius - (0.340 + deformation * 0.57 * hairFieldE);
  float hairDistanceF = radius - (0.308 + deformation * 0.55 * hairFieldF);

  float heroWidth = max(0.0120 + level * 0.0030, pixel * 1.44);
  float secondaryWidth = max(0.0064 + level * 0.0012, pixel * 0.82);
  float hairWidth = max(0.0036 + level * 0.0006, pixel * 0.54);
  float heroA = filament(heroDistanceA, heroWidth);
  float heroB = filament(heroDistanceB, heroWidth * 0.94);
  float secondaryA = filament(secondaryDistanceA, secondaryWidth);
  float secondaryB = filament(secondaryDistanceB, secondaryWidth * 0.94);
  float secondaryC = filament(secondaryDistanceC, secondaryWidth * 0.90);
  float secondaryD = filament(secondaryDistanceD, secondaryWidth * 0.88);
  float hairA = filament(hairDistanceA, hairWidth * 0.88);
  float hairB = filament(hairDistanceB, hairWidth * 0.84);
  float hairC = filament(hairDistanceC, hairWidth * 0.78);
  float hairD = filament(hairDistanceD, hairWidth * 0.76);
  float hairE = filament(hairDistanceE, hairWidth * 0.72);
  float hairF = filament(hairDistanceF, hairWidth * 0.70);

  // Geometry is reused for halos instead of recomputing another contour.
  float heroHaloA = filament(heroDistanceA, heroWidth * 5.8);
  float heroHaloB = filament(heroDistanceB, heroWidth * 5.4);
  float outerHalo = filament(secondaryDistanceA, secondaryWidth * 6.2);
  float innerHalo = filament(secondaryDistanceB, secondaryWidth * 5.8);
  float hotRibbonA = filament(heroDistanceB, heroWidth * 3.0);
  float hotRibbonB = filament(secondaryDistanceC, secondaryWidth * 4.0);
  float heroMask = max(heroA, heroB);
  float secondaryMask = max(max(secondaryA, secondaryB),
      max(secondaryC, secondaryD));
  float hairMask = max(
      max(max(hairA * 0.92, hairB * 0.82),
          max(hairC * 0.72, hairD * 0.64)),
      max(hairE * 0.56, hairF * 0.48));
  float haloMask = max(
      max(heroHaloA, heroHaloB),
      max(outerHalo * 0.78, innerHalo * 0.66));
  float crossingMask = max(
      max(min(heroHaloA, heroB), min(heroA, heroHaloB)),
      max(min(heroHaloA, secondaryC), min(heroHaloB, secondaryD)));

  // The four pressure events double as travelling light sources. Most of the
  // structure stays teal; two broader high-emphasis ribbons bloom only where
  // pressure passes through them, restoring depth without a white wash.
  float heroEnergy = saturate(0.66 + broad * 0.30 + travel * 0.18);
  float secondaryEnergy = saturate(0.54 + tight * 0.34 + echo * 0.20);
  float hairEnergy = saturate(0.42 + travel * 0.24 + echo * 0.18);
  float heroAlpha = heroMask * mix(0.90, 1.00, level) * heroEnergy;
  float secondaryAlpha = secondaryMask * 0.72 * secondaryEnergy;
  float hairAlpha = hairMask * 0.50 * hairEnergy;
  float haloAlpha = haloMask * mix(0.16, 0.30, level);
  float glintAlpha = crossingMask * mix(0.48, 0.92, level);
  // The broad ribbons stay quiet until a pressure lobe reaches them. This
  // produces a few thick, soft white blooms instead of tinting every contour
  // toward mint at all times.
  float hotRibbonAlpha = max(
      hotRibbonA * (tight * 0.44 + broad * 0.16),
      hotRibbonB * (travel * 0.40 + echo * 0.14));
  float alphaUnion = 1.0 -
      (1.0 - heroAlpha) * (1.0 - secondaryAlpha) *
      (1.0 - hairAlpha) * (1.0 - haloAlpha) *
      (1.0 - glintAlpha) * (1.0 - hotRibbonAlpha);

  vec3 atmosphere = uPrimaryColor.rgb * 0.72;
  vec3 bodyPrimary = uPrimaryColor.rgb;
  vec3 energizedEdge = mix(uPrimaryColor.rgb, uSecondaryColor.rgb, 0.15);
  vec3 crossingGlint = mix(uPrimaryColor.rgb, uSecondaryColor.rgb, 0.54);
  float deepWeight = haloAlpha * 0.92;
  float bodyWeight = heroAlpha + secondaryAlpha * 0.72 + hairAlpha * 0.28;
  float edgeWeight = secondaryAlpha * 0.28 + hairAlpha * 0.72;
  float glintWeight = glintAlpha * 0.92;
  float hotRibbonWeight = hotRibbonAlpha * 1.04;
  float colorWeight = max(
      deepWeight + bodyWeight + edgeWeight + glintWeight + hotRibbonWeight,
      0.0001);
  vec3 hue = (atmosphere * deepWeight + bodyPrimary * bodyWeight +
      energizedEdge * edgeWeight + crossingGlint * glintWeight +
      uSecondaryColor.rgb * hotRibbonWeight) / colorWeight;
  float whiteBloom = saturate(
      hotRibbonAlpha * mix(1.10, 1.45, level) + glintAlpha * 0.08);
  hue = mix(hue, uSecondaryColor.rgb, whiteBloom * 0.78);

  float crop = 1.0 - smoothstep(0.485, 0.555, radius);
  float alpha = saturate(alphaUnion * intensity * crop);
  alpha = alpha < 0.002 ? 0.0 : alpha;
  vec3 premultiplied = min(hue * alpha, vec3(alpha));
  fragColor = vec4(premultiplied, alpha);
}
