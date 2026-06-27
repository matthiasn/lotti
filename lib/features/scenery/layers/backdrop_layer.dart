import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';
import 'package:lotti/features/scenery/model/skyline_manifest.dart';

/// Everything a [BackdropLayer] needs to paint one frame. Carries the live
/// clock + the lazily-loaded GPU/image resources; any of the resource fields
/// may be null before its async load resolves, in which case a layer renders
/// its CPU fallback (or skips).
class BackdropContext {
  const BackdropContext({
    required this.size,
    required this.timeSeconds,
    required this.palette,
    this.reducedMotion = false,
    this.beatPulse = 0,
    this.skyProgram,
    this.oceanProgram,
    this.images = const {},
    this.manifest,
  });

  /// Pixel size of the backdrop.
  final Size size;

  /// Scene clock in seconds (the audio/dance position when injected).
  final double timeSeconds;

  /// Color source of truth for the whole scene.
  final BackdropPalette palette;

  /// When true the scene is held on a calm static frame (OS reduce-motion).
  final bool reducedMotion;

  /// 0..1 musical-beat intensity for elements that pulse with the track.
  final double beatPulse;

  /// Compiled sky shader program (null until loaded → CPU fallback).
  final ui.FragmentProgram? skyProgram;

  /// Compiled ocean shader program (null until loaded → CPU fallback).
  final ui.FragmentProgram? oceanProgram;

  /// Decoded bitmap layers keyed by asset basename (e.g. `skyline_near`).
  final Map<String, ui.Image> images;

  /// Light/window anchor geometry for the props layer.
  final SkylineManifest? manifest;
}

/// One painted layer in the back-to-front `BackdropScene` stack. Stateless
/// given a [BackdropContext]; any cross-frame caching lives in the owning
/// widget, never in the layer.
// A strategy interface with several implementations (sky, bitmap, ocean,
// props), not a single-use callback.
// ignore: one_member_abstracts
abstract interface class BackdropLayer {
  void paint(Canvas canvas, BackdropContext ctx);
}
