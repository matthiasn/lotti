#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uResolution;
uniform float uTime;
uniform float uAmplitude;
uniform float uSpeed;
uniform float uRandomness;
uniform float uLineCount;
uniform float uPulse;
uniform float uVariant;
uniform vec4 uPrimaryColor;
uniform vec4 uSecondaryColor;
uniform vec4 uBackgroundColor;

out vec4 fragColor;

float saturate(float value) {
  return clamp(value, 0.0, 1.0);
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

float glow(float distanceToShape, float radius) {
  float safeRadius = max(radius, 0.0001);
  float normalized = distanceToShape / safeRadius;
  return exp(-normalized * normalized);
}

float lineGlow(float y, float target, float width) {
  return glow(abs(y - target), width);
}

float box(vec2 uv, vec2 center, vec2 halfSize) {
  vec2 distanceToEdge = abs(uv - center) - halfSize;
  float outside = length(max(distanceToEdge, 0.0));
  float inside = min(max(distanceToEdge.x, distanceToEdge.y), 0.0);
  return outside + inside;
}

vec4 compose(vec3 color, float alpha) {
  return vec4(color, saturate(alpha));
}

vec4 quietThread(
    vec2 uv,
    float time,
    float amplitude,
    float randomness,
    float activeCount,
    float pulse,
    vec3 primary,
    vec3 secondary,
    vec3 background,
    float backgroundAlpha) {
  float centeredY = uv.y - 0.5;
  vec3 color = background * backgroundAlpha * 0.42;
  float alpha = backgroundAlpha * exp(-centeredY * centeredY * 18.0);
  float accumulated = 0.0;

  for (int i = 0; i < 6; i++) {
    float layer = float(i);
    float activeLayer = step(layer, activeCount - 0.5);
    float lineOffset = (layer - (activeCount - 1.0) * 0.5) * 0.045;
    float layerNoise = noise(vec2(
      uv.x * (3.0 + layer * 0.7) + layer * 17.0,
      time * (0.35 + layer * 0.08)
    ));
    float lowWave = sin(
      uv.x * (5.0 + layer * 0.8) +
      time * (0.80 + layer * 0.17) +
      layer * 1.8
    );
    float highWave = sin(
      uv.x * (19.0 + layer * 2.0) -
      time * (1.10 + layer * 0.13)
    );
    float lineY =
        0.5 +
        lineOffset +
        amplitude *
            (lowWave * 0.040 +
                highWave * 0.012 * randomness +
                (layerNoise - 0.5) * 0.055 * randomness);
    float line = lineGlow(uv.y, lineY, 0.006 + 0.006 * amplitude);
    float broken = smoothstep(
      0.18,
      0.82,
      noise(vec2(uv.x * 38.0 + layer * 13.0, floor(time * 8.0) * 0.19 + layer))
    );
    float sweep = exp(
      -pow((fract(uv.x - time * (0.080 + layer * 0.010) + layer * 0.190) -
              0.5) /
              0.080,
          2.0)
    );
    float envelope =
        smoothstep(0.00, 0.06, uv.x) * (1.0 - smoothstep(0.94, 1.00, uv.x));
    float energy =
        line * envelope * activeLayer * (0.38 + 0.62 * broken) *
        (0.72 + 0.45 * sweep * pulse);

    vec3 lineColor = mix(primary, secondary, saturate(layer / 5.0));
    color += lineColor * energy;
    accumulated += energy;
  }

  float centreGlow = exp(-centeredY * centeredY * 48.0) *
      (0.04 + 0.05 * sin(time * 1.7 + uv.x * 9.0));
  color += mix(primary, secondary, uv.x) * centreGlow;
  alpha = saturate(alpha + accumulated * 0.56 + centreGlow * 0.48);
  return compose(color, alpha);
}

vec4 packetScan(
    vec2 uv,
    float time,
    float amplitude,
    float randomness,
    float pulse,
    vec3 primary,
    vec3 secondary,
    vec3 background,
    float backgroundAlpha) {
  float center = 0.5 + sin(time * 0.55) * 0.018 * amplitude;
  float rail = lineGlow(uv.y, center, 0.006);
  float ghost = lineGlow(uv.y, center + 0.065, 0.004) +
      lineGlow(uv.y, center - 0.065, 0.004);
  float packets = 0.0;

  for (int i = 0; i < 8; i++) {
    float index = float(i);
    float x = fract(time * (0.09 + index * 0.004) + index * 0.137);
    float width = 0.020 + 0.018 * noise(vec2(index, floor(time * 2.0)));
    float y = center + (noise(vec2(index * 2.0, time * 0.25)) - 0.5) *
        amplitude *
        randomness *
        0.050;
    float packet = exp(-pow((uv.x - x) / width, 2.0)) *
        lineGlow(uv.y, y, 0.012 + amplitude * 0.005);
    packets += packet;
  }

  float envelope =
      smoothstep(0.00, 0.05, uv.x) * (1.0 - smoothstep(0.95, 1.00, uv.x));
  float scan = exp(-pow((fract(uv.x - time * 0.12) - 0.5) / 0.10, 2.0));
  vec3 color = background * backgroundAlpha * 0.38;
  color += primary * (rail * 0.46 + packets * (0.38 + pulse * 0.35));
  color += secondary * (ghost * 0.24 + scan * rail * 0.44);
  float alpha = backgroundAlpha * lineGlow(uv.y, center, 0.16) +
      (rail * 0.42 + ghost * 0.20 + packets * 0.48 + scan * rail * 0.35) *
          envelope;
  return compose(color, alpha);
}

vec4 circuitTrace(
    vec2 uv,
    float time,
    float amplitude,
    float randomness,
    float activeCount,
    vec3 primary,
    vec3 secondary,
    vec3 background,
    float backgroundAlpha) {
  vec3 color = background * backgroundAlpha * 0.34;
  float alpha = backgroundAlpha * exp(-pow((uv.y - 0.5) / 0.30, 2.0));
  float energy = 0.0;

  for (int i = 0; i < 6; i++) {
    float layer = float(i);
    float activeLayer = step(layer, activeCount - 0.5);
    float row = 0.5 + (layer - (activeCount - 1.0) * 0.5) * 0.060;
    float cell = floor(uv.x * 14.0 + layer * 3.0);
    float lane = row + (hash(vec2(cell, layer)) - 0.5) *
        amplitude *
        randomness *
        0.080;
    float horizontal = lineGlow(uv.y, lane, 0.005);
    float joints = pow(0.5 + 0.5 * cos(uv.x * 87.0 + layer), 18.0) *
        horizontal;
    float verticalGate = pow(0.5 + 0.5 * cos(uv.x * 44.0 + layer * 1.7), 28.0);
    float vertical = verticalGate *
        smoothstep(0.00, 0.14 + amplitude * 0.10, abs(uv.y - row)) *
        (1.0 - smoothstep(0.16 + amplitude * 0.12, 0.24, abs(uv.y - row)));
    float sweep = exp(
      -pow((fract(uv.x - time * (0.070 + layer * 0.007) + layer * 0.111) -
              0.5) /
              0.070,
          2.0)
    );
    float layerEnergy = activeLayer * (horizontal * 0.42 + joints * 0.50 +
        vertical * 0.12) * (0.55 + sweep * 0.75);
    color += mix(primary, secondary, layer / 5.0) * layerEnergy;
    energy += layerEnergy;
  }

  return compose(color, alpha + energy * 0.58);
}

vec4 probabilityBand(
    vec2 uv,
    float time,
    float amplitude,
    float randomness,
    vec3 primary,
    vec3 secondary,
    vec3 background,
    float backgroundAlpha) {
  float centeredY = uv.y - 0.5;
  float bandNoise = noise(vec2(uv.x * 5.0 - time * 0.35, time * 0.18));
  float bandWidth = 0.060 + amplitude * 0.055 + bandNoise * randomness * 0.030;
  float band = exp(-(centeredY * centeredY) / (bandWidth * bandWidth));
  float upper = lineGlow(uv.y, 0.5 + bandWidth * 0.75, 0.004 + amplitude * 0.004);
  float lower = lineGlow(uv.y, 0.5 - bandWidth * 0.75, 0.004 + amplitude * 0.004);
  float median = lineGlow(
    uv.y,
    0.5 + sin(uv.x * 7.0 + time * 0.8) * amplitude * 0.020,
    0.005
  );
  float grain = noise(vec2(uv.x * 80.0, uv.y * 20.0 + time * 2.0));
  float scan = exp(-pow((fract(uv.x - time * 0.09) - 0.5) / 0.16, 2.0));

  vec3 color = background * backgroundAlpha * 0.42;
  color += mix(primary, secondary, uv.x) * band * (0.14 + grain * 0.16);
  color += primary * (upper + lower) * 0.38;
  color += secondary * (median * 0.50 + scan * band * 0.18);
  float alpha = backgroundAlpha * band * 0.44 +
      band * (0.18 + grain * 0.12) + (upper + lower) * 0.30 + median * 0.42;
  return compose(color, alpha);
}

vec4 decoderBars(
    vec2 uv,
    float time,
    float amplitude,
    float randomness,
    float pulse,
    vec3 primary,
    vec3 secondary,
    vec3 background,
    float backgroundAlpha) {
  vec3 color = background * backgroundAlpha * 0.34;
  float alpha = backgroundAlpha * exp(-pow((uv.y - 0.5) / 0.32, 2.0));
  float bars = 0.0;
  float lit = 0.0;

  for (int i = 0; i < 36; i++) {
    float index = float(i);
    float x = (index + 0.5) / 36.0;
    float randomHeight = noise(vec2(index * 0.37, floor(time * 9.0) * 0.11));
    float height = 0.045 + amplitude * (0.10 + randomHeight * 0.16 * randomness);
    float width = 0.0045;
    float barShape = 1.0 - smoothstep(0.0, 0.008, box(uv, vec2(x, 0.5), vec2(width, height)));
    float cursor = exp(-pow((fract(x - time * 0.13) - 0.5) / 0.13, 2.0));
    bars += barShape * (0.42 + cursor * (0.45 + pulse * 0.35));
    lit += barShape * cursor;
  }

  float rail = lineGlow(uv.y, 0.5, 0.003);
  color += primary * (bars * 0.22 + rail * 0.34);
  color += secondary * lit * 0.35;
  alpha += bars * 0.34 + lit * 0.30 + rail * 0.25;
  return compose(color, alpha);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / max(uResolution, vec2(1.0));
  float amplitude = saturate(uAmplitude);
  float randomness = saturate(uRandomness);
  float pulse = saturate(uPulse);
  float time = uTime * max(uSpeed, 0.0);
  float activeCount = clamp(floor(uLineCount + 0.5), 1.0, 6.0);
  float variant = floor(uVariant + 0.5);

  if (variant < 0.5) {
    fragColor = quietThread(
        uv,
        time,
        amplitude,
        randomness,
        activeCount,
        pulse,
        uPrimaryColor.rgb,
        uSecondaryColor.rgb,
        uBackgroundColor.rgb,
        uBackgroundColor.a);
  } else if (variant < 1.5) {
    fragColor = packetScan(
        uv,
        time,
        amplitude,
        randomness,
        pulse,
        uPrimaryColor.rgb,
        uSecondaryColor.rgb,
        uBackgroundColor.rgb,
        uBackgroundColor.a);
  } else if (variant < 2.5) {
    fragColor = circuitTrace(
        uv,
        time,
        amplitude,
        randomness,
        activeCount,
        uPrimaryColor.rgb,
        uSecondaryColor.rgb,
        uBackgroundColor.rgb,
        uBackgroundColor.a);
  } else if (variant < 3.5) {
    fragColor = probabilityBand(
        uv,
        time,
        amplitude,
        randomness,
        uPrimaryColor.rgb,
        uSecondaryColor.rgb,
        uBackgroundColor.rgb,
        uBackgroundColor.a);
  } else {
    fragColor = decoderBars(
        uv,
        time,
        amplitude,
        randomness,
        pulse,
        uPrimaryColor.rgb,
        uSecondaryColor.rgb,
        uBackgroundColor.rgb,
        uBackgroundColor.a);
  }
}
