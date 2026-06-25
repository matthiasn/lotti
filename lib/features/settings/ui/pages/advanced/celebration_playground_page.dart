import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_params.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/features/settings/ui/widgets/celebration_preview_hero.dart';
import 'package:lotti/features/settings/ui/widgets/celebration_variant_picker.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/settings/settings_page_layout.dart';

/// The localized label for a [CelebrationSliderSpec.id]. Several ids are shared
/// across variants (e.g. `gravity`, `wobble`) and intentionally map to the same
/// label.
String celebrationKnobLabel(BuildContext context, String id) {
  final m = context.messages;
  final label = switch (id) {
    'count' => m.settingsCelebrationsKnobCount,
    'size' => m.settingsCelebrationsKnobSize,
    'reach' => m.settingsCelebrationsKnobReach,
    'clearCenter' => m.settingsCelebrationsKnobClearCenter,
    'gravity' => m.settingsCelebrationsKnobGravity,
    'speedSpread' => m.settingsCelebrationsKnobSpeedSpread,
    'trail' => m.settingsCelebrationsKnobTrail,
    'glow' => m.settingsCelebrationsKnobGlow,
    'launch' => m.settingsCelebrationsKnobLaunch,
    'fallout' => m.settingsCelebrationsKnobFallout,
    'twinkle' => m.settingsCelebrationsKnobTwinkle,
    'innerRing' => m.settingsCelebrationsKnobInnerRing,
    'spread' => m.settingsCelebrationsKnobSpread,
    'sway' => m.settingsCelebrationsKnobSway,
    'spin' => m.settingsCelebrationsKnobSpin,
    'fanSpread' => m.settingsCelebrationsKnobFanSpread,
    'wobble' => m.settingsCelebrationsKnobWobble,
    'halo' => m.settingsCelebrationsKnobHalo,
    'rise' => m.settingsCelebrationsKnobRise,
    'upward' => m.settingsCelebrationsKnobUpward,
    'swell' => m.settingsCelebrationsKnobSwell,
    'pop' => m.settingsCelebrationsKnobPop,
    _ => null,
  };
  // A knob shipped without a matching ARB label: fail loudly in debug so the
  // gap is caught during development, and fall back to the raw id in release
  // rather than crashing the user.
  assert(label != null, 'No localized label for celebration knob "$id"');
  return label ?? id;
}

/// A short plain-language description of what a knob does, so the controls are
/// approachable to non-technical users instead of bare engine jargon. Empty for
/// any unknown id (the description line is then omitted).
String celebrationKnobDescription(BuildContext context, String id) {
  final m = context.messages;
  return switch (id) {
    'count' => m.settingsCelebrationsKnobDescCount,
    'size' => m.settingsCelebrationsKnobDescSize,
    'reach' => m.settingsCelebrationsKnobDescReach,
    'clearCenter' => m.settingsCelebrationsKnobDescClearCenter,
    'gravity' => m.settingsCelebrationsKnobDescGravity,
    'speedSpread' => m.settingsCelebrationsKnobDescSpeedSpread,
    'trail' => m.settingsCelebrationsKnobDescTrail,
    'glow' => m.settingsCelebrationsKnobDescGlow,
    'launch' => m.settingsCelebrationsKnobDescLaunch,
    'fallout' => m.settingsCelebrationsKnobDescFallout,
    'twinkle' => m.settingsCelebrationsKnobDescTwinkle,
    'innerRing' => m.settingsCelebrationsKnobDescInnerRing,
    'spread' => m.settingsCelebrationsKnobDescSpread,
    'sway' => m.settingsCelebrationsKnobDescSway,
    'spin' => m.settingsCelebrationsKnobDescSpin,
    'fanSpread' => m.settingsCelebrationsKnobDescFanSpread,
    'wobble' => m.settingsCelebrationsKnobDescWobble,
    'halo' => m.settingsCelebrationsKnobDescHalo,
    'rise' => m.settingsCelebrationsKnobDescRise,
    'upward' => m.settingsCelebrationsKnobDescUpward,
    'swell' => m.settingsCelebrationsKnobDescSwell,
    'pop' => m.settingsCelebrationsKnobDescPop,
    _ => '',
  };
}

/// Max width of the editor column — wide enough for a two-column knob grid on
/// desktop, but capped so each label stays paired with its value instead of
/// being flung to the opposite screen edge (cf.
/// [SettingsPageLayout.maxContentWidth] = 840 for full-width forms).
const double _kEditorMaxWidth = 760;

/// Below this column width the knob grid collapses to a single column (phones).
const double _kTwoColumnMinWidth = 560;

/// The preview is capped narrower than the control grid and centred so its fake
/// rows keep list-row proportions instead of stretching into a hollow banner.
const double _kPreviewMaxWidth = 480;

/// The conceptual families the tunable knobs fall into, so the editor groups
/// them under section headers instead of presenting one flat ladder of sliders.
enum _KnobGroup { shape, motion, look }

/// Which section each stable knob id belongs to. Ids not listed fall back to
/// [_KnobGroup.motion] so a newly added knob still renders.
const Map<String, _KnobGroup> _knobGroupOf = {
  'count': _KnobGroup.shape,
  'size': _KnobGroup.shape,
  'reach': _KnobGroup.shape,
  'clearCenter': _KnobGroup.shape,
  'spread': _KnobGroup.shape,
  'fanSpread': _KnobGroup.shape,
  'innerRing': _KnobGroup.shape,
  'swell': _KnobGroup.shape,
  'gravity': _KnobGroup.motion,
  'speedSpread': _KnobGroup.motion,
  'launch': _KnobGroup.motion,
  'fallout': _KnobGroup.motion,
  'sway': _KnobGroup.motion,
  'spin': _KnobGroup.motion,
  'wobble': _KnobGroup.motion,
  'rise': _KnobGroup.motion,
  'upward': _KnobGroup.motion,
  'pop': _KnobGroup.motion,
  'trail': _KnobGroup.look,
  'glow': _KnobGroup.look,
  'twinkle': _KnobGroup.look,
  'halo': _KnobGroup.look,
};

/// The localized header for a knob section.
String _groupTitle(BuildContext context, _KnobGroup group) => switch (group) {
  _KnobGroup.shape => context.messages.settingsCelebrationsGroupShape,
  _KnobGroup.motion => context.messages.settingsCelebrationsGroupMotion,
  _KnobGroup.look => context.messages.settingsCelebrationsGroupLook,
};

/// A full-screen editor for one celebration [variant]: a large in-context
/// preview ([CelebrationPreviewHero]) over knob sliders grouped into Shape /
/// Motion / Look sections. Edits write through
/// [CelebrationPreferencesController.setVariantParams] so they persist and apply
/// globally wherever the variant plays; the live preview reflects the working
/// values as you drag and re-fires the burst when you release a slider.
class CelebrationPlaygroundPage extends ConsumerStatefulWidget {
  const CelebrationPlaygroundPage({required this.variant, super.key});

  final CelebrationVariant variant;

  @override
  ConsumerState<CelebrationPlaygroundPage> createState() =>
      _CelebrationPlaygroundPageState();
}

class _CelebrationPlaygroundPageState
    extends ConsumerState<CelebrationPlaygroundPage> {
  /// The working copy edited by the sliders; seeded from the persisted params
  /// once in [initState], then persisted back on each slider release.
  late CelebrationParams _params;

  /// Bumped on each slider release so the preview hero auto-replays the burst —
  /// closing the tune→preview loop without a manual tap.
  int _replayTick = 0;

  @override
  void initState() {
    super.initState();
    _params = ref
        .read(celebrationPreferencesControllerProvider)
        .paramsFor(widget.variant);
  }

  void _set(String id, double value) =>
      setState(() => _params = _params.withValue(id, value));

  void _persist() => ref
      .read(celebrationPreferencesControllerProvider.notifier)
      .setVariantParams(_params);

  /// On slider release: persist the new value and replay the preview so the
  /// effect of the change is shown without scrolling back up to tap the row.
  void _onSliderRelease() {
    _persist();
    setState(() => _replayTick++);
  }

  void _reset() {
    // Snapshot the pre-reset params so the reset (a single tap that wipes all
    // tuning) is reversible via the Undo action.
    final previous = _params;
    setState(() => _params = CelebrationParams.defaultsFor(widget.variant));
    ref
        .read(celebrationPreferencesControllerProvider.notifier)
        .resetVariantParams(widget.variant);

    final messages = context.messages;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(messages.settingsCelebrationsResetToast),
          action: SnackBarAction(
            label: messages.settingsCelebrationsResetUndo,
            onPressed: () {
              // Persist regardless; the local state restore is skipped if the
              // user already left this route (setState on a disposed State
              // throws).
              ref
                  .read(celebrationPreferencesControllerProvider.notifier)
                  .setVariantParams(previous);
              if (!mounted) return;
              setState(() => _params = previous);
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final specs = celebrationSliderSpecs(widget.variant);

    return Scaffold(
      // The variant name is an in-card heading (below); the AppBar carries the
      // back affordance and the Reset action.
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: _params.isCustomized ? _reset : null,
            child: Text(messages.settingsCelebrationsResetToDefault),
          ),
        ],
      ),
      // One centred, width-capped editor panel. The heading + compact preview +
      // hint are PINNED at the top while only the knob groups scroll beneath, so
      // the burst auto-replayed on each slider release stays visible no matter
      // which knob you're tuning. The sliders inherit the app's accent via one
      // [SliderTheme]; the grid goes two-up past [_kTwoColumnMinWidth].
      body: SliderTheme(
        data: _sliderTheme(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kEditorMaxWidth),
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step6),
              // One surface card frames the whole editor so the preview and its
              // controls read as a single panel rather than loose content on a
              // black void.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.colors.surface.enabled,
                  borderRadius: BorderRadius.circular(
                    tokens.radii.sectionCards,
                  ),
                  border: Border.all(color: tokens.colors.decorative.level02),
                ),
                child: Padding(
                  padding: EdgeInsets.all(tokens.spacing.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        celebrationVariantLabel(context, widget.variant),
                        style: tokens.typography.styles.heading.heading3
                            .copyWith(color: tokens.colors.text.highEmphasis),
                      ),
                      SizedBox(height: tokens.spacing.step2),
                      // "playground" implies a sandbox; spell out that edits are
                      // live and global so there's no mode-error surprise.
                      Text(
                        messages.settingsCelebrationsPlaygroundLiveNote,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                      SizedBox(height: tokens.spacing.step4),
                      // Hint precedes the rows so the "this is an interactive
                      // demo" scent arrives before the (otherwise checklist-like)
                      // rows, not after.
                      Text(
                        messages.settingsCelebrationsPlaygroundHint,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                      SizedBox(height: tokens.spacing.step3),
                      // Width-capped (so the rows keep list-row proportions) but
                      // LEFT-aligned to the card's content edge, so the preview
                      // shares one left edge with the heading, replay, and the
                      // slider grid — the panel reads as one column, not islands.
                      // Unframed because the editor card already provides the
                      // surface; a single neighbour row keeps the hero compact.
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _kPreviewMaxWidth,
                        ),
                        child: CelebrationPreviewHero(
                          params: _params,
                          replayTick: _replayTick,
                          // On a phone, drop the context rows so the pinned
                          // preview stays small and more knobs are reachable
                          // (and the page is obviously scrollable); desktop has
                          // the height for one neighbour each side.
                          neighbours:
                              MediaQuery.sizeOf(context).width <
                                  _kTwoColumnMinWidth
                              ? 0
                              : 1,
                          framed: false,
                        ),
                      ),
                      SizedBox(height: tokens.spacing.step2),
                      // An explicit replay control (left-aligned on the same edge
                      // as the preview it drives), so previewing the effect isn't
                      // gated behind discovering the tappable row.
                      TextButton.icon(
                        onPressed: () => setState(() => _replayTick++),
                        style: TextButton.styleFrom(
                          foregroundColor: tokens.colors.interactive.enabled,
                        ),
                        icon: const Icon(Icons.replay),
                        label: Text(messages.settingsCelebrationsReplay),
                      ),
                      SizedBox(height: tokens.spacing.step5),
                      // Only the knob groups scroll; the preview above stays
                      // pinned so the auto-replayed burst is always visible.
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final entry in _visibleGroups(specs).indexed)
                                ..._buildGroup(
                                  context,
                                  entry.$2,
                                  specs,
                                  isFirst: entry.$1 == 0,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The knob sections the [specs] actually populate, in display order — so the
  /// first one can drop its leading gap (the preview already sits above it).
  List<_KnobGroup> _visibleGroups(List<CelebrationSliderSpec> specs) =>
      _KnobGroup.values
          .where(
            (g) => specs.any(
              (s) => (_knobGroupOf[s.id] ?? _KnobGroup.motion) == g,
            ),
          )
          .toList();

  /// The knobs for one [group] under a section header, laid out as a responsive
  /// grid (two columns on wide panes, one on phones). Returns an empty list when
  /// the variant has no knobs in this group, so no orphan header renders.
  List<Widget> _buildGroup(
    BuildContext context,
    _KnobGroup group,
    List<CelebrationSliderSpec> specs, {
    bool isFirst = false,
  }) {
    final tokens = context.designTokens;
    final groupSpecs = specs
        .where((s) => (_knobGroupOf[s.id] ?? _KnobGroup.motion) == group)
        .toList();
    if (groupSpecs.isEmpty) return const [];

    return [
      // A deliberate gap before each section header sets the group rhythm. The
      // first group skips it — the preview/replay above already provide the gap,
      // so it isn't double-paid.
      if (!isFirst) SizedBox(height: tokens.spacing.sectionGap),
      Text(
        _groupTitle(context, group),
        // subtitle1 (a step ABOVE the bodyMedium knob labels) + high-emphasis so
        // the Shape / Motion / Look structure outranks the controls on both size
        // and weight.
        style: tokens.typography.styles.subtitle.subtitle1.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
      ),
      SizedBox(height: tokens.spacing.step3),
      LayoutBuilder(
        builder: (context, constraints) {
          final twoColumn = constraints.maxWidth >= _kTwoColumnMinWidth;
          // A wide gutter so a left-column value never reads as paired with the
          // next column's label ("40  Size").
          final gap = tokens.spacing.step6;
          // -1 guards against a sub-pixel overflow that would wrap the pair.
          final itemWidth = twoColumn
              ? (constraints.maxWidth - gap) / 2 - 1
              : constraints.maxWidth;
          return Wrap(
            spacing: gap,
            children: [
              for (final spec in groupSpecs)
                SizedBox(
                  width: itemWidth,
                  child: _KnobSlider(
                    label: celebrationKnobLabel(context, spec.id),
                    spec: spec,
                    value: _params.v(spec.id),
                    onChanged: (v) => _set(spec.id, v),
                    onChangeEnd: (_) => _onSliderRelease(),
                  ),
                ),
            ],
          );
        },
      ),
    ];
  }
}

/// The slider styling shared by every knob: the app's interactive accent on the
/// active track + thumb (so the controls visibly belong to the teal preview they
/// drive) over a neutral inactive track.
SliderThemeData _sliderTheme(BuildContext context) {
  final tokens = context.designTokens;
  final accent = tokens.colors.interactive.enabled;
  return SliderTheme.of(context).copyWith(
    activeTrackColor: accent,
    // decorative.level03 (a brighter neutral than the level02 chrome) so the
    // unfilled range stays legible on the near-black surface.
    inactiveTrackColor: tokens.colors.decorative.level03,
    thumbColor: accent,
    overlayColor: accent.withValues(alpha: 0.12),
    // Ticks on the integer sliders only add noise next to the live value, which
    // already reads the exact number.
    activeTickMarkColor: Colors.transparent,
    inactiveTickMarkColor: Colors.transparent,
  );
}

/// One labelled slider for a [CelebrationSliderSpec], showing the current value.
class _KnobSlider extends StatelessWidget {
  const _KnobSlider({
    required this.label,
    required this.spec,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final CelebrationSliderSpec spec;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  /// Opens a numeric editor so an exact value can be typed instead of dragged —
  /// the two paths (drag / type) reach the same value. The entry is clamped to
  /// the knob's range and routed through the same [onChanged]/[onChangeEnd] as a
  /// drag so it persists and replays the preview.
  Future<void> _editValue(BuildContext context) async {
    final entered = await showDialog<double>(
      context: context,
      builder: (_) =>
          _ValueEditorDialog(label: label, spec: spec, value: value),
    );
    if (entered == null) return;
    // Integer knobs (e.g. particle count) round to a whole number so the typed
    // path stores exactly what the slider and readout present, not a fraction.
    final normalized = spec.isInt ? entered.roundToDouble() : entered;
    final clamped = normalized.clamp(spec.min, spec.max);
    onChanged(clamped);
    onChangeEnd(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final display = spec.isInt
        ? value.round().toString()
        : value.toStringAsFixed(2);
    // Each knob is one unit: a tight label→value→slider stack with a clear gap
    // below before the next knob, so the list reads as discrete controls rather
    // than one continuous ladder.
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + value as one Text.rich cluster ("Particles  40") so the
          // value stays glued to its own name. The muted label leads (you scan
          // by name); the high-emphasis value is the live readout — and a tap
          // target (a faint accent chip) for typing an exact value instead of
          // dragging. Tabular figures keep it from jittering mid-drag.
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
                const TextSpan(text: '  '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: InkWell(
                    onTap: () => _editValue(context),
                    borderRadius: BorderRadius.circular(tokens.radii.xs),
                    // A resting chip (subtle fill + edit glyph) so the value
                    // reads as a tappable field — the type-an-exact-value path is
                    // discoverable, not hidden behind plain text.
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.spacing.step2,
                        vertical: tokens.spacing.step1,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.colors.decorative.level02,
                        borderRadius: BorderRadius.circular(tokens.radii.xs),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            display,
                            style: tokens.typography.styles.body.bodyMedium
                                .copyWith(
                                  color: tokens.colors.text.highEmphasis,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                          SizedBox(width: tokens.spacing.step1),
                          Icon(
                            Icons.edit_outlined,
                            size: tokens.spacing.step4,
                            color: tokens.colors.text.mediumEmphasis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Plain-language description so a non-technical user can predict what
          // dragging this knob will do, instead of facing bare engine jargon.
          if (celebrationKnobDescription(context, spec.id).isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step1),
              child: Text(
                celebrationKnobDescription(context, spec.id),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ),
          Slider(
            value: value.clamp(spec.min, spec.max),
            min: spec.min,
            max: spec.max,
            divisions: spec.isInt ? (spec.max - spec.min).round() : null,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }
}

/// A small numeric editor dialog for a knob value. It owns its
/// [TextEditingController] and disposes it in [State.dispose] (when the route is
/// removed), so the type-an-exact-value path leaks nothing and never disposes a
/// controller while the dialog is still animating out. Pops the parsed value
/// (or null on cancel); the caller clamps to the knob's range.
class _ValueEditorDialog extends StatefulWidget {
  const _ValueEditorDialog({
    required this.label,
    required this.spec,
    required this.value,
  });

  final String label;
  final CelebrationSliderSpec spec;
  final double value;

  @override
  State<_ValueEditorDialog> createState() => _ValueEditorDialogState();
}

class _ValueEditorDialogState extends State<_ValueEditorDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.spec.isInt
        ? widget.value.round().toString()
        : widget.value.toStringAsFixed(2),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = double.tryParse(_controller.text.replaceAll(',', '.'));
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final spec = widget.spec;
    return AlertDialog(
      title: Text(widget.label),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          helperText: spec.isInt
              ? '${spec.min.round()}–${spec.max.round()}'
              : '${spec.min.toStringAsFixed(2)}–${spec.max.toStringAsFixed(2)}',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(messages.cancelButton),
        ),
        TextButton(onPressed: _submit, child: Text(messages.saveButton)),
      ],
    );
  }
}
