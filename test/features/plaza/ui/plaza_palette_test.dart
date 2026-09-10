import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/ui/plaza_palette.dart';
import 'package:material_ui/material_ui.dart';

PlazaTask _task(PlazaTaskState state, {int color = 0xFF3366FF}) => PlazaTask(
  id: 'palette-${state.name}',
  createdAt: DateTime.utc(2026, 7),
  title: 'Palette probe',
  state: state,
  progress: 0,
  checklistItems: 0,
  linkedTaskIds: const [],
  categoryColor: color,
);

/// Perceived brightness, so "daylight is lighter than night" can be asserted
/// on a colour rather than eyeballed.
double _luminance(Color color) =>
    0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;

/// The states that are lights at night: everything except the unlit
/// fixture, which is exempt from the legibility rules on purpose.
const _liveStates = <LanternState>[
  LanternState.blocked,
  LanternState.overdue,
  LanternState.inProgress,
  LanternState.open,
];

void main() {
  final now = DateTime.utc(2026, 7, 15);

  group('PlazaSkyMode', () {
    test('PLAZA_DAY=1 boots the fixture into daylight', () {
      expect(
        PlazaSkyMode.fromEnvironment({'PLAZA_DAY': '1'}),
        PlazaSkyMode.day,
      );
    });

    test('any other environment stays at night', () {
      expect(PlazaSkyMode.fromEnvironment(const {}), PlazaSkyMode.night);
      expect(
        PlazaSkyMode.fromEnvironment({'PLAZA_DAY': '0'}),
        PlazaSkyMode.night,
      );
      expect(
        PlazaSkyMode.fromEnvironment({'PLAZA_DAY': 'true'}),
        PlazaSkyMode.night,
        reason: 'only the literal 1 opts in, as with the other PLAZA_ knobs',
      );
    });

    test('a stored name round-trips', () {
      for (final mode in PlazaSkyMode.values) {
        expect(PlazaSkyMode.fromName(mode.name), mode);
      }
    });

    test('a missing or unreadable preference falls back to night', () {
      expect(PlazaSkyMode.fromName(null), PlazaSkyMode.night);
      expect(PlazaSkyMode.fromName(''), PlazaSkyMode.night);
      expect(PlazaSkyMode.fromName('dusk'), PlazaSkyMode.night);
    });
  });

  group('PlazaSky', () {
    test('night has no sun; day does', () {
      expect(PlazaPalette.night.sky.hasSun, isFalse);
      expect(PlazaPalette.day.sky.hasSun, isTrue);
    });

    test('the sun direction is a unit vector at its stated azimuth', () {
      final sky = PlazaPalette.day.sky;
      final direction = sky.sunDirection;
      final length = math.sqrt(
        direction.x * direction.x +
            direction.y * direction.y +
            direction.z * direction.z,
      );
      expect(length, closeTo(1, 1e-12));
      expect(direction.y, closeTo(math.sin(sky.sunElevation), 1e-12));
      // atan2 answers in (-pi, pi]; an azimuth past half a turn is the
      // same bearing, so compare them on the circle.
      expect(
        math.atan2(direction.x, direction.z) % (2 * math.pi),
        closeTo(sky.sunAzimuth % (2 * math.pi), 1e-12),
      );
    });

    test('the sun stands above the horizon and off the street axis', () {
      final sky = PlazaPalette.day.sky;
      expect(
        sky.sunElevation,
        inInclusiveRange(math.pi / 8, math.pi / 2 - math.pi / 12),
        reason:
            'a sun at the zenith leaves no shadow, one at the horizon '
            'leaves nothing but shadow',
      );
      expect(sky.sunDirection.y, greaterThan(0));
    });

    test('a night wall casts nothing, whatever its height', () {
      expect(PlazaPalette.night.sky.shadowLength(1), 0);
      expect(PlazaPalette.night.sky.shadowLength(80), 0);
    });

    test('a daylight shadow grows with the wall until it is clamped', () {
      final sky = PlazaPalette.day.sky;
      final low = sky.shadowLength(4);
      final tall = sky.shadowLength(12);
      expect(low, greaterThan(0));
      expect(tall, greaterThan(low));
      expect(low, closeTo(4 / math.tan(sky.sunElevation), 1e-9));
    });

    test('a tower does not drag its shadow across the district', () {
      final sky = PlazaPalette.day.sky;
      expect(sky.shadowLength(400), PlazaSky.maxShadowLength);
      expect(
        sky.shadowLength(400),
        greaterThanOrEqualTo(sky.shadowLength(40)),
        reason: 'the clamp is a ceiling, never a reversal',
      );
    });

    test('a sun on the horizon clamps instead of dividing by zero', () {
      const horizon = PlazaSky(
        zenith: Colors.blue,
        horizon: Colors.white,
        ground: Colors.brown,
        sun: Colors.white,
        sunIntensity: 5,
        sunAzimuth: 0,
        sunElevation: 0,
        sunSharpness: 400,
      );
      expect(horizon.shadowLength(10), PlazaSky.maxShadowLength);
    });
  });

  group('PlazaAir', () {
    test('night carries both bloom and vignette', () {
      expect(PlazaPalette.night.air.hasBloom, isTrue);
      expect(PlazaPalette.night.air.hasVignette, isTrue);
    });

    test('daylight keeps a trace of bloom and drops the vignette', () {
      expect(PlazaPalette.day.air.hasVignette, isFalse);
      expect(
        PlazaPalette.day.air.bloomThreshold,
        greaterThan(PlazaPalette.night.air.bloomThreshold),
        reason: 'nothing in a daylit street should outshine the sky',
      );
      expect(
        PlazaPalette.day.air.bloomIntensity,
        lessThan(PlazaPalette.night.air.bloomIntensity),
      );
    });

    test('haze thins with altitude in both skies', () {
      for (final palette in [PlazaPalette.night, PlazaPalette.day]) {
        final air = palette.air;
        expect(
          air.fogDensityHigh,
          lessThan(air.fogDensityLow),
          reason: '${palette.mode.name}: the overview must see the district',
        );
        expect(air.fogOpacityHigh, lessThan(air.fogOpacityLow));
      }
    });

    test('daylight haze is thinner and paler than the night indigo', () {
      expect(
        PlazaPalette.day.air.fogDensityLow,
        lessThan(PlazaPalette.night.air.fogDensityLow),
      );
      expect(
        _luminance(PlazaPalette.day.air.fog),
        greaterThan(_luminance(PlazaPalette.night.air.fog)),
      );
    });
  });

  group('PlazaLanterns', () {
    test('every state has its own colour, in both skies', () {
      for (final palette in [PlazaPalette.night, PlazaPalette.day]) {
        final colours = {
          for (final state in LanternState.values)
            state: palette.lanterns.of(state),
        };
        expect(
          colours.values.toSet(),
          hasLength(LanternState.values.length),
          reason:
              '${palette.mode.name}: two states reading the same colour '
              'is a state the walker cannot tell apart',
        );
      }
    });

    test('a live state keeps its hue and changes only its value', () {
      // The four states that are lights at night have to survive as marks
      // by day. The hue is the thing the walker has learned; the value is
      // what has to change to carry it against a bright sky.
      for (final state in _liveStates) {
        final night = HSLColor.fromColor(PlazaPalette.night.lanterns.of(state));
        final day = HSLColor.fromColor(PlazaPalette.day.lanterns.of(state));
        expect(
          day.lightness,
          lessThan(night.lightness),
          reason: '$state should darken for a bright sky',
        );
        if (night.saturation > 0.2) {
          expect(
            day.hue,
            closeTo(night.hue, 12),
            reason: '$state must stay recognisably the same colour',
          );
        }
      }
    });

    test('a live state reads better by day than its night colour would', () {
      // The point of a second lantern set: against the day sky, each of
      // these separates further than the night colour it replaces.
      final sky = _luminance(PlazaPalette.day.sky.horizon);
      for (final state in _liveStates) {
        final asNight =
            (sky - _luminance(PlazaPalette.night.lanterns.of(state))).abs();
        final asDay = (sky - _luminance(PlazaPalette.day.lanterns.of(state)))
            .abs();
        expect(
          asDay,
          greaterThan(asNight),
          reason: '$state gains nothing from the day set',
        );
      }
    });

    test('the off state is the only lantern without a hue', () {
      // Nothing to report should not shout. It cannot be said in luminance
      // — a grey mark separates from a pale sky more than an amber one
      // does — so the rule is chroma: every live state carries a hue and
      // the unlit fixture is the one neutral among them.
      for (final palette in [PlazaPalette.night, PlazaPalette.day]) {
        final off = HSLColor.fromColor(
          palette.lanterns.of(LanternState.off),
        ).saturation;
        expect(
          off,
          lessThan(0.15),
          reason: '${palette.mode.name}: off should read as grey metal',
        );
        for (final state in _liveStates) {
          expect(
            HSLColor.fromColor(palette.lanterns.of(state)).saturation,
            greaterThan(off),
            reason: '${palette.mode.name}: $state has no more hue than off',
          );
        }
      }
    });

    test('the day lanterns are darker than the sky behind them', () {
      final sky = _luminance(PlazaPalette.day.sky.horizon);
      for (final state in LanternState.values) {
        expect(
          _luminance(PlazaPalette.day.lanterns.of(state)),
          lessThan(sky),
          reason: '$state has to read as a mark, not vanish into the sky',
        );
      }
    });
  });

  group('PlazaPalette', () {
    test('of() returns the palette for the mode, and knows which it is', () {
      expect(PlazaPalette.of(PlazaSkyMode.night), same(PlazaPalette.night));
      expect(PlazaPalette.of(PlazaSkyMode.day), same(PlazaPalette.day));
      expect(PlazaPalette.night.isDay, isFalse);
      expect(PlazaPalette.day.isDay, isTrue);
      expect(PlazaPalette.night.mode, PlazaSkyMode.night);
      expect(PlazaPalette.day.mode, PlazaSkyMode.day);
    });

    test('a finished task is the success green, whatever the hour', () {
      final done = attentionFor(_task(PlazaTaskState.done), now);
      final success = dsTokensDark.colors.alert.success.defaultColor;
      expect(PlazaPalette.night.taskColor(done), success);
      expect(PlazaPalette.day.taskColor(done), success);
    });

    test('every other task takes its lantern in the active register', () {
      final open = attentionFor(_task(PlazaTaskState.open), now);
      expect(
        PlazaPalette.night.taskColor(open),
        PlazaPalette.night.lanterns.of(open.lantern),
      );
      expect(
        PlazaPalette.day.taskColor(open),
        PlazaPalette.day.lanterns.of(open.lantern),
      );
      expect(
        PlazaPalette.day.taskColor(open),
        isNot(PlazaPalette.night.taskColor(open)),
      );
    });

    test('walls and roofs keep the category hue in both skies', () {
      final task = _task(PlazaTaskState.open, color: 0xFFFF0000);
      for (final palette in [PlazaPalette.night, PlazaPalette.day]) {
        final wall = HSLColor.fromColor(palette.categoryWall(task));
        final roof = HSLColor.fromColor(palette.categoryRoof(task));
        bool red(double hue) => hue < 12 || hue > 348;
        expect(red(wall.hue), isTrue, reason: '${palette.mode}: ${wall.hue}');
        expect(red(roof.hue), isTrue, reason: '${palette.mode}: ${roof.hue}');
      }
    });

    test('a daylight wall and roof are lit, not merely tinted dark', () {
      final task = _task(PlazaTaskState.open);
      expect(
        _luminance(PlazaPalette.day.categoryWall(task)),
        greaterThan(_luminance(PlazaPalette.night.categoryWall(task)) + 0.2),
      );
      expect(
        _luminance(PlazaPalette.day.categoryRoof(task)),
        greaterThan(_luminance(PlazaPalette.night.categoryRoof(task)) + 0.2),
      );
    });

    test('the roof stays a step down from the wall it caps', () {
      final task = _task(PlazaTaskState.open);
      for (final palette in [PlazaPalette.night, PlazaPalette.day]) {
        expect(
          _luminance(palette.categoryRoof(task)),
          lessThan(_luminance(palette.categoryWall(task))),
          reason: '${palette.mode.name}: a roof reads as a top surface',
        );
      }
    });

    test('the night done wall still starts from the design system ground', () {
      // The value is copied into the palette because a token is not a
      // constant; if the token moves, this is what says so.
      expect(
        PlazaPalette.night.surfaces.doneWallBase,
        dsTokensDark.colors.background.level01,
      );
    });

    test('a finished block reads green before its sign is legible', () {
      final done = _task(PlazaTaskState.done, color: 0xFFFF0000);
      final success = dsTokensDark.colors.alert.success.defaultColor;
      for (final palette in [PlazaPalette.night, PlazaPalette.day]) {
        expect(
          palette.categoryRoof(done),
          success,
          reason: '${palette.mode.name}: the roof is the aerial read',
        );
        final wall = HSLColor.fromColor(palette.categoryWall(done));
        expect(
          wall.hue,
          closeTo(HSLColor.fromColor(success).hue, 6),
          reason: '${palette.mode.name}: the walls go green too, not red',
        );
      }
    });

    test(
      'the daylight done wall takes more green than the night one, because '
      'a pale wall swallows the tint a dark one shows',
      () {
        final done = _task(PlazaTaskState.done, color: 0xFFFF0000);
        final success = dsTokensDark.colors.alert.success.defaultColor;
        double distanceToSuccess(Color wall) {
          final hsl = HSLColor.fromColor(wall);
          return (hsl.saturation - HSLColor.fromColor(success).saturation)
              .abs();
        }

        expect(
          distanceToSuccess(PlazaPalette.day.categoryWall(done)),
          lessThan(distanceToSuccess(PlazaPalette.night.categoryWall(done))),
        );
      },
    );
  });

  group('the two skies differ where it matters', () {
    test('daylight puts the light in the sky, not in the buildings', () {
      final night = PlazaPalette.night.lights;
      final day = PlazaPalette.day.lights;
      expect(
        day.emissiveBoost,
        lessThan(night.emissiveBoost),
        reason: 'nothing is pushed past white when the sky already is',
      );
      expect(day.groundLightScale, 0, reason: 'no pools of lamplight at noon');
      expect(day.glowScale, lessThan(night.glowScale));
      expect(day.lampsLit, isFalse);
      expect(night.lampsLit, isTrue);
    });

    test('only daylight casts shadows, and they are dark', () {
      expect(PlazaPalette.night.lights.hasShadows, isFalse);
      expect(PlazaPalette.night.lights.shadowAlpha, 0);
      expect(PlazaPalette.day.lights.hasShadows, isTrue);
      expect(
        _luminance(PlazaPalette.day.lights.shadow),
        lessThan(_luminance(PlazaPalette.day.surfaces.pavement)),
        reason: 'a shadow has to darken the paving it lies on',
      );
    });

    test('every built surface is lighter by day than by night', () {
      final night = PlazaPalette.night.surfaces;
      final day = PlazaPalette.day.surfaces;
      final pairs = <String, (Color, Color)>{
        'ground': (night.ground, day.ground),
        'road': (night.road, day.road),
        'gap': (night.gap, day.gap),
        'post': (night.post, day.post),
        'tower': (night.tower, day.tower),
        'pavement': (night.pavement, day.pavement),
        'kerb': (night.kerb, day.kerb),
        'centreLine': (night.centreLine, day.centreLine),
        'cornice': (night.cornice, day.cornice),
        'plotBase': (night.plotBase, day.plotBase),
        'plotRim': (night.plotRim, day.plotRim),
        'unlitNeon': (night.unlitNeon, day.unlitNeon),
        'riser': (night.riser, day.riser),
        'timber': (night.timber, day.timber),
        'ironwork': (night.ironwork, day.ironwork),
        'foliage': (night.foliage, day.foliage),
        'wallBase': (night.wallBase, day.wallBase),
        'roofBase': (night.roofBase, day.roofBase),
      };
      for (final MapEntry(key: name, value: (dark, lit)) in pairs.entries) {
        expect(
          _luminance(lit),
          greaterThan(_luminance(dark)),
          reason:
              '$name is unlit geometry: if it does not lighten, that '
              'surface stays a night surface under a blue sky',
        );
      }
    });

    test('the kerb still separates itself from the paving by day', () {
      for (final palette in [PlazaPalette.night, PlazaPalette.day]) {
        expect(
          _luminance(palette.surfaces.kerb),
          greaterThan(_luminance(palette.surfaces.pavement)),
          reason: '${palette.mode.name}: the kerb line carries the street',
        );
        expect(
          _luminance(palette.surfaces.pavement),
          greaterThan(_luminance(palette.surfaces.road)),
          reason: '${palette.mode.name}: pavement reads against asphalt',
        );
      }
    });

    test('the day sky is brighter overhead than the night sky', () {
      expect(
        _luminance(PlazaPalette.day.sky.horizon),
        greaterThan(_luminance(PlazaPalette.night.sky.horizon)),
      );
      expect(
        _luminance(PlazaPalette.day.sky.zenith),
        greaterThan(_luminance(PlazaPalette.night.sky.zenith)),
      );
      expect(
        _luminance(PlazaPalette.day.sky.horizon),
        greaterThan(_luminance(PlazaPalette.day.sky.zenith)),
        reason: 'a clear sky is palest where it meets the ground',
      );
    });
  });
}
