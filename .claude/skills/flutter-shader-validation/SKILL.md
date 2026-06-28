---
name: flutter-shader-validation
description: "Diagnose and verify Flutter runtime-effect shader changes, including Impeller RuntimeStage/GLES compile errors, FragmentProgram asset loading, shader-vs-fallback rendering, and GLSL linter questions. Use when editing shaders/*.frag, seeing impellerc failures, adding scenery shaders, or deciding whether glslang/glslc can catch a shader bug."
---

# Flutter Shader Validation

Flutter runtime shaders are validated by Flutter's own shader compiler and
runtime-effect loading path. Generic GLSL tools can help with syntax, but they
do not fully understand Flutter's shader prelude, `FlutterFragCoord`, generated
uniform layout, or Impeller backend constraints.

## Authoritative Checks

For scenery shaders, run the shader compile test first:

```bash
fvm flutter test test/features/scenery/runtime/scenery_shaders_test.dart
```

For related code, add targeted analyzer/test runs:

```bash
fvm flutter analyze lib/features/scenery shaders
fvm flutter test test/features/scenery/runtime/scenery_shaders_test.dart \
  test/features/scenery/model/backdrop_scene_test.dart
```

If `fvm flutter run` fails with `ShaderCompilerException`, reproduce with the
targeted shader test before changing unrelated code.

## Diagnostic Loop

1. Read the exact compiler error, line number, and backend target
   (`RuntimeStageGLES`, Impeller, etc.).
2. Open the shader around the failing line and the helper function definitions.
3. Check overload signatures exactly. Flutter's shader compiler will not forgive
   mismatched `float`/`vec2`/`vec3` helper calls.
4. Prefer explicit casts and overloads. Avoid relying on implicit int-to-float
   behavior.
5. Keep helper functions defined before use when possible. It makes errors
   clearer and avoids backend quirks.
6. Rerun the shader test. Do not call it fixed until the runtime-effect compiler
   accepts the file.

## Common Failure Modes

- **`no matching overloaded function found`:** call arguments do not match the
  helper signature. Add the needed overload or fix the call site.
- **Works in a generic GLSL linter but fails in Flutter:** the linter is not the
  authority. Flutter runtime effects have their own subset and generated wrapper.
- **Renders but not through the intended shader:** the widget may have fallen
  back to CPU/canvas rendering. Use a render-path A/B test or
  `cinematic-render-panel` guidance to verify shader vs fallback pixels.
- **Looks unchanged after shader edits:** hot restart may be needed; shader
  assets can be cached during a running Flutter app.

## Optional Generic Linters

These tools are useful as a cheap preflight, not as proof:

```bash
sudo apt-get install -y glslang-tools glslc
```

Use them only when they can be wrapped to approximate Flutter's shader prelude.
Even then, final verification is still `fvm flutter test` or `fvm flutter run`
through the real Flutter compiler.

## Visual Validation

Compile success is not enough for art shaders. Render the real production scene
at two times, inspect the pixels, and compare against a forced fallback when
fallback confusion is possible. Use `scenery-art-layer-prep` for asset/layer
issues and `cinematic-render-panel` for art-quality review.
